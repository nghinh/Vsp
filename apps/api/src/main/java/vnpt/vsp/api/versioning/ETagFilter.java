package vnpt.vsp.api.versioning;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

/**
 * {@link OncePerRequestFilter} that implements HTTP conditional-GET semantics
 * using the {@code ETag} / {@code If-None-Match} headers.
 * <p>
 * <strong>Behaviour:</strong>
 * <ol>
 *   <li>
 *     <strong>{@code If-None-Match} check:</strong> when an incoming GET request
 *     carries an {@code If-None-Match} header, the filter short-circuits
 *     <em>before</em> controller execution by delegating to
 *     {@link #checkETagAndShortCircuit(HttpServletRequest, HttpServletResponse, FilterChain)}.
 *     The request attribute {@link #ATTR_ETAG} must have been set by the
 *     controller/service layer with the current entity's ETag.
 *     If the header value matches the attribute, a {@code 304 Not Modified}
 *     response is emitted immediately.
 *   </li>
 *   <li>
 *     <strong>ETag population:</strong> when the response is being written,
 *     the {@link ContentCachingResponseWrapper} captures the body.
 *     After the controller has written its response, the filter checks the
 *     {@link #ATTR_ETAG} request attribute again.  If set, the corresponding
 *     ETag is written to the response {@code ETag} header.
 *   </li>
 * </ol>
 * <p>
 * <strong>How controllers / services set the ETag:</strong>
 * after computing the ETag via {@link ETagService#computeETag(Object)}, place
 * it in the request attribute under {@link #ATTR_ETAG}:
 * <pre>{@code
 * request.setAttribute(ETagFilter.ATTR_ETAG, etagService.computeETag(entity));
 * }</pre>
 *
 * <p>
 * The filter runs with {@link Ordered#LOWEST_PRECEDENCE} so that downstream
 * components (controllers, services) execute between the early
 * {@code If-None-Match} check and the late ETag header injection.
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE)
public class ETagFilter extends OncePerRequestFilter {

    /**
     * Request attribute key under which the computed ETag is placed by
     * downstream components (controllers / services).
     */
    public static final String ATTR_ETAG = "vnpt.vsp.api.ETag";

    /**
     * Response header name for the ETag value.
     */
    public static final String HEADER_ETAG = "ETag";

    /**
     * Request header name the client sends to conditionally request a
     * fresh representation.
     */
    public static final String HEADER_IF_NONE_MATCH = "If-None-Match";

    private final ETagService eTagService;

    public ETagFilter(ETagService eTagService) {
        this.eTagService = eTagService;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        ContentCachingResponseWrapper wrappedResponse = new ContentCachingResponseWrapper(response);

        // Step 1: early If-None-Match short-circuit (only if controller already set the ETag)
        String etag = getETagFromRequest(request);
        if (etag != null && matchesIfNoneMatch(request, etag)) {
            response.setStatus(HttpServletResponse.SC_NOT_MODIFIED);
            return;
        }

        // Step 2: run the rest of the filter chain (controller executes here)
        filterChain.doFilter(request, wrappedResponse);

        // Step 3: after controller ran, inject ETag header if set by controller
        String computedETag = getETagFromRequest(request);
        if (computedETag != null) {
            wrappedResponse.setHeader(HEADER_ETAG, computedETag);
        }

        // Step 4: copy body to the underlying response
        wrappedResponse.copyBodyToResponse();
    }

    /**
     * Short-circuit helper used by controllers that already know the ETag
     * before the filter chain runs.
     *
     * @param request  the current request
     * @param response the current response
     * @param chain    the remaining filter chain
     * @throws IOException      if forward/short-circuit fails
     * @throws ServletException if the underlying filter chain throws
     */
    public void checkETagAndShortCircuit(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain chain) throws IOException, ServletException {

        String etag = getETagFromRequest(request);
        if (etag != null && matchesIfNoneMatch(request, etag)) {
            response.setStatus(HttpServletResponse.SC_NOT_MODIFIED);
            return;
        }
        chain.doFilter(request, response);
    }

    /**
     * Returns the ETag stored in the request attribute, or {@code null} if not set.
     */
    private String getETagFromRequest(HttpServletRequest request) {
        Object attr = request.getAttribute(ATTR_ETAG);
        return attr instanceof String s ? s : null;
    }

    /**
     * Returns {@code true} when the {@code If-None-Match} header matches the
     * supplied ETag value.
     */
    private boolean matchesIfNoneMatch(HttpServletRequest request, String etag) {
        String incoming = request.getHeader(HEADER_IF_NONE_MATCH);
        if (incoming == null || incoming.isBlank()) {
            return false;
        }
        // Support comma-separated list of ETags (RFC 7232 §3.2)
        for (String token : incoming.split("\\s*,\\s*")) {
            if (token.equals(etag) || token.equals("*")) {
                return true;
            }
        }
        return false;
    }
}
