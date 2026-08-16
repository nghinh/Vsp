package vnpt.vsp.module.geometry.vision;

/**
 * The patch of ground a satellite image covers, and how to read a pixel back
 * onto it.
 *
 * <p>Longitude is linear across the image; latitude is not — Web Mercator
 * stretches it, more so the further from the equator. Interpolating latitude
 * linearly would put a green a few metres north of where it is, consistently,
 * and nothing on the map would look wrong.
 */
public record ImageBounds(double north, double south, double east, double west,
                          int zoom) {

    /// Longitude at a fraction across the image, 0 at the left edge.
    public double longitudeAt(double x) {
        return west + (east - west) * x;
    }

    /// Latitude at a fraction down the image, 0 at the top. Interpolated in
    /// tile space, which is where the projection is linear.
    public double latitudeAt(double y) {
        double topTileY = WebMercator.tileY(north, zoom);
        double bottomTileY = WebMercator.tileY(south, zoom);
        return WebMercator.latitudeOfTileY(
                topTileY + (bottomTileY - topTileY) * y, zoom);
    }
}
