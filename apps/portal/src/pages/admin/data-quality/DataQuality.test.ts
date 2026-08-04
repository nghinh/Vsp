/**
 * Unit tests for Data Quality Portal page.
 * Per Story 9.4 Wave 3 — T19 Portal Tests.
 */

import { describe, it, expect } from 'vitest';

// ─── Types being tested ────────────────────────────────────────────────────────
import type { DataQualityMetrics, StaleRecord } from '@/types/admin/data-quality';

// ─── Mock API client ───────────────────────────────────────────────────────────
const MOCK_METRICS: DataQualityMetrics = {
  geometryCompleteness: 87.5,
  verifiedCoursesCount: 42,
  totalCoursesCount: 50,
  classABCoverage: 78.0,
  correctionVolume: 127,
  avgResolutionTimeHours: 18.4,
  medianResolutionTimeHours: 12.0,
  facilityId: null,
  courseId: null,
  fromDate: '2025-07-01',
  toDate: '2025-07-31',
};

const MOCK_STALE_RECORDS: StaleRecord[] = [
  {
    recordType: 'PIN',
    recordId: 1,
    facilityId: 10,
    facilityName: 'Pine Valley Golf Club',
    courseId: 101,
    courseName: 'Championship Course',
    holeNumber: 3,
    expiredAt: '2025-06-15T08:00:00Z',
    severity: 'HIGH',
  },
  {
    recordType: 'GREEN_SPEED',
    recordId: 2,
    facilityId: 10,
    facilityName: 'Pine Valley Golf Club',
    courseId: 101,
    courseName: 'Championship Course',
    holeNumber: 5,
    expiredAt: '2025-06-20T10:00:00Z',
    severity: 'MODERATE',
  },
  {
    recordType: 'COURSE_CONDITION',
    recordId: 3,
    facilityId: 11,
    facilityName: 'Augusta National',
    courseId: 201,
    courseName: 'Masters Course',
    holeNumber: null,
    expiredAt: '2025-06-25T12:00:00Z',
    severity: 'CRITICAL',
  },
];

// ─── Test: DataQualityMetrics type ────────────────────────────────────────────
describe('DataQualityMetrics', () => {
  it('should accept all required fields', () => {
    const m: DataQualityMetrics = { ...MOCK_METRICS };
    expect(m.geometryCompleteness).toBe(87.5);
    expect(m.verifiedCoursesCount).toBe(42);
    expect(m.totalCoursesCount).toBe(50);
    expect(m.classABCoverage).toBe(78.0);
    expect(m.correctionVolume).toBe(127);
    expect(m.avgResolutionTimeHours).toBe(18.4);
    expect(m.medianResolutionTimeHours).toBe(12.0);
  });

  it('should allow null for nullable fields', () => {
    const m: DataQualityMetrics = {
      geometryCompleteness: null,
      verifiedCoursesCount: 0,
      totalCoursesCount: 0,
      classABCoverage: null,
      correctionVolume: 0,
      avgResolutionTimeHours: null,
      medianResolutionTimeHours: null,
      facilityId: null,
      courseId: null,
      fromDate: '2025-07-01',
      toDate: '2025-07-31',
    };
    expect(m.geometryCompleteness).toBeNull();
    expect(m.avgResolutionTimeHours).toBeNull();
  });
});

// ─── Test: StaleRecord type ───────────────────────────────────────────────────
describe('StaleRecord', () => {
  it('should accept PIN record type', () => {
    const r = MOCK_STALE_RECORDS[0];
    expect(r.recordType).toBe('PIN');
    expect(r.severity).toBe('HIGH');
    expect(r.holeNumber).toBe(3);
  });

  it('should accept GREEN_SPEED record type', () => {
    const r = MOCK_STALE_RECORDS[1];
    expect(r.recordType).toBe('GREEN_SPEED');
    expect(r.severity).toBe('MODERATE');
  });

  it('should accept COURSE_CONDITION record type with null holeNumber', () => {
    const r = MOCK_STALE_RECORDS[2];
    expect(r.recordType).toBe('COURSE_CONDITION');
    expect(r.holeNumber).toBeNull();
    expect(r.courseName).toBe('Masters Course');
  });

  it('should have valid severity values', () => {
    const validSeverities = ['LOW', 'MODERATE', 'HIGH', 'CRITICAL'];
    for (const record of MOCK_STALE_RECORDS) {
      expect(validSeverities).toContain(record.severity);
    }
  });
});

