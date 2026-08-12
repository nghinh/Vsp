import type { CorrectionTypeValue } from '@/types/correction';

/**
 * What a correction is about, in Vietnamese.
 *
 * One copy, because there were three: the queue table, the detail panel and
 * the official-data panel each carried their own map of the same enum. They
 * agreed only by luck, and they stopped agreeing the moment the first one was
 * translated — leaving a reviewer looking at "Vị trí cắm cờ" in the list and
 * "Pin Position" on the record it opened.
 *
 * Bunker keeps its name: Vietnamese golfers say bunker.
 */
export const CORRECTION_TYPE_LABELS: Record<CorrectionTypeValue, string> = {
  GEOMETRY: 'Hình học',
  PIN_POSITION: 'Vị trí cắm cờ',
  BUNKER: 'Bunker',
  WATER: 'Chướng ngại nước',
  OB: 'Ngoài biên',
  CART_PATH: 'Đường xe điện',
  LANDMARK: 'Mốc định vị',
  COURSE_CONDITION: 'Tình trạng sân',
  GREEN_SPEED: 'Tốc độ green',
  SCORECARD: 'Bảng điểm sân',
  OTHER: 'Khác',
};

/** Falls back to the raw enum rather than inventing a label for it. */
export function correctionTypeLabel(type: CorrectionTypeValue): string {
  return CORRECTION_TYPE_LABELS[type] ?? type;
}
