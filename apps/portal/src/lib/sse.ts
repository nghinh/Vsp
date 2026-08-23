/**
 * A server-sent-events subscription that can carry a bearer token.
 *
 * The leaderboard used `new EventSource(url)`. An EventSource cannot set
 * request headers, and the API reads the token from `Authorization` and
 * nowhere else — so the stream was refused with 401 on every open, the
 * `onerror` handler closed it quietly, and the live leaderboard was a
 * 30-second poll that called itself live. On top of that the server names its
 * frames (`event: leaderboard`), which `onmessage` never receives.
 *
 * This reads the stream with `fetch`, which can send the header, and parses
 * the event-stream framing by hand: `event:` and `data:` lines, blank line
 * ends a frame, `:` starts a comment (the keep-alive ping).
 */
export interface SseFrame {
  event: string;
  data: string;
}

export interface SseHandle {
  close(): void;
}

export function subscribeSse(
  url: string,
  token: string,
  onFrame: (frame: SseFrame) => void,
  onClose: (error?: unknown) => void = () => {},
): SseHandle {
  const controller = new AbortController();
  let closed = false;

  const finish = (error?: unknown) => {
    if (closed) return;
    closed = true;
    onClose(error);
  };

  (async () => {
    try {
      const res = await fetch(url, {
        headers: { Accept: 'text/event-stream', Authorization: `Bearer ${token}` },
        signal: controller.signal,
      });
      if (!res.ok || !res.body) {
        finish(new Error(`SSE ${res.status}`));
        return;
      }
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let event = 'message';
      let data: string[] = [];
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        let nl: number;
        while ((nl = buffer.indexOf('\n')) >= 0) {
          const line = buffer.slice(0, nl).replace(/\r$/, '');
          buffer = buffer.slice(nl + 1);
          if (line === '') {
            if (data.length) onFrame({ event, data: data.join('\n') });
            event = 'message';
            data = [];
          } else if (line.startsWith(':')) {
            // comment / keep-alive
          } else {
            const colon = line.indexOf(':');
            const field = colon < 0 ? line : line.slice(0, colon);
            const value = colon < 0 ? '' : line.slice(colon + 1).replace(/^ /, '');
            if (field === 'event') event = value;
            else if (field === 'data') data.push(value);
          }
        }
      }
      finish();
    } catch (error) {
      if (controller.signal.aborted) finish();
      else finish(error);
    }
  })();

  return {
    close() {
      controller.abort();
      finish();
    },
  };
}
