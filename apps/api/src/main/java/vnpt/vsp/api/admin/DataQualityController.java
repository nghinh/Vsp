package vnpt.vsp.api.admin;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.Audited;
import vnpt.vsp.module.dataquality.dto.DataQualityExportDto;
import vnpt.vsp.module.dataquality.dto.DataQualityMetricsDto;
import vnpt.vsp.module.dataquality.dto.DataQualityQueryRequest;
import vnpt.vsp.module.dataquality.dto.StaleRecordDto;
import vnpt.vsp.module.dataquality.service.DataQualityService;
import vnpt.vsp.module.dataquality.service.StaleRecordService;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * REST controller for data quality dashboard endpoints.
 * Per Story 9.4 Wave 1 and Slice Plan.
 *
 * Endpoints:
 * - GET /admin/data-quality/metrics  — geometry completeness, verified courses,
 *                                       Class A/B coverage, correction volume, resolution time
 * - GET /admin/data-quality/stale    — stale pin, green speed, course condition records
 * - GET /admin/data-quality/export   — CSV/XLSX export of metrics + stale records
 *
 * RBAC: SUPER_ADMIN, COURSE_ADMIN, AUDITOR only.
 */
@RestController
@RequestMapping("/admin/data-quality")
public class DataQualityController {

    private static final Logger log = LoggerFactory.getLogger(DataQualityController.class);

    private static final int MAX_EXPORT_DAYS = 90;
    private static final DateTimeFormatter ISO_DATE = DateTimeFormatter.ISO_LOCAL_DATE;

    private final DataQualityService dataQualityService;
    private final StaleRecordService staleRecordService;
    private final RoleService roleService;

    public DataQualityController(
            DataQualityService dataQualityService,
            StaleRecordService staleRecordService,
            RoleService roleService) {
        this.dataQualityService = dataQualityService;
        this.staleRecordService = staleRecordService;
        this.roleService = roleService;
    }

