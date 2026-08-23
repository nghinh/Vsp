/**
 * Vietnamese labels for the enum values the server sends.
 *
 * The portal has no i18n catalogue and `vietnamese-ui.test.ts` keeps English
 * out of the strings written in the source. It cannot see this class of
 * string: an enum constant arrives as data, gets interpolated with `{{ }}`,
 * and no literal in any `.vue` file ever spells it. So the screens were full
 * of `D_UNVERIFIED_COMMUNITY`, `PENDING_REVIEW`, `COURSE_OVERALL` and
 * `CADDIE_MASTER` — the database's spelling, shown to a greenkeeper.
 *
 * One module rather than a map per page, for the reason `correction-labels.ts`
 * already gives: copies agree only by luck, and stop agreeing the moment one
 * is edited.
 *
 * Every lookup falls back to the raw value. A label that is missing should
 * look like a gap in this file, not like a blank cell — and a server that
 * adds an enum constant must not be able to blank a column here.
 */

function label(map: Record<string, string>, value: string | null | undefined): string {
  if (value === null || value === undefined || value === '') return '—';
  return map[value] ?? value;
}

// ─── Course data provenance ──────────────────────────────────────────────────

/**
 * `AccuracyClass`, per PRD 9.4. The letter is the grade operators talk in —
 * "hạng A" — so it leads, and the source follows it.
 */
export const ACCURACY_CLASS_LABELS: Record<string, string> = {
  A_RTK_SURVEYED: 'A · Đo RTK',
  B_LICENSED_PROVIDER: 'B · Nhà cung cấp có bản quyền',
  C_VERIFIED_SATELLITE: 'C · Vệ tinh đã kiểm',
  D_UNVERIFIED_COMMUNITY: 'D · Cộng đồng, chưa kiểm',
};

/** Just the grade letter, for a badge with no room for the source. */
export const ACCURACY_CLASS_SHORT: Record<string, string> = {
  A_RTK_SURVEYED: 'A',
  B_LICENSED_PROVIDER: 'B',
  C_VERIFIED_SATELLITE: 'C',
  D_UNVERIFIED_COMMUNITY: 'D',
};

export const VERIFICATION_STATUS_LABELS: Record<string, string> = {
  UNVERIFIED: 'Chưa xác minh',
  PENDING_REVIEW: 'Chờ duyệt',
  VERIFIED: 'Đã xác minh',
  REJECTED: 'Đã từ chối',
};

export const accuracyClassLabel = (v?: string | null) => label(ACCURACY_CLASS_LABELS, v);
export const accuracyClassShort = (v?: string | null) => label(ACCURACY_CLASS_SHORT, v);
export const verificationStatusLabel = (v?: string | null) =>
  label(VERIFICATION_STATUS_LABELS, v);

// ─── Greenkeeping ────────────────────────────────────────────────────────────

export const PIN_POSITION_TYPE_LABELS: Record<string, string> = {
  CURRENT: 'Thường ngày',
  TOURNAMENT: 'Giải đấu',
  PRACTICE: 'Tập luyện',
};

export const CONDITION_TYPE_LABELS: Record<string, string> = {
  GREEN_SPEED: 'Tốc độ green',
  GREEN_FIRMNESS: 'Độ cứng green',
  FAIRWAY_FIRMNESS: 'Độ cứng fairway',
  ROUGH_DENSITY: 'Độ dày rough',
  BUNKER_CONDITION: 'Tình trạng bunker',
  COURSE_MOISTURE: 'Độ ẩm sân',
  COURSE_OVERALL: 'Tổng thể sân',
  WEATHER_IMPACT: 'Ảnh hưởng thời tiết',
  OTHER: 'Khác',
};

export const SEVERITY_LABELS: Record<string, string> = {
  LOW: 'Nhẹ',
  MODERATE: 'Vừa',
  HIGH: 'Nặng',
  CRITICAL: 'Nghiêm trọng',
};

export const FIRMNESS_LABELS: Record<string, string> = {
  SOFT: 'Mềm',
  MEDIUM: 'Vừa',
  FIRM: 'Chắc',
  HARD: 'Cứng',
};

export const MOISTURE_LABELS: Record<string, string> = {
  DRY: 'Khô',
  NORMAL: 'Bình thường',
  WET: 'Ướt',
  SATURATED: 'Sũng nước',
};

/** `DataQuality`'s expired-record table: which kind of record lapsed. */
export const RECORD_TYPE_LABELS: Record<string, string> = {
  PIN: 'Vị trí cờ',
  GREEN_SPEED: 'Tốc độ green',
  COURSE_CONDITION: 'Tình trạng sân',
};

export const pinPositionTypeLabel = (v?: string | null) => label(PIN_POSITION_TYPE_LABELS, v);
export const recordTypeLabel = (v?: string | null) => label(RECORD_TYPE_LABELS, v);
export const conditionTypeLabel = (v?: string | null) => label(CONDITION_TYPE_LABELS, v);
export const severityLabel = (v?: string | null) => label(SEVERITY_LABELS, v);
export const firmnessLabel = (v?: string | null) => label(FIRMNESS_LABELS, v);
export const moistureLabel = (v?: string | null) => label(MOISTURE_LABELS, v);

