package vnpt.vsp.api.error;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.UUID;

/**
 * Renders the two refusals the security filter chain produces itself — before
 * any controller runs, so {@link GlobalExceptionHandler} never sees them — as
 * the same {@link ErrorResponse} body every other API error uses.
 * <p>
 * Without this, Spring Security answers both with an empty body: a caller gets
 * a bare {@code 403} and cannot tell "you sent no token" from "your role is
 * wrong" from "that route does not exist".
 * <p>
 * The correlation ID cannot come from the MDC here. {@code springSecurityFilterChain}
 * is registered at order {@code -100} and {@link CorrelationIdFilter} at order
 * {@code 1}, so security runs first and the MDC is still empty; the ID is taken
 * from the request header when the client sent one and generated otherwise, and
 * echoed back on the response exactly as {@link CorrelationIdFilter} would.
 */
@Component
public class SecurityErrorResponder implements AuthenticationEntryPoint, AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    public SecurityErrorResponder(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /** No credentials, or credentials that did not authenticate. */
    @Override
    public void commence(HttpServletRequest request,
                         HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        write(request, response, VspErrorCode.AUTH_001,
                "Authentication required — send a valid access token as 'Authorization: Bearer <token>'");
    }

    /** Authenticated, but lacking the role the route requires. */
    @Override
    public void handle(HttpServletRequest request,
                       HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException {
        write(request, response, VspErrorCode.AUTH_005,
                VspErrorCode.AUTH_005.getDefaultMessage());
    }

    private void write(HttpServletRequest request,
                       HttpServletResponse response,
                       VspErrorCode code,
                       String message) throws IOException {

        String correlationId = correlationId(request);
        response.setHeader(CorrelationIdFilter.HEADER_NAME, correlationId);
        response.setStatus(code.getHttpStatus().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");

        ErrorResponse body = ErrorResponse.builder()
                .code(code.getCode())
                .message(message)
                .correlationId(correlationId)
                .build();

        objectMapper.writeValue(response.getOutputStream(), body);
    }

    private String correlationId(HttpServletRequest request) {
        String fromMdc = MDC.get(CorrelationIdFilter.MDC_KEY);
        if (fromMdc != null && !fromMdc.isBlank()) {
            return fromMdc;
        }
        String fromHeader = request.getHeader(CorrelationIdFilter.HEADER_NAME);
        if (fromHeader != null && !fromHeader.isBlank()) {
            return fromHeader;
        }
        return UUID.randomUUID().toString();
    }
}
