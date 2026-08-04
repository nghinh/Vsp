package vnpt.vsp.api.pagination;

import java.util.Objects;

/**
 * Immutable value object representing the resolved pagination parameters for a request.
 * <p>
 * Produced by {@link PaginationArgumentResolver} and consumed by service/repository
 * layers to apply cursor-based pagination.
 *
 * @param page          0-based page index
 * @param pageSize      number of items to return per page
 * @param sortField     field name to sort by (may be null)
 * @param sortDirection sort direction: "asc" or "desc" (may be null implies "asc")
 * @param anchor         opaque anchor cursor from the last item of the previous page (may be null)
 * @param includeTotalCount whether the total count should be included in the response
 */
public record PageConstraints(
        int page,
        int pageSize,
        String sortField,
        String sortDirection,
        String anchor,
        boolean includeTotalCount
) {

    public PageConstraints(int page, int pageSize, String sortField, String sortDirection, String anchor) {
        this(page, pageSize, sortField, sortDirection, anchor, false);
    }

    /**
     * Creates a default {@link PageConstraints} with page = 0, pageSize = 20, no sorting.
     */
    public static PageConstraints defaults() {
        return new PageConstraints(0, 20, null, null, null, false);
    }

    /**
     * Returns true if the sort direction is descending.
     */
    public boolean isDescending() {
        return "desc".equalsIgnoreCase(sortDirection);
    }

    @Override
    public String toString() {
        return "PageConstraints{page=" + page
                + ", pageSize=" + pageSize
                + ", sortField='" + sortField + '\''
                + ", sortDirection='" + sortDirection + '\''
                + ", anchor='" + anchor + '\''
                + ", includeTotalCount=" + includeTotalCount
                + '}';
    }
}