// ─── Alerts ──────────────────────────────────────────────────────────────────

export const ALERT_TYPE_LABELS: Record<string, string> = {
  SAFETY: 'An toàn',
  PROMOTION: 'Khuyến mãi',
};

export const ALERT_TARGET_LABELS: Record<string, string> = {
  FACILITY: 'Cả cơ sở',
  COURSE: 'Cả sân',
  HOLE: 'Một hố',
  FLIGHT: 'Một flight',
  GROUP: 'Một nhóm',
};

export const ALERT_PRIORITY_LABELS: Record<string, string> = {
  LOW: 'Thấp',
  NORMAL: 'Bình thường',
  HIGH: 'Cao',
  URGENT: 'Khẩn cấp',
};

export const DELIVERY_STATUS_LABELS: Record<string, string> = {
  PENDING: 'Đang gửi',
  DELIVERED: 'Đã gửi',
  FAILED: 'Gửi lỗi',
};

export const alertTypeLabel = (v?: string | null) => label(ALERT_TYPE_LABELS, v);
export const alertTargetLabel = (v?: string | null) => label(ALERT_TARGET_LABELS, v);
export const alertPriorityLabel = (v?: string | null) => label(ALERT_PRIORITY_LABELS, v);
export const deliveryStatusLabel = (v?: string | null) => label(DELIVERY_STATUS_LABELS, v);

// ─── Tournaments ─────────────────────────────────────────────────────────────

/**
 * Stroke play, match play and Stableford keep their English names: that is
 * what the entry sheet says and what the players say. `vietnamese-ui.test.ts`
 * already allows all three for the same reason.
 */
export const TOURNAMENT_FORMAT_LABELS: Record<string, string> = {
  STROKE_PLAY: 'Đấu gậy (Stroke Play)',
  MATCH_PLAY: 'Đấu đối kháng (Match Play)',
  STABLEFORD: 'Stableford',
};

export const TOURNAMENT_STATUS_LABELS: Record<string, string> = {
  DRAFT: 'Bản nháp',
  REGISTRATION_OPEN: 'Đang mở đăng ký',
  IN_PROGRESS: 'Đang thi đấu',
  COMPLETED: 'Đã kết thúc',
  CANCELLED: 'Đã huỷ',
};

export const PLAYER_STATUS_LABELS: Record<string, string> = {
  REGISTERED: 'Đã đăng ký',
  CONFIRMED: 'Đã xác nhận',
  WITHDRAWN: 'Đã rút',
  DISQUALIFIED: 'Bị loại',
};

export const STARTING_TEE_LABELS: Record<string, string> = {
  FRONT: 'Hố 1',
  BACK: 'Hố 10',
};

export const TIE_BREAK_RULE_LABELS: Record<string, string> = {
  SCORECARD_PLAYOFF: 'So bảng điểm',
  EXACT_HANDICAP: 'Handicap chính xác',
  LOWEST_ROUND: 'Vòng thấp nhất',
  MOST_BIRDIES: 'Nhiều birdie nhất',
  DRAW: 'Bốc thăm',
};

export const tournamentFormatLabel = (v?: string | null) => label(TOURNAMENT_FORMAT_LABELS, v);
export const tournamentStatusLabel = (v?: string | null) => label(TOURNAMENT_STATUS_LABELS, v);
export const playerStatusLabel = (v?: string | null) => label(PLAYER_STATUS_LABELS, v);
export const startingTeeLabel = (v?: string | null) => label(STARTING_TEE_LABELS, v);
export const tieBreakRuleLabel = (v?: string | null) => label(TIE_BREAK_RULE_LABELS, v);

// ─── Roles ───────────────────────────────────────────────────────────────────

/**
 * The six operator roles. `roles.ts` holds the names the guard matches on;
 * this holds what a human is shown. Kept apart on purpose — a label is
 * cosmetic and a role name is a decision, and they must not be edited as one
 * thing.
 */
export const ROLE_LABELS: Record<string, string> = {
  SUPER_ADMIN: 'Quản trị hệ thống',
  COURSE_ADMIN: 'Quản trị sân',
  GREENKEEPER: 'Chăm sóc sân',
  TOURNAMENT_DIRECTOR: 'Điều hành giải',
  CADDIE_MASTER: 'Quản lý caddie',
  AUDITOR: 'Kiểm toán',
};

export const roleLabel = (v?: string | null) => label(ROLE_LABELS, v);

// ─── Golfers ─────────────────────────────────────────────────────────────────

/**
 * What to call a golfer on a roster, a score grid or a results board.
 *
 * `displayName` is nullable on every outing DTO the server sends, and each of
 * the six places that renders it printed it straight — so an account without a
 * name produced a blank first column. On the score grid that is the column the
 * director reads to know whose line they are typing into, and a blank one next
 * to eighteen empty boxes is worse than a wrong name.
 *
 * The VGA code comes next because it is the other thing printed on the entry
 * sheet, and only then a placeholder that says what is missing.
 */
export function golferLabel(p: {
  displayName?: string | null;
  vgaCode?: string | null;
}): string {
  return p.displayName?.trim() || p.vgaCode?.trim() || 'Chưa có tên';
}
