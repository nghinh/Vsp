package vnpt.vsp.module.geometry.vision;

import java.awt.image.BufferedImage;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

/**
 * Snapping a traced shape onto what the picture actually shows.
 *
 * <p>A language model asked to outline a bunker returns a smooth octagon of
 * about the right size in about the right place. Every bunker comes back the
 * same shape, because it is describing a bunker rather than tracing one — and
 * on the map that reads as a course somebody drew from memory.
 *
 * <p>The model is good at the part it is good at: knowing that this blob is
 * sand and that one is water. So its answer is kept as a seed, and the edge
 * is taken from the pixels: flood the region around the seed's centre by
 * colour, walk the boundary of what filled, and use that.
 *
 * <p>Where the flood produces something implausible — a couple of pixels, or
 * half the frame — the model's own outline stands. A wrong shape in roughly
 * the right place is worse than an approximate one, but an approximate one
 * is far better than nothing.
 */
public final class ShapeRefiner {

    /// How far a pixel's colour may sit from the seed's and still be the
    /// same feature. Sand and water are both flat in colour; grass is not,
    /// which is why fairways are not refined this way.
    private static final int DEFAULT_TOLERANCE = 38;

    /// The flood may not wander further than this multiple of the seed's own
    /// size — otherwise one pond leaks along a stream into the next hole.
    private static final double MAX_GROWTH = 2.5;

    /// Fewer pixels than this is noise, not a feature.
    private static final int MIN_PIXELS = 40;

    private ShapeRefiner() {}

    /**
     * The refined ring in image fractions, or null to keep the seed.
     *
     * @param image the stitched satellite picture the model was shown
     * @param seed  the model's own outline, in image fractions (x, y)
     */
    public static List<double[]> refine(BufferedImage image, List<double[]> seed) {
        return refine(image, seed, DEFAULT_TOLERANCE);
    }

    static List<double[]> refine(BufferedImage image, List<double[]> seed, int tolerance) {
        if (image == null || seed == null || seed.size() < 4) {
            return null;
        }
        int width = image.getWidth();
        int height = image.getHeight();

        // The seed's own extent, in pixels.
        double minX = 1, maxX = 0, minY = 1, maxY = 0;
        for (double[] point : seed) {
            minX = Math.min(minX, point[0]);
            maxX = Math.max(maxX, point[0]);
            minY = Math.min(minY, point[1]);
            maxY = Math.max(maxY, point[1]);
        }
        int seedWidth = (int) Math.round((maxX - minX) * width);
        int seedHeight = (int) Math.round((maxY - minY) * height);
        if (seedWidth < 3 || seedHeight < 3) {
            return null;
        }

        int centreX = (int) Math.round((minX + maxX) / 2 * width);
        int centreY = (int) Math.round((minY + maxY) / 2 * height);
        if (centreX < 0 || centreY < 0 || centreX >= width || centreY >= height) {
            return null;
        }

        // The window the flood may not leave.
        int growX = (int) Math.round(seedWidth * (MAX_GROWTH - 1) / 2);
        int growY = (int) Math.round(seedHeight * (MAX_GROWTH - 1) / 2);
        int left = Math.max(0, (int) Math.round(minX * width) - growX);
        int right = Math.min(width - 1, (int) Math.round(maxX * width) + growX);
        int top = Math.max(0, (int) Math.round(minY * height) - growY);
        int bottom = Math.min(height - 1, (int) Math.round(maxY * height) + growY);

        int seedRgb = image.getRGB(centreX, centreY);
        boolean[][] filled = new boolean[right - left + 1][bottom - top + 1];
        Deque<int[]> queue = new ArrayDeque<>();
        queue.add(new int[]{centreX, centreY});
        filled[centreX - left][centreY - top] = true;
        int count = 1;
        int limit = (right - left + 1) * (bottom - top + 1);

        while (!queue.isEmpty()) {
            int[] pixel = queue.poll();
            for (int[] step : new int[][]{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
                int x = pixel[0] + step[0];
                int y = pixel[1] + step[1];
                if (x < left || x > right || y < top || y > bottom) {
                    continue;
                }
                if (filled[x - left][y - top]) {
                    continue;
                }
                if (distance(seedRgb, image.getRGB(x, y)) > tolerance) {
                    continue;
                }
                filled[x - left][y - top] = true;
                count++;
                queue.add(new int[]{x, y});
            }
        }

        // Too small to be the feature, or so large the flood escaped into the
        // surrounding grass — either way the seed is the better answer.
        if (count < MIN_PIXELS || count > limit * 0.85) {
            return null;
        }
        return ring(filled, left, top, width, height);
    }

    /// Colour distance, per channel — enough to tell sand from grass and
    /// water from either, which is all this needs to do.
    private static int distance(int a, int b) {
        int dr = Math.abs(((a >> 16) & 0xFF) - ((b >> 16) & 0xFF));
        int dg = Math.abs(((a >> 8) & 0xFF) - ((b >> 8) & 0xFF));
        int db = Math.abs((a & 0xFF) - (b & 0xFF));
        return Math.max(dr, Math.max(dg, db));
    }

    /**
     * The outline of the filled region, as image fractions.
     *
     * <p>Sampled around the region's centre rather than walked pixel by
     * pixel: a per-pixel boundary is hundreds of vertices of jitter, and a
     * map draws it no better than sixty clean ones. Sixty rays from the
     * centre, each stopping where the fill stops.
     */
    private static List<double[]> ring(boolean[][] filled, int left, int top,
                                       int width, int height) {
        int cols = filled.length;
        int rows = filled[0].length;

        long sumX = 0;
        long sumY = 0;
        int count = 0;
        for (int x = 0; x < cols; x++) {
            for (int y = 0; y < rows; y++) {
                if (filled[x][y]) {
                    sumX += x;
                    sumY += y;
                    count++;
                }
            }
        }
        if (count == 0) {
            return null;
        }
        double cx = (double) sumX / count;
        double cy = (double) sumY / count;

        int rays = 60;
        double maxRadius = Math.hypot(cols, rows);
        var ring = new ArrayList<double[]>();
        for (int i = 0; i < rays; i++) {
            double angle = 2 * Math.PI * i / rays;
            double dx = Math.cos(angle);
            double dy = Math.sin(angle);
            double lastX = cx;
            double lastY = cy;
            for (double r = 1; r < maxRadius; r += 0.5) {
                int x = (int) Math.round(cx + dx * r);
                int y = (int) Math.round(cy + dy * r);
                if (x < 0 || y < 0 || x >= cols || y >= rows || !filled[x][y]) {
                    break;
                }
                lastX = x;
                lastY = y;
            }
            ring.add(new double[]{
                    (lastX + left) / width,
                    (lastY + top) / height,
            });
        }
        // Close it.
        ring.add(new double[]{ring.get(0)[0], ring.get(0)[1]});
        return ring;
    }
}
