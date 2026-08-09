import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

import { visibleTimeout } from '../visible-timeout';

/**
 * These exist because of a bug that looked like a broken map.
 *
 * The geometry editor showed "Nền bản đồ tải quá lâu" on a map with nothing
 * wrong with it. MapLibre reports a finished load from a requestAnimationFrame
 * loop, browsers suspend that loop for a background tab, and the backstop
 * timeout counted the wait anyway. Switch tabs for twelve seconds, come back,
 * and the editor had already declared failure.
 */
describe('visibleTimeout', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('fires after the period when the page stays visible', () => {
    const onElapsed = vi.fn();
    visibleTimeout(12_000, onElapsed, { isVisible: () => true });

    vi.advanceTimersByTime(11_999);
    expect(onElapsed).not.toHaveBeenCalled();

    vi.advanceTimersByTime(1);
    expect(onElapsed).toHaveBeenCalledTimes(1);
  });

  it('does not fire while the page is hidden, however long it is hidden for', () => {
    const onElapsed = vi.fn();
    visibleTimeout(12_000, onElapsed, { isVisible: () => false });

    // Ten minutes in a background tab. This is the reported bug: the old
    // wall-clock timeout fired here and blamed the map.
    vi.advanceTimersByTime(600_000);

    expect(onElapsed).not.toHaveBeenCalled();
  });

  it('fires once the page comes back, after a further full period', () => {
    let visible = false;
    const onElapsed = vi.fn();
    visibleTimeout(12_000, onElapsed, { isVisible: () => visible });

    vi.advanceTimersByTime(600_000);
    expect(onElapsed).not.toHaveBeenCalled();

    visible = true;
    // Coming back does not fire it immediately — the deadline is time someone
    // spent waiting, and that person has waited none of it yet.
    vi.advanceTimersByTime(11_999);
    expect(onElapsed).not.toHaveBeenCalled();

    vi.advanceTimersByTime(1);
    expect(onElapsed).toHaveBeenCalledTimes(1);
  });

  it('fires only once', () => {
    const onElapsed = vi.fn();
    visibleTimeout(1_000, onElapsed, { isVisible: () => true });

    vi.advanceTimersByTime(60_000);

    expect(onElapsed).toHaveBeenCalledTimes(1);
  });

  it('does not fire after cancel', () => {
    const onElapsed = vi.fn();
    const timeout = visibleTimeout(12_000, onElapsed, { isVisible: () => true });

    timeout.cancel();
    vi.advanceTimersByTime(60_000);

    expect(onElapsed).not.toHaveBeenCalled();
  });

  it('does not fire after cancel, even when cancelled while hidden and re-armed', () => {
    // The unmount path: the operator navigates away from the editor while the
    // tab is in the background. A re-arming timer that ignored cancel would
    // keep a dead component's callback alive indefinitely.
    let visible = false;
    const onElapsed = vi.fn();
    const timeout = visibleTimeout(12_000, onElapsed, { isVisible: () => visible });

    vi.advanceTimersByTime(30_000); // re-armed at least twice
    timeout.cancel();
    visible = true;
    vi.advanceTimersByTime(60_000);

    expect(onElapsed).not.toHaveBeenCalled();
    expect(vi.getTimerCount()).toBe(0);
  });

  it('reports whether it fired', () => {
    let visible = false;
    const timeout = visibleTimeout(1_000, () => {}, { isVisible: () => visible });

    vi.advanceTimersByTime(10_000);
    expect(timeout.fired).toBe(false);

    visible = true;
    vi.advanceTimersByTime(1_000);
    expect(timeout.fired).toBe(true);
  });

  it('cancel is safe to call twice and after firing', () => {
    const timeout = visibleTimeout(1_000, () => {}, { isVisible: () => true });
    vi.advanceTimersByTime(1_000);

    expect(() => {
      timeout.cancel();
      timeout.cancel();
    }).not.toThrow();
  });

  it('treats a real visible document as visible by default', () => {
    // jsdom reports 'visible', so the production default must agree rather
    // than needing the option passed at every call site.
    const onElapsed = vi.fn();
    visibleTimeout(1_000, onElapsed);

    vi.advanceTimersByTime(1_000);

    expect(onElapsed).toHaveBeenCalledTimes(1);
  });
});
