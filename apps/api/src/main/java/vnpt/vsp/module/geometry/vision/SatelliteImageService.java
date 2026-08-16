package vnpt.vsp.module.geometry.vision;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

/**
 * The satellite picture of one hole, stitched from the operator's own tiles.
 *
 * <p>Only the operator's configured imagery. A tile server nobody licensed is
 * a legal problem wearing a URL, and this project already refuses to serve
 * satellite tiles to the app without an attribution string for the same
 * reason — see {@code vsp.basemap.satellite-tile-url}.
 */
@Service
public class SatelliteImageService {

    private static final Logger log = LoggerFactory.getLogger(SatelliteImageService.class);

    /// Big enough for a model to see a bunker, small enough to send.
    private static final int MAX_PIXELS = 1024;

    private final String tileUrlTemplate;
    private final String attribution;
    private final int maxZoom;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    public SatelliteImageService(
            @Value("${vsp.basemap.satellite-tile-url:}") String tileUrlTemplate,
            @Value("${vsp.basemap.satellite-attribution:}") String attribution,
            @Value("${vsp.basemap.satellite-max-zoom:0}") int maxZoom) {
        this.tileUrlTemplate = tileUrlTemplate == null ? "" : tileUrlTemplate.trim();
        this.attribution = attribution == null ? "" : attribution.trim();
        this.maxZoom = maxZoom;
    }

    /// True when this deployment has imagery it is allowed to use.
    public boolean isConfigured() {
        return !tileUrlTemplate.isEmpty() && !attribution.isEmpty() && maxZoom > 0;
    }

    /**
     * The image covering a bounding box, and the ground it covers.
     *
     * <p>Returns null when the deployment has no licensed imagery, or when a
     * tile could not be fetched — a half-stitched image would be read as a
     * hole with half its features missing.
     */
    public StitchedImage fetch(double south, double west, double north, double east) {
        if (!isConfigured()) {
            return null;
        }
        int zoom = WebMercator.zoomFor(south, west, north, east, MAX_PIXELS, maxZoom);

        int minTileX = (int) Math.floor(WebMercator.tileX(west, zoom));
        int maxTileX = (int) Math.floor(WebMercator.tileX(east, zoom));
        int minTileY = (int) Math.floor(WebMercator.tileY(north, zoom));
        int maxTileY = (int) Math.floor(WebMercator.tileY(south, zoom));

        int columns = maxTileX - minTileX + 1;
        int rows = maxTileY - minTileY + 1;
        if (columns <= 0 || rows <= 0 || columns * rows > 64) {
            log.warn("Refusing a {}x{} tile stitch for a hole — the box is wrong",
                    columns, rows);
            return null;
        }

        BufferedImage canvas = new BufferedImage(
                columns * WebMercator.TILE_SIZE,
                rows * WebMercator.TILE_SIZE,
                BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = canvas.createGraphics();
        try {
            for (int x = minTileX; x <= maxTileX; x++) {
                for (int y = minTileY; y <= maxTileY; y++) {
                    BufferedImage tile = tile(zoom, x, y);
                    if (tile == null) {
                        return null;
                    }
                    graphics.drawImage(tile,
                            (x - minTileX) * WebMercator.TILE_SIZE,
                            (y - minTileY) * WebMercator.TILE_SIZE, null);
                }
            }
        } finally {
            graphics.dispose();
        }

        // The stitched image covers whole tiles, so its edges are not the
        // box that was asked for. The bounds returned describe what was
        // actually drawn — read a polygon against the wrong bounds and it
        // lands tens of metres out.
        var bounds = new ImageBounds(
                WebMercator.latitudeOfTileY(minTileY, zoom),
                WebMercator.latitudeOfTileY(maxTileY + 1.0, zoom),
                WebMercator.longitudeOfTileX(maxTileX + 1.0, zoom),
                WebMercator.longitudeOfTileX(minTileX, zoom),
                zoom);

        try {
            var png = new ByteArrayOutputStream();
            ImageIO.write(canvas, "png", png);
            return new StitchedImage(png.toByteArray(), bounds, attribution);
        } catch (Exception e) {
            log.warn("Could not encode the stitched satellite image: {}", e.getMessage());
            return null;
        }
    }

    private BufferedImage tile(int zoom, int x, int y) {
        String url = tileUrlTemplate
                .replace("{z}", Integer.toString(zoom))
                .replace("{x}", Integer.toString(x))
                .replace("{y}", Integer.toString(y));
        try {
            HttpResponse<byte[]> response = http.send(
                    HttpRequest.newBuilder(URI.create(url))
                            .timeout(Duration.ofSeconds(20))
                            .GET().build(),
                    HttpResponse.BodyHandlers.ofByteArray());
            if (response.statusCode() != 200) {
                log.warn("Satellite tile {} answered {}", url, response.statusCode());
                return null;
            }
            return ImageIO.read(new java.io.ByteArrayInputStream(response.body()));
        } catch (Exception e) {
            log.warn("Could not fetch satellite tile {}: {}", url, e.getMessage());
            return null;
        }
    }

    /// The picture, what it covers, and whose imagery it is.
    public record StitchedImage(byte[] png, ImageBounds bounds, String attribution) {}
}
