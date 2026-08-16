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

    /// Where a place sits in this image, as fractions from the left and the
    /// top — the inverse of the two readers here.
    ///
    /// This is how the model can be told where the tee is in terms it can
    /// actually see. Given a latitude instead, it has nothing in the picture
    /// to compare against, and it anchors on whatever looks like a tee.
    public double[] fractionOf(double latitude, double longitude) {
        double topTileY = WebMercator.tileY(north, zoom);
        double bottomTileY = WebMercator.tileY(south, zoom);
        double y = (WebMercator.tileY(latitude, zoom) - topTileY)
                / (bottomTileY - topTileY);
        double x = (longitude - west) / (east - west);
        return new double[]{x, y};
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