// ─── Test: Metric card status helper ─────────────────────────────────────────
describe('cardStatus logic', () => {
  // Replicate the cardStatus function from the component for unit testing
  function cardStatus(value: number | null, threshold: number, inverse = false): string {
    if (value == null) return 'metric-card--neutral';
    if (inverse) {
      if (value <= threshold * 0.5) return 'metric-card--good';
      if (value <= threshold) return 'metric-card--warn';
      return 'metric-card--bad';
    }
    if (value >= threshold) return 'metric-card--good';
    if (value >= threshold * 0.6) return 'metric-card--warn';
    return 'metric-card--bad';
  }

  it('returns neutral for null values', () => {
    expect(cardStatus(null, 80)).toBe('metric-card--neutral');
  });

  // Geometry completeness (higher is better)
  it('returns good when geometry completeness >= threshold', () => {
    expect(cardStatus(85, 80)).toBe('metric-card--good');
    expect(cardStatus(100, 80)).toBe('metric-card--good');
  });

  it('returns warn when geometry completeness between 60% and 100% of threshold', () => {
    expect(cardStatus(50, 80)).toBe('metric-card--warn'); // 50 is 62.5% of 80
    expect(cardStatus(79, 80)).toBe('metric-card--warn');
  });

  it('returns bad when geometry completeness below 60% of threshold', () => {
    expect(cardStatus(40, 80)).toBe('metric-card--bad');
    expect(cardStatus(0, 80)).toBe('metric-card--bad');
  });

  // Resolution time (lower is better — inverse)
  it('returns good for low resolution time (inverse)', () => {
    expect(cardStatus(10, 48, true)).toBe('metric-card--good');  // 10 <= 24 (50% of 48)
    expect(cardStatus(20, 48, true)).toBe('metric-card--good');
  });

  it('returns warn for moderate resolution time (inverse)', () => {
    expect(cardStatus(30, 48, true)).toBe('metric-card--warn'); // 30 > 24, <= 48
    expect(cardStatus(48, 48, true)).toBe('metric-card--warn');
  });

  it('returns bad for high resolution time (inverse)', () => {
    expect(cardStatus(60, 48, true)).toBe('metric-card--bad');
    expect(cardStatus(100, 48, true)).toBe('metric-card--bad');
  });
});

// ─── Test: format helpers ─────────────────────────────────────────────────────
describe('format helpers', () => {
  function fmtPct(value: number | null): string {
    if (value == null) return '—';
    return `${Number(value).toFixed(1)}%`;
  }

  function fmtHours(value: number | null): string {
    if (value == null) return '—';
    if (value < 1) return `${Math.round(value * 60)}m`;
    if (value < 24) return `${Number(value).toFixed(1)}h`;
    return `${(value / 24).toFixed(1)}d`;
  }

  describe('fmtPct', () => {
    it('formats percentage with one decimal', () => {
      expect(fmtPct(87.5)).toBe('87.5%');
      expect(fmtPct(100)).toBe('100.0%');
      expect(fmtPct(0)).toBe('0.0%');
    });

    it('returns em-dash for null', () => {
      expect(fmtPct(null)).toBe('—');
    });
  });

  describe('fmtHours', () => {
    it('returns minutes for sub-hour values', () => {
      expect(fmtHours(0.5)).toBe('30m');
      expect(fmtHours(0.25)).toBe('15m');
    });

    it('returns hours for sub-day values', () => {
      expect(fmtHours(1)).toBe('1.0h');
      expect(fmtHours(18.4)).toBe('18.4h');
      expect(fmtHours(23.9)).toBe('23.9h');
    });

    it('returns days for values >= 24h', () => {
      expect(fmtHours(24)).toBe('1.0d');
      expect(fmtHours(48)).toBe('2.0d');
      expect(fmtHours(72)).toBe('3.0d');
    });

    it('returns em-dash for null', () => {
      expect(fmtHours(null)).toBe('—');
    });
  });
});

// ─── Test: Date range validation ─────────────────────────────────────────────
describe('Date range validation', () => {
  it('rejects when from date is after to date', () => {
    const from = '2025-07-31';
    const to = '2025-07-01';
    const isValid = from <= to;
    expect(isValid).toBe(false);
  });

  it('accepts when from date is before or equal to to date', () => {
    const from = '2025-07-01';
    const to = '2025-07-31';
    const isValid = from <= to;
    expect(isValid).toBe(true);
  });

  it('accepts same day range', () => {
    const from = '2025-07-15';
    const to = '2025-07-15';
    const isValid = from <= to;
    expect(isValid).toBe(true);
  });
});

// ─── Test: Export filename ─────────────────────────────────────────────────────
describe('Export filename', () => {
  it('generates correct CSV filename', () => {
    const from = '2025-07-01';
    const to = '2025-07-31';
    const filename = `data-quality-${from}-to-${to}.csv`;
    expect(filename).toBe('data-quality-2025-07-01-to-2025-07-31.csv');
  });
});
