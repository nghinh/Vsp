/**
 * The bridge between an ISO instant and a `datetime-local` input.
 *
 * A `datetime-local` input has no timezone. Whatever `YYYY-MM-DDTHH:mm` it
 * holds is read as *local* time, and the API speaks UTC. Slicing an ISO string
 * straight into the field therefore shows a Vietnamese operator a time seven
 * hours earlier than the one on the list beside it — and because saving reads
 * the field back as local, each round of editing moved the pin another seven
 * hours into the past. Nothing errors; the schedule just quietly drifts.
 *
 * So: one conversion in each direction, in one place.
 */

/** An instant as the `YYYY-MM-DDTHH:mm` a `datetime-local` input expects. */
export function toLocalInput(value: Date | string | null | undefined): string {
  if (value == null || value === '') return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  // getTimezoneOffset is the offset *to* UTC, so subtracting it makes
  // toISOString print the local wall clock.
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
}

/** What a `datetime-local` input holds, as the UTC instant the API wants. */
export function fromLocalInput(value: string | null | undefined): string | null {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/** Now, ready for a `datetime-local` input. */
export function nowLocalInput(): string {
  return toLocalInput(new Date());
}

/** `h` hours from now, ready for a `datetime-local` input. */
export function hoursFromNowLocalInput(h: number): string {
  return toLocalInput(new Date(Date.now() + h * 3600_000));
}

/** The end of today (23:59 local), ready for a `datetime-local` input. */
export function endOfTodayLocalInput(): string {
  const d = new Date();
  d.setHours(23, 59, 0, 0);
  return toLocalInput(d);
}

/**
 * An instant, for reading.
 *
 * Guards the absent case, which is the whole reason this exists: eight pages
 * each had their own `formatInstant(iso) { return new Date(iso).toLocaleString() }`,
 * and `new Date(null)` is the Unix epoch, not an error. So a hole whose
 * createdAt the API never filled in rendered as "Created 1/1/1970" — on all
 * eighteen cards, looking for all the world like real data.
 */
export function formatInstant(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString('vi-VN');
}

/** The date part only. Same guard. */
export function formatDay(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleDateString('vi-VN');
}
