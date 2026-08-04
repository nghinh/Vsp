package vnpt.vsp.api.pagination;

import org.springframework.core.MethodParameter;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;
import java.util.Optional;

/**
 * {@link HandlerMethodArgumentResolver} that extracts pagination parameters from
 * the current HTTP request and produces a {@link PageConstraints} value object.
 * <p>
 * Resolution is only attempted for controller methods annotated with {@link Paged}.
 * <p>
 * Parameters read:
 * <ul>
 *   <li>{@code pageToken} — opaque cursor string; decoded to recover prior page state</li>
 *   <li>{@code pageSize} — optional; defaults to {@link Paged#defaultPageSize()}</li>
 * </ul>
 * <p>
 * The resolver also validates that {@code pageSize} does not exceed {@link Paged#maxPageSize()}.
 */
@Component
public class PaginationArgumentResolver implements HandlerMethodArgumentResolver {

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.hasParameterAnnotation(Paged.class)
                && PageConstraints.class.isAssignableFrom(parameter.getParameterType());
    }

    @Override
    public Object resolveArgument(
            MethodParameter parameter,
            ModelAndViewContainer mavContainer,
            NativeWebRequest webRequest,
            WebDataBinderFactory binderFactory
    ) {
        Paged paged = parameter.getMethodAnnotation(Paged.class);
        if (paged == null) {
            throw new VspApiException(VspErrorCode.INTERNAL_001,
                    Map.of("context", "PaginationArgumentResolver invoked without @Paged annotation"));
        }

        HttpServletRequest request = webRequest.getNativeRequest(HttpServletRequest.class);

        String pageToken = request.getParameter("pageToken");
        String pageSizeStr = request.getParameter("pageSize");

        int pageSize = paged.defaultPageSize();
        if (pageSizeStr != null && !pageSizeStr.isBlank()) {
            try {
                pageSize = Integer.parseInt(pageSizeStr);
            } catch (NumberFormatException e) {
                throw new VspApiException(VspErrorCode.VALIDATION_001, "pageSize",
                        Map.of("reason", "pageSize must be an integer"));
            }
        }

        if (pageSize < 1) {
            throw new VspApiException(VspErrorCode.VALIDATION_001, "pageSize",
                    Map.of("reason", "pageSize must be at least 1"));
        }

        int effectiveMaxPageSize = paged.maxPageSize();
        if (pageSize > effectiveMaxPageSize) {
            pageSize = effectiveMaxPageSize;
        }

        int page = 0;
        String sortField = null;
        String sortDir = null;
        String anchor = null;

        if (pageToken != null && !pageToken.isBlank()) {
            PageTokenService pageTokenService = new PageTokenService();
            Optional<PageTokenService.PageToken> decoded = pageTokenService.decode(pageToken);
            if (decoded.isPresent()) {
                PageTokenService.PageToken token = decoded.get();
                page = token.page() - 1; // convert 1-based to 0-based
                if (token.sortField() != null) {
                    sortField = token.sortField();
                }
                if (token.sortDir() != null) {
                    sortDir = token.sortDir();
                }
                anchor = token.anchor();
            }
        }

        return new PageConstraints(page, pageSize, sortField, sortDir, anchor, paged.includeTotalCount());
    }
}
