package vnpt.vsp.api.error;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

/**
 * {@link OncePerRequestFilter} that extracts or generates a correlation ID for the request.
 * <p>
 * Logic:
 * <ol>
 *   <li>If the incoming request carries an {@code X-Correlation-ID} header, use its value.</li>
 *   <li>Otherwise generate a new {@link UUID#randomUUID()}.</li>
 * </ol>
 * The ID is placed in:
 * <ul>
 *   <li>{@link MDC} under the key {@code correlationId} — for structured log correlation</li>
 *   <li>The response {@code X-Correlation-ID} header — for client-side tracing</li>
 * </ul>
 * <p>
 * The filter runs early in the chain ({@link Order#HIGHEST_PRECEDENCE}) so the ID is available
 * to all downstream components including the {@link GlobalExceptionHandler}.
 */
@Component
@Order(1)
public class CorrelationIdFilter extends OncePerRequestFilter {

    public static final String HEADER_NAME = "X-Correlation-ID";
    public static final String MDC_KEY = "correlationId";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        String correlationId = request.getHeader(HEADER_NAME);
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = UUID.randomUUID().toString();
        }

        MDC.put(MDC_KEY, correlationId);
        response.setHeader(HEADER_NAME, correlationId);

        try {
            filterChain.doFilter(request, response);
        } finally {
            MDC.remove(MDC_KEY);
        }
    }
}