    /**
     * GET /admin/data-quality/metrics
     *
     * Returns data quality metrics for the given filter criteria.
     */
    @GetMapping("/metrics")
    @PreAuthorize("hasRole(#authentication, 'SUPER_ADMIN') or hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'AUDITOR')")
    public ResponseEntity<DataQualityMetricsDto> getMetrics(
            Authentication authentication,
            @RequestParam(required = false) Long facilityId,
            @RequestParam(required = false) Long courseId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {

        Long accountId = (Long) authentication.getPrincipal();
        requireDataQualityAccess(accountId);

        log.info("GET /admin/data-quality/metrics accountId={} facilityId={} courseId={} from={} to={}",
                accountId, facilityId, courseId, from, to);

        validateDateRange(from, to);

        DataQualityQueryRequest request = new DataQualityQueryRequest();
        request.setFacilityId(facilityId);
        request.setCourseId(courseId);
        request.setFromDate(from);
        request.setToDate(to);

        DataQualityMetricsDto metrics = dataQualityService.computeMetrics(request);
        return ResponseEntity.ok(metrics);
    }

    /**
     * GET /admin/data-quality/stale
     *
     * Returns stale pin, green speed, and course condition records.
     */
    @GetMapping("/stale")
    @PreAuthorize("hasRole(#authentication, 'SUPER_ADMIN') or hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'AUDITOR')")
    public ResponseEntity<List<StaleRecordDto>> getStaleRecords(
            Authentication authentication,
            @RequestParam(required = false) Long facilityId,
            @RequestParam(required = false) Long courseId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireDataQualityAccess(accountId);

        log.info("GET /admin/data-quality/stale accountId={} facilityId={} courseId={}",
                accountId, facilityId, courseId);

        List<StaleRecordDto> staleRecords = staleRecordService.findAllStaleRecords(facilityId, courseId);
        return ResponseEntity.ok(staleRecords);
    }

    /**
     * GET /admin/data-quality/export
     *
     * Exports data quality metrics and stale records as CSV or XLSX.
     * Enforces 90-day maximum date range per Slice Plan risk mitigation.
     */
    @GetMapping("/export")
    @PreAuthorize("hasRole(#authentication, 'SUPER_ADMIN') or hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'AUDITOR')")
    @Audited(action = AuditAction.DATA_QUALITY_METRICS_EXPORT, objectType = "DataQuality")
    public ResponseEntity<String> exportDataQuality(
            Authentication authentication,
            @RequestParam(required = false) Long facilityId,
            @RequestParam(required = false) Long courseId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "csv") String format) {

        Long accountId = (Long) authentication.getPrincipal();
        requireDataQualityAccess(accountId);

        log.info("GET /admin/data-quality/export accountId={} facilityId={} courseId={} from={} to={} format={}",
                accountId, facilityId, courseId, from, to, format);

        validateDateRange(from, to);
        validateExportFormat(format);

        DataQualityQueryRequest request = new DataQualityQueryRequest();
        request.setFacilityId(facilityId);
        request.setCourseId(courseId);
        request.setFromDate(from);
        request.setToDate(to);

        DataQualityMetricsDto metrics = dataQualityService.computeMetrics(request);
        List<StaleRecordDto> staleRecords = staleRecordService.findAllStaleRecords(facilityId, courseId);

        String csv = buildCsvExport(metrics, staleRecords, from, to);

        String filename = String.format("data-quality-export-%s-to-%s.%s",
                from.format(ISO_DATE), to.format(ISO_DATE), format);

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("text/csv"))
                .body(csv);
    }

    private void requireDataQualityAccess(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.SUPER_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.AUDITOR)) {
            throw new VspApiException(VspErrorCode.AUTH_005,
                    "SUPER_ADMIN, COURSE_ADMIN, or AUDITOR role required");
        }
    }

    private void validateDateRange(LocalDate from, LocalDate to) {
        if (from == null || to == null) {
            throw new VspApiException(VspErrorCode.VALIDATION_001, "from and to dates are required");
        }
        if (to.isBefore(from)) {
            throw new VspApiException(VspErrorCode.VALIDATION_001, "to date must be after from date");
        }
        long daysBetween = java.time.temporal.ChronoUnit.DAYS.between(from, to);
        if (daysBetween > MAX_EXPORT_DAYS) {
            throw new VspApiException(VspErrorCode.VALIDATION_001,
                    "Date range exceeds maximum of " + MAX_EXPORT_DAYS + " days");
        }
    }

    private void validateExportFormat(String format) {
        if (!format.equalsIgnoreCase("csv") && !format.equalsIgnoreCase("xlsx")) {
            throw new VspApiException(VspErrorCode.VALIDATION_001,
                    "format must be 'csv' or 'xlsx'");
        }
    }

    private String buildCsvExport(DataQualityMetricsDto metrics, List<StaleRecordDto> staleRecords,
                                   LocalDate from, LocalDate to) {
        StringBuilder sb = new StringBuilder();

        // Metrics section
        sb.append("# Data Quality Metrics\n");
        sb.append("# Period: ").append(from).append(" to ").append(to).append("\n");
        sb.append("geometry_completeness,verified_courses,total_courses,class_ab_coverage,correction_volume,avg_resolution_hours,median_resolution_hours\n");
        sb.append(metrics.getGeometryCompleteness()).append(",")
          .append(metrics.getVerifiedCoursesCount()).append(",")
          .append(metrics.getTotalCoursesCount()).append(",")
          .append(metrics.getClassABCoverage()).append(",")
          .append(metrics.getCorrectionVolume()).append(",")
          .append(metrics.getAvgResolutionTimeHours()).append(",")
          .append(metrics.getMedianResolutionTimeHours()).append("\n");

        // Stale records section
        sb.append("\n# Stale Records\n");
        sb.append("record_type,record_id,facility_id,facility_name,course_id,course_name,holl_number,expired_at,severity\n");
        for (StaleRecordDto s : staleRecords) {
            sb.append(s.getRecordType()).append(",")
              .append(s.getRecordId()).append(",")
              .append(s.getFacilityId()).append(",")
              .append(escapeCsv(s.getFacilityName())).append(",")
              .append(s.getCourseId()).append(",")
              .append(escapeCsv(s.getCourseName())).append(",")
              .append(s.getHoleNumber()).append(",")
              .append(s.getExpiredAt()).append(",")
              .append(s.getSeverity()).append("\n");
        }

        return sb.toString();
    }

    private String escapeCsv(String value) {
        if (value == null) {
            return "";
        }
        if (value.contains(",") || value.contains("\"") || value.contains("\n")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }
}
