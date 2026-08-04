package vnpt.vsp.module.coursealert.dto;

import java.util.List;

/**
 * Response DTO for paginated list of course alerts.
 * Per Story 8.6 AC-1: targeting filter support.
 */
public class CourseAlertListResponse {

    private List<CourseAlertResponse> alerts;
    private Pagination pagination;

    public CourseAlertListResponse() {}

    public CourseAlertListResponse(List<CourseAlertResponse> alerts, Pagination pagination) {
        this.alerts = alerts;
        this.pagination = pagination;
    }

    public List<CourseAlertResponse> getAlerts() { return alerts; }
    public void setAlerts(List<CourseAlertResponse> alerts) { this.alerts = alerts; }

    public Pagination getPagination() { return pagination; }
    public void setPagination(Pagination pagination) { this.pagination = pagination; }

    /**
     * Pagination metadata for the list response.
     */
    public static class Pagination {
        private int page;
        private int size;
        private long totalElements;
        private int totalPages;
        private boolean first;
        private boolean last;
        private String nextPageToken;

        public Pagination() {}

        public Pagination(int page, int size, long totalElements, int totalPages, boolean first, boolean last, String nextPageToken) {
            this.page = page;
            this.size = size;
            this.totalElements = totalElements;
            this.totalPages = totalPages;
            this.first = first;
            this.last = last;
            this.nextPageToken = nextPageToken;
        }

        public int getPage() { return page; }
        public void setPage(int page) { this.page = page; }

        public int getSize() { return size; }
        public void setSize(int size) { this.size = size; }

        public long getTotalElements() { return totalElements; }
        public void setTotalElements(long totalElements) { this.totalElements = totalElements; }

        public int getTotalPages() { return totalPages; }
        public void setTotalPages(int totalPages) { this.totalPages = totalPages; }

        public boolean isFirst() { return first; }
        public void setFirst(boolean first) { this.first = first; }

        public boolean isLast() { return last; }
        public void setLast(boolean last) { this.last = last; }

        public String getNextPageToken() { return nextPageToken; }
        public void setNextPageToken(String nextPageToken) { this.nextPageToken = nextPageToken; }
    }
}
