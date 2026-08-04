/**
 * TypeScript types for Data Quality Admin API.
 * Per Story 9.4 Wave 2.
 */


/** Data quality metric snapshot from GET /admin/data-quality/metrics. */
export interface DataQualityMetrics {
  geometryCompleteness: number | null;   // 0-100 percentage
  verifiedCoursesCount: number;
  totalCoursesCount: number;
  classABCoverage: number | null;        // 0-100 percentage
  correctionVolume: number;
  avgResolutionTimeHours: number | null;
  medianResolutionTimeHours: number | null;
  facilityId: number | null;
  courseId: number | null;
  fromDate: string;  // ISO date
  toDate: string;    // ISO date
}

/** Stale record entry from GET /admin/data-quality/stale. */
export interface StaleRecord {
  recordType: 'PIN' | 'GREEN_SPEED' | 'COURSE_CONDITION';
  recordId: number;
  facilityId: number;
  facilityName: string;
  courseId: number | null;
  courseName: string | null;
  holeNumber: number | null;
  expiredAt: string;  // ISO instant
  severity: 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL';
}

/** Query parameters for data quality metrics. */
export interface DataQualityQuery {
  facilityId?: number;
  courseId?: number;
  from: string;  // ISO date (required)
  to: string;    // ISO date (required)
}

/** Facility option for the filter bar. */
export interface FacilityOption {
  id: number;
  name: string;
}

/** Course option for the filter bar. */
export interface CourseOption {
  id: number;
  name: string;
  facilityId: number;
}

/** API error response shape (shared across all admin endpoints). */
export interface ApiError {
  code: string;
  message: string;
  correlationId?: string;
  field?: string;
  details?: Record<string, unknown>;
}
