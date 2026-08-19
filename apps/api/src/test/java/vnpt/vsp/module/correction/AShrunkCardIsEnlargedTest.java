package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * A card that arrived shrunk is enlarged before the model is asked to read it.
 *
 * <p>Measured on a real one: a Korean card, four players, shared through a chat
 * app at 598 by 1280. At that size the model returned three players and a set
 * of numbers that match no row on the card. The identical pixels enlarged to
 * 2560 returned four players, all four names, and a front nine that agrees with
 * the card hole for hole on one row and misses a single cell on two others.
 *
 * <p>Enlarging adds no information — it is the same photograph. What it buys is
 * the model's attention, and on a card of seventy-two handwritten cells that
 * turned out to be the difference between a usable read and a fabricated one.
 *
 * <p>A photograph taken in the app is never touched: it comes off the picker at
 * up to three thousand pixels, well over the threshold.
 */
class AShrunkCardIsEnlargedTest {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private HttpServer server;
    /** Every image the gateway was actually sent, in order. */
    private final List<BufferedImage> sent = new ArrayList<>();

    @BeforeEach
    void startGateway() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            try (InputStream in = exchange.getRequestBody()) {
                record(in.readAllBytes());
            }
            respond(exchange, aFullCard());
        });
        server.start();
    }

    @AfterEach
    void stopGateway() {
        server.stop(0);
    }

    /** Pulls the image back out of the request the gateway built. */
    private void record(byte[] request) {
        try {
            var url = objectMapper.readTree(request)
                    .get("messages").get(0).get("content").get(0)
                    .get("image_url").get("url").asText();
            byte[] bytes = Base64.getDecoder().decode(url.substring(url.indexOf(",") + 1));
            sent.add(ImageIO.read(new ByteArrayInputStream(bytes)));
        } catch (Exception e) {
            throw new IllegalStateException("could not read the image out of the request", e);
        }
    }

    private void respond(HttpExchange exchange, String content) throws IOException {
        String body = """
                {"choices": [{"message": {"content": %s}}]}
                """.formatted(quoted(content));
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("content-type", "application/json");
        exchange.sendResponseHeaders(200, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }

    private String quoted(String value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    /** A read good enough that nothing is retried. */
    private String aFullCard() {
        var holes = new StringBuilder();
        for (int hole = 1; hole <= 18; hole++) {
            if (hole > 1) holes.append(",");
            holes.append("{\"hole\":").append(hole).append(",\"written\":4}");
        }
        return "{\"players\":[{\"player\":\"A\",\"notation\":\"strokes\",\"holes\":["
                + holes + "]}]}";
    }

    private ScorecardOcrService service() {
        return new ScorecardOcrService(objectMapper,
                new vnpt.vsp.module.ai.LlmGateway(objectMapper, "sk-test",
                        "http://127.0.0.1:" + server.getAddress().getPort(), "image"));
    }

    private byte[] jpeg(int width, int height) throws Exception {
        var out = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB), "jpg", out);
        return out.toByteArray();
    }

    @Test
    @DisplayName("a card shared through a chat app is enlarged before it is read")
    void enlargesTheSizeThatFailed() throws Exception {
        service().extractScores(jpeg(598, 1280), "image/jpeg");

        assertThat(sent).hasSize(1);
        assertThat(Math.max(sent.get(0).getWidth(), sent.get(0).getHeight()))
                .as("this is the size the read failed at")
                .isEqualTo(2560);
    }

    @Test
    @DisplayName("and keeps its shape while doing it")
    void doesNotSquashTheCard() throws Exception {
        // A card stretched out of shape has its columns no longer above their
        // hole numbers, which is the one thing the model must not lose.
        service().extractScores(jpeg(598, 1280), "image/jpeg");

        var enlarged = sent.get(0);
        assertThat((double) enlarged.getWidth() / enlarged.getHeight())
                .isCloseTo(598.0 / 1280.0, org.assertj.core.data.Offset.offset(0.01));
    }

    @Test
    @DisplayName("a photograph taken in the app is sent untouched")
    void leavesACameraPhotographAlone() throws Exception {
        // The picker gives up to three thousand pixels. Re-encoding that would
        // cost a golfer detail and buy nothing.
        service().extractScores(jpeg(3000, 2250), "image/jpeg");

        var asSent = sent.get(0);
        assertThat(asSent.getWidth()).isEqualTo(3000);
        assertThat(asSent.getHeight()).isEqualTo(2250);
    }
}
