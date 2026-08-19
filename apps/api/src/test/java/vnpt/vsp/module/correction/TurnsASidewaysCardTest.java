package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * A card lying sideways in the photograph is turned and read again.
 *
 * <p>Measured on a real one: Hilltop Valley, four players, folded and
 * photographed on a car seat with the card lying across the frame. Read as
 * photographed, the model found all four rows and could make out two legible
 * cells out of eighteen on the best of them. The same photograph turned a
 * quarter turn: four rows, sixteen and seventeen cells each, and identical
 * between runs.
 *
 * <p>EXIF cannot fix this. The phone was held the right way up — it is the card
 * on the seat that is sideways, and no orientation tag records that. Nor does a
 * card lie one way round: across the frame, its first hole can be at either
 * end. So a thin read is retried on a turned copy, both ways if it has to be,
 * and whichever saw more of the card wins.
 *
 * <p>The cost is one extra model call — two when the first turn was the wrong
 * one — and only on a read so thin it was of no use anyway.
 */
class TurnsASidewaysCardTest {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private HttpServer server;
    private final AtomicInteger asks = new AtomicInteger();
    private final List<String> answers = new ArrayList<>();

    @BeforeEach
    void startGateway() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            try (InputStream in = exchange.getRequestBody()) {
                in.readAllBytes();
            }
            int n = asks.getAndIncrement();
            String body = answers.get(Math.min(n, answers.size() - 1));
            try {
                respond(exchange, 200, openAiAnswer(body));
            } catch (IOException e) {
                throw e;
            } catch (Exception e) {
                throw new IOException(e);
            }
        });
        server.start();
    }

    @AfterEach
    void stopGateway() {
        server.stop(0);
    }

    private void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("content-type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }

    private String openAiAnswer(String content) throws Exception {
        return """
                {"id": "r", "object": "chat.completion",
                 "choices": [{"index": 0, "finish_reason": "stop",
                              "message": {"role": "assistant", "content": %s}}]}
                """.formatted(objectMapper.writeValueAsString(content));
    }

    private ScorecardOcrService service() {
        return new ScorecardOcrService(objectMapper,
                new vnpt.vsp.module.ai.LlmGateway(objectMapper, "sk-test",
                        "http://127.0.0.1:" + server.getAddress().getPort(), "image"));
    }

    /** A real JPEG, so the rotation has something to turn. */
    private byte[] jpeg() throws Exception {
        var image = new BufferedImage(120, 60, BufferedImage.TYPE_INT_RGB);
        var out = new ByteArrayOutputStream();
        ImageIO.write(image, "jpg", out);
        return out.toByteArray();
    }

    /** A row with [cells] holes filled in and the rest unreadable. */
    private String rowWith(int cells) {
        var holes = new StringBuilder();
        for (int hole = 1; hole <= 18; hole++) {
            if (hole > 1) holes.append(",");
            holes.append("{\"hole\":").append(hole).append(",\"written\":")
                 .append(hole <= cells ? "4" : "null").append("}");
        }
        return "{\"players\":[{\"player\":\"A\",\"notation\":\"strokes\",\"holes\":["
                + holes + "]}]}";
    }

    @Test
    @DisplayName("a thin read is tried again on a turned copy")
    void turnsAndKeepsTheBetterRead() throws Exception {
        answers.add(rowWith(2));   // as photographed: barely anything
        answers.add(rowWith(17));  // turned: nearly the whole card

        String result = service().extractScores(jpeg(), "image/jpeg");

        assertThat(asks.get())
                .as("a card this thin is worth turning over")
                .isEqualTo(2);
        assertThat(cellsIn(result)).isEqualTo(17);
    }

    @Test
    @DisplayName("a good read is not asked for twice")
    void doesNotPayTwiceForAnAnswerItHas() throws Exception {
        // The retry costs a model call. It has to be rare, and it has to be
        // driven by the answer rather than by hope.
        answers.add(rowWith(18));

        service().extractScores(jpeg(), "image/jpeg");

        assertThat(asks.get()).isEqualTo(1);
    }

    @Test
    @DisplayName("and the upright read is kept when turning reads less")
    void keepsTheBestOfWhatItSaw() throws Exception {
        answers.add(rowWith(9));
        answers.add(rowWith(1));
        answers.add(rowWith(4));

        String result = service().extractScores(jpeg(), "image/jpeg");

        assertThat(cellsIn(result))
                .as("turning is an attempt, not a decision")
                .isEqualTo(9);
    }

    @Test
    @DisplayName("a card lying the other way round is turned the other way")
    void triesBothQuarterTurns() throws Exception {
        // A card across the frame can have its first hole at either end, and
        // one quarter turn only ever fixes one of the two. The real one turned
        // clockwise; the golfer who lays it down the other way is owed the
        // same read.
        answers.add(rowWith(2));   // as photographed
        answers.add(rowWith(3));   // turned one way: still nothing
        answers.add(rowWith(17));  // turned the other: the whole card

        String result = service().extractScores(jpeg(), "image/jpeg");

        assertThat(asks.get()).isEqualTo(3);
        assertThat(cellsIn(result)).isEqualTo(17);
    }

    @Test
    @DisplayName("and stops turning as soon as it can read the card")
    void stopsAtTheFirstGoodTurn() throws Exception {
        answers.add(rowWith(2));
        answers.add(rowWith(17));
        answers.add(rowWith(18));

        service().extractScores(jpeg(), "image/jpeg");

        assertThat(asks.get())
                .as("the third call buys nothing once the card has been read")
                .isEqualTo(2);
    }

    @Test
    @DisplayName("a picture the model refuses is still shown to it turned")
    void turnsAPictureTheModelWouldNotRead() throws Exception {
        // Measured on the Korean card: stood upright the model answered with
        // nothing this could parse, and a quarter turn of the same picture
        // answered fine. A refusal at one angle used to end the whole read.
        answers.add("I'm sorry, I can't help with that.");
        answers.add(rowWith(17));

        String result = service().extractScores(jpeg(), "image/jpeg");

        assertThat(cellsIn(result)).isEqualTo(17);
    }

    @Test
    @DisplayName("and a card refused at every angle keeps its own complaint")
    void doesNotInventANewFailure() throws Exception {
        answers.add("I'm sorry, I can't help with that.");

        assertThatThrownBy(() -> service().extractScores(jpeg(), "image/jpeg"))
                .isInstanceOf(vnpt.vsp.api.error.VspApiException.class);
        assertThat(asks.get()).isEqualTo(3);
    }

    @Test
    @DisplayName("a row that adds up beats a fuller row that does not")
    void trustsTheCardsOwnArithmetic() throws Exception {
        // Cells alone rank a fabrication above the truth. The sideways read of
        // the Korean card filled every one of its cells with numbers that are
        // on no row of the card, while an honest read of a smudged card leaves
        // cells null. The total the golfer wrote at the end of their own row is
        // the one piece of arithmetic the card checks itself with.
        answers.add(rowWith(2));            // as photographed: thin
        answers.add(frontNine(4, 41));      // turned: nine cells that add up to nothing
        answers.add(frontNine(4, 36));      // turned back: the same nine, and they add up

        String result = service().extractScores(jpeg(), "image/jpeg");

        JsonNode checks = objectMapper.readTree(result).get("players").get(0).get("checks");
        assertThat(checks.get("outAgrees").asBoolean())
                .as("both reads have nine cells — only one of them adds up")
                .isTrue();
        assertThat(checks.get("writtenOut").asInt()).isEqualTo(36);
    }

    /** A front nine of [stroke], with [writtenOut] claimed at the end of it. */
    private String frontNine(int stroke, Integer writtenOut) {
        var holes = new StringBuilder();
        for (int hole = 1; hole <= 18; hole++) {
            if (hole > 1) holes.append(",");
            holes.append("{\"hole\":").append(hole).append(",\"written\":")
                 .append(hole <= 9 ? String.valueOf(stroke) : "null").append("}");
        }
        return "{\"players\":[{\"player\":\"A\",\"notation\":\"strokes\",\"writtenOut\":"
                + writtenOut + ",\"holes\":[" + holes + "]}]}";
    }

    /** How many holes an answer actually has a number for. */
    private long cellsIn(String result) throws Exception {
        JsonNode holes = objectMapper.readTree(result).get("players").get(0).get("holes");
        long read = 0;
        for (var hole : holes) {
            if (!hole.get("written").isNull()) read++;
        }
        return read;
    }
}
