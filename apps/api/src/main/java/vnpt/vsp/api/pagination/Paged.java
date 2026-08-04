package vnpt.vsp.api.pagination;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Marks a list-returning method as supporting cursor-based pagination.
 * <p>
 * When present on a method, the {@link PaginationArgumentResolver} will read
 * {@code pageToken} and {@code pageSize} from the current HTTP request and
 * inject a {@link org.springframework.data.domain.PageRequest} argument.
 * The {@link PaginationAdvice} will wrap the method's list return value in
 * a {@link Pagination} response DTO.
 * <p>
 * Example:
 * <pre>
 * {@code @Paged(defaultPageSize = 20, maxPageSize = 100)}
 * public List&lt;Course&gt; listCourses(PageRequest pageRequest) { ... }
 * </pre>
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Paged {

    /**
     * Default number of items returned per page when the client does not specify
     * a {@code pageSize} query parameter.
     */
    int defaultPageSize() default 20;

    /**
     * Maximum allowed page size. Requests with a larger {@code pageSize} will be
     * capped to this value.
     */
    int maxPageSize() default 100;

    /**
     * Whether {@code totalCount} should be included in the {@link Pagination} response.
     * Counting total records can be expensive on large tables; defaults to {@code false}.
     */
    boolean includeTotalCount() default false;
}
