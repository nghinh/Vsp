package vnpt.vsp.api.idempotency;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerExecutionChain;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;
import vnpt.vsp.api.error.VspApiException;

import java.io.IOException;
import java.time.Duration;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

/**
 * {@link OncePerRequestFilter} that enforces idempotency-key semantics on endpoints
 * annotated with {@link Idempotent}.
 * <p>
 * Logic per request:
 * <ol>
 *   <li>Resolve the target {@link HandlerMethod}, if any.</li>
 *   <li>If the handler is not annotated with {@link Idempotent}, pass through immediately.</li>
 *   <li>If the handler is annotated but the {@code Idempotency-Key} header is absent,
 *       throw {@link VspApiException} with {@code VALIDATION_006}.</li>
 *   <li>If the key is present and a cached response exists, write the cached body, status,
 *       content-type, and headers to the real response and set
 *       {@code X-Idempotent-Replay: true}; then stop the filter chain.</li>
 *   <li>If the key is present and no cache exists, wrap the response with
 *       {@link CachingResponseWrapper}, continue the filter chain, and after execution
 *       store the captured response under the key with the configured TTL.</li>
 * </ol>
 * <p>
 * The filter runs after {@link vnpt.vsp.api.error.CorrelationIdFilter}
 * ({@code Order 1}) so correlation IDs are available for error responses.
 *
 * @see Idempotent
 * @see IdempotencyService
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 10)
public class IdempotencyFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(IdempotencyFilter.class);

    public static final String HEADER_IDEMPOTENCY_KEY = "Idempotency-Key";
    public static final String HEADER_IDEMPOTENT_REPLAY = "X-Idempotent-Replay";

    private final IdempotencyService idempotencyService;
    private final RequestMappingHandlerMapping handlerMapping;

    public IdempotencyFilter(IdempotencyService idempotencyService,
                             @Qualifier("requestMappingHandlerMapping") RequestMappingHandlerMapping handlerMapping) {
        this.idempotencyService = idempotencyService;
        this.handlerMapping = handlerMapping;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        HandlerMethod handler = resolveHandlerMethod(request);
        if (handler == null) {
            filterChain.doFilter(request, response);
            return;
        }

        Idempotent idempotent = resolveIdempotentAnnotation(handler);
        if (idempotent == null) {
            filterChain.doFilter(request, response);
            return;
        }

        String key = request.getHeader(HEADER_IDEMPOTENCY_KEY);
        if (key == null || key.isBlank()) {
            throw new VspApiException(
                    vnpt.vsp.api.error.VspErrorCode.VALIDATION_006,
                    HEADER_IDEMPOTENCY_KEY
            );
        }

        CachedResponse cached = idempotencyService.getCachedResponse(key);
        if (cached != null) {
            replayResponse(cached, response);
            log.debug("Idempotency replay for key={}", key);
            return;
        }

        CachingResponseWrapper wrappedResponse = new CachingResponseWrapper(response);
        String finalKey = key;
        wrappedResponse.setResponseCallback(() -> {
            CachedResponse captured = wrappedResponse.capture();
            Duration ttl = Duration.ofSeconds(idempotent.ttlSeconds());
            idempotencyService.put(finalKey, captured, ttl);
            log.debug("Idempotency cached for key={}", finalKey);
        });

        try {
            filterChain.doFilter(request, wrappedResponse);
        } finally {
            wrappedResponse.runResponseCallback();
        }
    }

    private HandlerMethod resolveHandlerMethod(HttpServletRequest request) {
        try {
            HandlerExecutionChain chain = handlerMapping.getHandler(request);
            if (chain == null) {
                return null;
            }
            Object handler = chain.getHandler();
            if (handler instanceof HandlerMethod hm) {
                return hm;
            }
            return null;
        } catch (Exception e) {
            log.trace("Could not resolve handler method", e);
            return null;
        }
    }

    private Idempotent resolveIdempotentAnnotation(HandlerMethod handler) {
        Idempotent methodLevel = handler.getMethodAnnotation(Idempotent.class);
        if (methodLevel != null) {
            return methodLevel;
        }
        Idempotent classLevel = handler.getBeanType().getAnnotation(Idempotent.class);
        return classLevel;
    }

    private void replayResponse(CachedResponse cached, HttpServletResponse response) throws IOException {
        response.setStatus(cached.status());
        if (cached.contentType() != null) {
            response.setContentType(cached.contentType());
        }
        response.setHeader(HEADER_IDEMPOTENT_REPLAY, "true");
        cached.headers().forEach(response::setHeader);
        response.getOutputStream().write(cached.body());
        response.getOutputStream().flush();
    }

    /**
     * Response wrapper that captures the response body, status, and headers
     * after the controller has written to it, without consuming the output stream.
     */
    private static class CachingResponseWrapper extends jakarta.servlet.http.HttpServletResponseWrapper {

        private final HttpServletResponse delegate;
        private final AtomicReference<byte[]> capturedBody = new AtomicReference<>();
        private final ByteArrayOutputStream captureStream;
        private final TeeServletOutputStream teeOutputStream;
        private int status = 200;
        private String contentType;
        private final Map<String, String> headers = new HashMap<>();
        private volatile boolean callbackRun = false;
        private Runnable responseCallback;

        CachingResponseWrapper(HttpServletResponse response) throws IOException {
            super(response);
            this.delegate = response;
            this.captureStream = new ByteArrayOutputStream();
            this.teeOutputStream = new TeeServletOutputStream(delegate.getOutputStream(), captureStream);
        }

        void setResponseCallback(Runnable callback) {
            this.responseCallback = callback;
        }

        void runResponseCallback() {
            if (!callbackRun && responseCallback != null) {
                callbackRun = true;
                responseCallback.run();
            }
        }

        @Override
        public void setStatus(int status) {
            this.status = status;
            super.setStatus(status);
        }

        @Override
        public void setContentType(String contentType) {
            this.contentType = contentType;
            super.setContentType(contentType);
        }

        @Override
        public void setHeader(String name, String value) {
            this.headers.put(name, value);
            super.setHeader(name, value);
        }

        @Override
        public void addHeader(String name, String value) {
            this.headers.put(name, value);
            super.addHeader(name, value);
        }

        @Override
        public jakarta.servlet.ServletOutputStream getOutputStream() throws IOException {
            return teeOutputStream;
        }

        @Override
        public void flushBuffer() throws IOException {
            teeOutputStream.flush();
        }

        @Override
        public void reset() {
            super.reset();
            this.status = 200;
            this.contentType = null;
            this.headers.clear();
        }

        CachedResponse capture() {
            return CachedResponse.fromServletResponse(
                    captureStream.toByteArray(),
                    status,
                    contentType,
                    new HashMap<>(headers)
            );
        }
    }

    private static class ByteArrayOutputStream extends java.io.ByteArrayOutputStream {
        // marker class for clarity; parent class is sufficient
    }

    private static class TeeServletOutputStream extends jakarta.servlet.ServletOutputStream {

        private final jakarta.servlet.ServletOutputStream delegate;
        private final java.io.OutputStream tee;

        TeeServletOutputStream(jakarta.servlet.ServletOutputStream delegate, java.io.OutputStream tee) {
            this.delegate = delegate;
            this.tee = tee;
        }

        @Override
        public void write(int b) throws java.io.IOException {
            delegate.write(b);
            tee.write(b);
        }

        @Override
        public void write(byte[] b) throws java.io.IOException {
            delegate.write(b);
            tee.write(b);
        }

        @Override
        public void write(byte[] b, int off, int len) throws java.io.IOException {
            delegate.write(b, off, len);
            tee.write(b, off, len);
        }

        @Override
        public void flush() throws java.io.IOException {
            delegate.flush();
            tee.flush();
        }

        @Override
        public void close() throws java.io.IOException {
            delegate.close();
            tee.close();
        }

        @Override
        public boolean isReady() {
            return delegate.isReady();
        }

        @Override
        public void setWriteListener(jakarta.servlet.WriteListener listener) {
            delegate.setWriteListener(listener);
        }
    }
}
