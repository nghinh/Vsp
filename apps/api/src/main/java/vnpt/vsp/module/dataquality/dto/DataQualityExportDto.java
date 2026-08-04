package vnpt.vsp.module.dataquality.dto;

import java.util.List;

/**
 * Data quality export response returned by GET /admin/data-quality/export.
 * Per Story 9.4 AC2 and Slice Plan Wave 1.
 */
public class DataQualityExportDto {

    /** Export format: csv or xlsx. */
    private String format;

    /** Number of data rows in the export. */
    private int rowCount;

    /** Exported metric records. */
    private List<DataQualityMetricsDto> metrics;

    /** Stale records exported. */
    private List<StaleRecordDto> staleRecords;

    public DataQualityExportDto() {}

    public DataQualityExportDto(String format, List<DataQualityMetricsDto> metrics, List<StaleRecordDto> staleRecords) {
        this.format = format;
        this.metrics = metrics;
        this.staleRecords = staleRecords;
        this.rowCount = (metrics != null ? metrics.size() : 0) + (staleRecords != null ? staleRecords.size() : 0);
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getFormat() {
        return format;
    }

    public void setFormat(String format) {
        this.format = format;
    }

    public int getRowCount() {
        return rowCount;
    }

    public void setRowCount(int rowCount) {
        this.rowCount = rowCount;
    }

    public List<DataQualityMetricsDto> getMetrics() {
        return metrics;
    }

    public void setMetrics(List<DataQualityMetricsDto> metrics) {
        this.metrics = metrics;
    }

    public List<StaleRecordDto> getStaleRecords() {
        return staleRecords;
    }

    public void setStaleRecords(List<StaleRecordDto> staleRecords) {
        this.staleRecords = staleRecords;
    }
}
