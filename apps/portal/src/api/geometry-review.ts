/**
 * Geometry review — the gate between imported course data and course data the
 * app is willing to draw.
 *
 * Everything the OSM pipeline imports lands as PENDING_REVIEW, and the mobile
 * app refuses to draw a strategic map or run automatic hole detection against
 * anything short of VERIFIED. These two calls are the only way a hole crosses
 * that line, and crossing it is a claim a person makes.
 */
import { getAuthToken } from '../auth';
import { API_BASE } from './base';

const BASE = API_BASE;

export interface HoleReviewItem {
  holeNumber: number;
  par: number | null;
  lengthMeters: number | null;
  /** e.g. `osm:way/1017320363`, or `SEED` for a hole nobody digitised. */
  source: string | null;
  accuracyClass: string | null;
  verificationStatus: string | null;
  hasCoordinates: boolean;
  greens: number;
  bunkers: number;
  teeBoxes: number;
  /** False when there is nothing here a reviewer could have looked at. */
  reviewable: boolean;
  /**
   * False when this par is impossible for a hole of this length.
   *
   * Par came from the seed script that invented the coordinates, and the OSM
   * import replaced every length with a measured one without touching par — so
   * the two now contradict each other on 42 of the 100 matched holes.
   */
  parMatchesLength: boolean;
  /**
   * The par this length would ordinarily carry, when the recorded one is
   * impossible. A prompt for a reviewer holding the scorecard — no measurement
   * can decide whether a 380 m hole is a long par 4 or a short par 5.
   */
  suggestedPar: number | null;
}

export interface GeometryReviewSummary {
  courseId: number;
  courseName: string;
  holes: HoleReviewItem[];
  pendingHoles: number;
  verifiedHoles: number;
  unverifiedHoles: number;
  /** Par summed across the holes. */
  holeParTotal: number;
  /**
   * Par the course itself advertises. A mismatch with `holeParTotal` means at
   * least one hole's par is still wrong — including holes whose par is
   * individually plausible and therefore flagged by nothing else.
   */
  courseParTotal: number | null;
}

export interface CorrectParResponse {
  changedHoleNumbers: number[];
  unchangedHoleNumbers: number[];
  unknownHoleNumbers: number[];
  /** Applied, but still contradicting the measured length. */
  stillImplausible: number[];
  correctedAt: string;
  reviewer: string;
}

export interface VerifyGeometryResponse {
  verifiedHoleNumbers: number[];
  refusedHoleNumbers: number[];
  verifiedAt: string;
  reviewer: string;
}

async function handle<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let message = res.statusText;
    try {
      const body = (await res.json()) as { message?: string };
      message = body.message ?? message;
    } catch {
      // A response with no JSON body — keep the status text.
    }
    throw new Error(message);
  }
  return (await res.json()) as T;
}

export async function fetchGeometryReview(
  courseId: number,
): Promise<GeometryReviewSummary> {
  const res = await fetch(
    `${BASE}/admin/courses/${courseId}/geometry/review`,
    { headers: { Authorization: `Bearer ${getAuthToken()}` } },
  );
  return handle<GeometryReviewSummary>(res);
}

export async function verifyGeometry(
  courseId: number,
  holeNumbers: number[],
  note: string,
): Promise<VerifyGeometryResponse> {
  const res = await fetch(
    `${BASE}/admin/courses/${courseId}/geometry/verify`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${getAuthToken()}`,
      },
      body: JSON.stringify({ holeNumbers, note }),
    },
  );
  return handle<VerifyGeometryResponse>(res);
}

/**
 * Sets par on the named holes from the course's scorecard.
 *
 * Separate from verification because it is a different claim from a different
 * source: coordinates are checked against a map, par against a printed card.
 */
export async function correctPar(
  courseId: number,
  holes: { holeNumber: number; par: number }[],
  note: string,
): Promise<CorrectParResponse> {
  const res = await fetch(
    `${BASE}/admin/courses/${courseId}/geometry/par`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${getAuthToken()}`,
      },
      body: JSON.stringify({ holes, note }),
    },
  );
  return handle<CorrectParResponse>(res);
}
