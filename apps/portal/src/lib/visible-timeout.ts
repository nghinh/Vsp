/**
 * A timeout that only counts time the page is actually on screen.
 *
 * The motivating case is a map that has not finished loading. MapLibre
 * announces a finished load from its render loop, and that loop is driven by
 * requestAnimationFrame, which browsers suspend for a background tab. A plain
 * wall-clock timeout cannot tell "this is taking too long" from "nobody has
 * been looking at it" — so opening the geometry editor, switching tabs, and
 * coming back a minute later reported a broken basemap when nothing was wrong.
 *
 * The rule here is that a deadline for a human should be measured in time that
 * human spent waiting. A tick that lands on a hidden page re-arms instead of
 * firing.
 *
 * This deliberately does not accumulate partial visible time: if the page is
 * hidden when the deadline arrives, the full period starts over. For a
 * "something is wrong" backstop that is the safer direction to round — the
 * cost of waiting longer is a spinner, and the cost of firing early is telling
 * somebody their map is broken when it is not. Anything that needs true
 * accumulated visible time wants a different tool.
 */

export interface VisibleTimeoutOptions {
  /** Overridable for tests; defaults to the real document. */
  isVisible?: () => boolean;
}

export interface VisibleTimeout {
  /** Stop the timeout. Safe to call more than once, and after it has fired. */
  cancel(): void;
  /** Whether the callback has already run. */
  readonly fired: boolean;
}

/**
 * Run {@link onElapsed} once, after {@link ms} milliseconds of page-visible time.
 */
export function visibleTimeout(
  ms: number,
  onElapsed: () => void,
  options: VisibleTimeoutOptions = {}
): VisibleTimeout {
  const isVisible =
    options.isVisible ??
    (() => typeof document === 'undefined' || document.visibilityState === 'visible');

  let handle: ReturnType<typeof setTimeout> | null = null;
  let cancelled = false;
  let fired = false;

  const arm = () => {
    handle = setTimeout(() => {
      handle = null;
      if (cancelled) return;
      if (!isVisible()) {
        // Not late — unobserved. Start the clock again.
        arm();
        return;
      }
      fired = true;
      onElapsed();
    }, ms);
  };

  arm();

  return {
    cancel() {
      cancelled = true;
      if (handle !== null) {
        clearTimeout(handle);
        handle = null;
      }
    },
    get fired() {
      return fired;
    },
  };
}
