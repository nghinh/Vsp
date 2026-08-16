package vnpt.vsp.module.geometry.vision;

/**
 * The arithmetic between a place on Earth and a pixel in a satellite tile.
 *
 * <p>Everything the vision service does rests on this. The model looks at an
 * image and answers in image coordinates; if the conversion back to latitude
 * and longitude is wrong by a factor or a sign, the drafted bunker lands in
 * the next province and nothing about the polygon itself looks suspicious. So
 * it is pure arithmetic, in its own class, with its own tests.
 *
 * <p>Standard XYZ slippy-map tiles: 256 px, zoom doubling each level, y
 * counted from the north. Web Mercator, which every tile provider serves and
 * which stretches latitude — the reason y is not linear in degrees.
 */
public final class WebMercator {

    public static final int TILE_SIZE = 256;

    private WebMercator() {}

    /// Fractional tile x for a longitude — the whole part is the tile, the
    /// fraction is how far across it.
    public static double tileX(double longitude, int zoom) {
        return (longitude + 180.0) / 360.0 * (1 << zoom);
    }

    /// Fractional tile y for a latitude.
    public static double tileY(double latitude, int zoom) {
        double lat = Math.toRadians(latitude);
        return (1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI)
                / 2 * (1 << zoom);
    }

    public static double longitudeOfTileX(double tileX, int zoom) {
        return tileX / (1 << zoom) * 360.0 - 180.0;
    }

    public static double latitudeOfTileY(double tileY, int zoom) {
        double n = Math.PI - 2.0 * Math.PI * tileY / (1 << zoom);
        return Math.toDegrees(Math.atan(Math.sinh(n)));
    }

    /**
     * The deepest zoom at which a bounding box still fits in an image of
     * {@code maxPixels} on a side.
     *
     * <p>Deeper is better — the model sees more — until the stitched image
     * gets too big to send. A hole is 300–500 m long, which is zoom 17 or 18
     * in a 1024 px frame.
     */
    public static int zoomFor(double south, double west, double north, double east,
                              int maxPixels, int maxZoom) {
        for (int zoom = Math.min(maxZoom, 21); zoom >= 1; zoom--) {
            double width = Math.abs(tileX(east, zoom) - tileX(west, zoom)) * TILE_SIZE;
            double height = Math.abs(tileY(south, zoom) - tileY(north, zoom)) * TILE_SIZE;
            if (width <= maxPixels && height <= maxPixels) {
                return zoom;
            }
        }
        return 1;
    }
}
