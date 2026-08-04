package vnpt.vsp.api.pagination;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.List;
import java.util.Objects;

/**
 * Generic pagination wrapper DTO for list responses.
 * <p>
 * Schema (matches OpenAPI {@code Pagination} schema):
 * <pre>
 * {
 *   "items": [...],          // the list of items for this page
 *   "pageToken": "eyJiYXNlVW...",
 *   "hasMore": true,
 *   "totalCount": 247        // optional; only present when the caller requests it
 * }
 * </pre>
 *
 * @param <T> the type of item contained in the list
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class Pagination<T> {

    private List<T> items;
    private String pageToken;
    private Boolean hasMore;
    private Long totalCount;

    public Pagination() {
    }

    private Pagination(Builder<T> builder) {
        this.items = builder.items;
        this.pageToken = builder.pageToken;
        this.hasMore = builder.hasMore;
        this.totalCount = builder.totalCount;
    }

    public static <T> Builder<T> builder() {
        return new Builder<>();
    }

    public List<T> getItems() {
        return items;
    }

    public String getPageToken() {
        return pageToken;
    }

    public Boolean getHasMore() {
        return hasMore;
    }

    public Long getTotalCount() {
        return totalCount;
    }

    public void setItems(List<T> items) {
        this.items = items;
    }

    public void setPageToken(String pageToken) {
        this.pageToken = pageToken;
    }

    public void setHasMore(Boolean hasMore) {
        this.hasMore = hasMore;
    }

    public void setTotalCount(Long totalCount) {
        this.totalCount = totalCount;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Pagination<?> that = (Pagination<?>) o;
        return Objects.equals(items, that.items)
                && Objects.equals(pageToken, that.pageToken)
                && Objects.equals(hasMore, that.hasMore)
                && Objects.equals(totalCount, that.totalCount);
    }

    @Override
    public int hashCode() {
        return Objects.hash(items, pageToken, hasMore, totalCount);
    }

    @Override
    public String toString() {
        return "Pagination{items=" + (items != null ? items.size() : 0)
                + ", pageToken=" + pageToken
                + ", hasMore=" + hasMore
                + ", totalCount=" + totalCount
                + "}";
    }

    public static class Builder<T> {
        private List<T> items;
        private String pageToken;
        private Boolean hasMore;
        private Long totalCount;

        public Builder<T> items(List<T> items) {
            this.items = items;
            return this;
        }

        public Builder<T> pageToken(String pageToken) {
            this.pageToken = pageToken;
            return this;
        }

        public Builder<T> hasMore(Boolean hasMore) {
            this.hasMore = hasMore;
            return this;
        }

        public Builder<T> totalCount(Long totalCount) {
            this.totalCount = totalCount;
            return this;
        }

        public Pagination<T> build() {
            return new Pagination<>(this);
        }
    }
}
