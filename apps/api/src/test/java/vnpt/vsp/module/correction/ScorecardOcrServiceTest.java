package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import vnpt.vsp.api.error.VspApiException;

import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.InstanceOfAssertFactories.type;

/**
 * The gateway this reads cards through routes one model alias at whatever
 * model its operator has pointed it at, and the shape of the answer follows
 * the model rather than the request. That is not hypothetical: the alias was
 * repointed from Gemma to a GPT model between one afternoon and the next, the
 * answers changed from Anthropic `content` blocks to an OpenAI
 * `chat.completion`, and every scan on the phone became a 500 with the typed
 * client failing on "`content` is not set".
 *
 * <p>So both shapes are pinned here, against a real HTTP server rather than a
 * mocked client — the failure was in the wire format, which a mock of our own
 * transport would have agreed with us about.
 */
class ScorecardOcrServiceTest {

    private static final String CARD_JSON = """
            {"name": "A + B", "parTotal": 36,
             "holes": [{"hole": 1, "par": 4, "strokeIndex": 7},
                       {"hole": 2, "par": 5, "strokeIndex": 3}]}
            """;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private HttpServer server;
    private final List<String> pathsAsked = new ArrayList<>();
    private final AtomicReference<JsonNode> lastRequest = new AtomicReference<>();

    @BeforeEach
    void startGateway() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.start();
    }

    @AfterEach
    void stopGateway() {
        server.stop(0);
    }

    private String baseUrl() {
        return "http://127.0.0.1:" + server.getAddress().getPort();
    }

    /** Answer this path with this body, and remember what was asked. */
    private void serve(String path, int status, String body) {
        server.createContext(path, exchange -> {
            pathsAsked.add(exchange.getRequestURI().getPath());
            try (InputStream in = exchange.getRequestBody()) {
                lastRequest.set(objectMapper.readTree(in.readAllBytes()));
            } catch (Exception e) {
                lastRequest.set(null);
            }
            respond(exchange, status, body);
        });
    }

    private void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("content-type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }

    private ScorecardOcrService service(String baseUrl) {
        return new ScorecardOcrService(objectMapper,
                new vnpt.vsp.module.ai.LlmGateway(objectMapper, "sk-test-key", baseUrl, "image"));
    }

    private String openAiAnswer(String content) throws Exception {
        return """
                {"id": "resp_1", "object": "chat.completion", "model": "gpt-5.4-mini",
                 "choices": [{"index": 0, "finish_reason": "stop",
                              "message": {"role": "assistant", "content": %s}}]}
                """.formatted(objectMapper.writeValueAsString(content));
    }

    private String anthropicAnswer(String text) throws Exception {
        return """
                {"id": "msg_1", "type": "message", "role": "assistant",
                 "stop_reason": "end_turn",
                 "content": [{"type": "text", "text": %s}]}
                """.formatted(objectMapper.writeValueAsString(text));
    }

    @Test
    @DisplayName("reads a card out of an OpenAI-shaped answer — the shape that broke production")
    void readsOpenAiShape() throws Exception {
        serve("/v1/chat/completions", 200, openAiAnswer(CARD_JSON));

        String card = service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg");

        assertThat(objectMapper.readTree(card).get("holes")).hasSize(2);
        assertThat(objectMapper.readTree(card).get("name").asText()).isEqualTo("A + B");
    }

    @Test
    @DisplayName("a tee row is checked against the sums the club printed beside it")
    void checksYardagesAgainstTheCardsOwnSums() throws Exception {
        // The par row has always had this test. The yardage rows had none,
        // while being ten times the cells: five tees over eighteen holes is
        // ninety three-digit numbers against par's eighteen single digits.
        // A hole read 450 instead of 400 now contradicts the club's own OUT.
        String misread = """
                {"name": "A + B", "parTotal": 8,
                 "holes": [{"hole": 1, "par": 4}, {"hole": 2, "par": 4}],
                 "tees": [{"name": "GOLD", "yardsOut": 800, "yardsTotal": 800,
                           "yardages": [{"hole": 1, "yards": 450},
                                        {"hole": 2, "yards": 400}]}]}
                """;
        serve("/v1/chat/completions", 200, openAiAnswer(misread));

        var tee = objectMapper.readTree(
                service(baseUrl()).extractCourse(new byte[]{1}, "image/jpeg"))
                .get("tees").get(0).get("checks");

        assertThat(tee.get("yardsOutRead").asInt()).isEqualTo(850);
        assertThat(tee.get("yardsOutPrinted").asInt()).isEqualTo(800);
        assertThat(tee.get("yardsAgree").asBoolean()).isFalse();
        assertThat(tee.get("yardsChecked").asBoolean()).isTrue();
    }

    @Test
    @DisplayName("a tee row that adds up says so, quietly")
    void agreesWhenTheYardagesAddUp() throws Exception {
        String clean = """
                {"name": "A + B", "parTotal": 8,
                 "holes": [{"hole": 1, "par": 4}, {"hole": 2, "par": 4}],
                 "tees": [{"name": "GOLD", "yardsOut": 800, "yardsTotal": 800,
                           "yardages": [{"hole": 1, "yards": 400},
                                        {"hole": 2, "yards": 400}]}]}
                """;
        serve("/v1/chat/completions", 200, openAiAnswer(clean));

        var tee = objectMapper.readTree(
                service(baseUrl()).extractCourse(new byte[]{1}, "image/jpeg"))
                .get("tees").get(0).get("checks");

        assertThat(tee.get("yardsAgree").asBoolean()).isTrue();
        assertThat(tee.get("yardsChecked").asBoolean()).isTrue();
    }

    @Test
    @DisplayName("a card that prints no sums is unchecked, not approved")
    void saysWhenNothingCouldBeChecked() throws Exception {
        // Silence and a green tick are different answers. Plenty of cards
        // print no per-tee totals, and calling those verified would put a
        // reviewer's trust behind a check that never ran.
        String noSums = """
                {"name": "A + B", "parTotal": 8,
                 "holes": [{"hole": 1, "par": 4}, {"hole": 2, "par": 4}],
                 "tees": [{"name": "GOLD",
                           "yardages": [{"hole": 1, "yards": 400}]}]}
                """;
        serve("/v1/chat/completions", 200, openAiAnswer(noSums));

        var tee = objectMapper.readTree(
                service(baseUrl()).extractCourse(new byte[]{1}, "image/jpeg"))
                .get("tees").get(0).get("checks");

        assertThat(tee.get("yardsChecked").isNull()).isTrue();
        assertThat(tee.get("yardsAgree").asBoolean()).isTrue();
    }

    @Test
    @DisplayName("a back nine outside the frame is absent, not a contradiction")
    void doesNotFlagANineThePhotographNeverCaught() throws Exception {
        // A front-nine photograph of an eighteen-hole card still shows the
        // card's TOTAL. Judging the back nine against it would flag every
        // half-card anyone submits.
        String frontOnly = """
                {"name": "A", "parTotal": 8,
                 "holes": [{"hole": 1, "par": 4}, {"hole": 2, "par": 4}],
                 "tees": [{"name": "GOLD", "yardsOut": 800,
                           "yardages": [{"hole": 1, "yards": 400},
                                        {"hole": 2, "yards": 400}]}]}
                """;
        serve("/v1/chat/completions", 200, openAiAnswer(frontOnly));

        var tee = objectMapper.readTree(
                service(baseUrl()).extractCourse(new byte[]{1}, "image/jpeg"))
                .get("tees").get(0).get("checks");

        assertThat(tee.get("yardsAgree").asBoolean()).isTrue();
        assertThat(tee.get("yardsInRead").asInt()).isZero();
    }

    @Test
    @DisplayName("reads a card out of an Anthropic-shaped answer on the same path")
    void readsAnthropicShapeOnChatPath() throws Exception {
        // The router normalises nothing: it answered a chat-completions
        // request in Anthropic shape while it fronted a Claude model.
        serve("/v1/chat/completions", 200, anthropicAnswer(CARD_JSON));

        String card = service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg");

        assertThat(objectMapper.readTree(card).get("holes")).hasSize(2);
    }

    @Test
    @DisplayName("falls back to /v1/messages when the router does not serve chat completions")
    void fallsBackToMessages() throws Exception {
        serve("/v1/chat/completions", 404, "{\"error\":\"not found\"}");
        serve("/v1/messages", 200, anthropicAnswer(CARD_JSON));

        String card = service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg");

        assertThat(objectMapper.readTree(card).get("holes")).hasSize(2);
        assertThat(pathsAsked).containsExactly("/v1/chat/completions", "/v1/messages");
    }

    @Test
    @DisplayName("a base URL that already carries /v1 is not given a second one")
    void doesNotDoubleTheVersionSegment() throws Exception {
        serve("/v1/chat/completions", 200, openAiAnswer(CARD_JSON));

        // Both forms have been in this project's config: the gateway was
        // handed over as ".../v1" and deployed as the bare host.
        service(baseUrl() + "/v1").extractCourse(new byte[]{1, 2, 3}, "image/jpeg");

        assertThat(pathsAsked).containsExactly("/v1/chat/completions");
    }

    @Test
    @DisplayName("sends the photograph as a data URI the OpenAI surface can read")
    void sendsTheImageInline() throws Exception {
        serve("/v1/chat/completions", 200, openAiAnswer(CARD_JSON));

        service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/png");

        JsonNode content = lastRequest.get().get("messages").get(0).get("content");
        assertThat(content.get(0).get("image_url").get("url").asText())
                .isEqualTo("data:image/png;base64,AQID");
        assertThat(lastRequest.get().get("model").asText()).isEqualTo("image");
        // The gateway streams when `stream` is absent, and the answer then
        // arrives as server-sent events that no JSON parser will read.
        assertThat(lastRequest.get().get("stream").asBoolean()).isFalse();
    }

    @Test
    @DisplayName("a gateway error is reported as an unreadable image, not a 500")
    void reportsGatewayFailureAsAFieldError() {
        // 402: the routes on this gateway have run out of credit before.
        serve("/v1/chat/completions", 402, "{\"error\":{\"message\":\"insufficient credits\"}}");

        assertThatThrownBy(() -> service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg"))
                .isInstanceOf(VspApiException.class)
                .asInstanceOf(type(VspApiException.class))
                .extracting(e -> e.getDetails().get("image"))
                .isEqualTo("this image could not be read");
    }

    @Test
    @DisplayName("an answer with no text in it is an error, not an empty card")
    void rejectsAnAnswerWithNoText() {
        serve("/v1/chat/completions", 200, "{\"choices\":[{\"message\":{\"role\":\"assistant\"}}]}");

        assertThatThrownBy(() -> service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg"))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("a refusal is not read as a card")
    void rejectsARefusal() {
        serve("/v1/chat/completions", 200,
                "{\"choices\":[{\"finish_reason\":\"stop\","
                        + "\"message\":{\"role\":\"assistant\",\"refusal\":\"I can't help with that\"}}]}");

        assertThatThrownBy(() -> service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg"))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("reads a card out of a streamed answer — the gateway streams when it feels like it")
    void readsServerSentEvents() throws Exception {
        // This is not a guess at what some server might do. `stream` was
        // omitted once and this gateway streamed anyway; the answer arrived as
        // events and the parser died on the word "event". It is asked not to,
        // and it is read either way.
        var events = new StringBuilder();
        for (String piece : split(CARD_JSON)) {
            events.append("data: ").append(objectMapper.writeValueAsString(
                    objectMapper.createObjectNode().set("choices",
                            objectMapper.createArrayNode().add(
                                    objectMapper.createObjectNode().set("delta",
                                            objectMapper.createObjectNode().put("content", piece))))))
                    .append("\n\n");
        }
        events.append("data: [DONE]\n\n");
        serve("/v1/chat/completions", 200, events.toString());

        String card = service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg");

        assertThat(objectMapper.readTree(card).get("holes")).hasSize(2);
    }

    @Test
    @DisplayName("reads a card out of an Anthropic-streamed answer")
    void readsAnthropicServerSentEvents() throws Exception {
        var events = new StringBuilder();
        for (String piece : split(CARD_JSON)) {
            events.append("event: content_block_delta\n");
            events.append("data: {\"type\":\"content_block_delta\",\"delta\":")
                    .append("{\"type\":\"text_delta\",\"text\":")
                    .append(objectMapper.writeValueAsString(piece))
                    .append("}}\n\n");
        }
        serve("/v1/chat/completions", 200, events.toString());

        String card = service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg");

        assertThat(objectMapper.readTree(card).get("holes")).hasSize(2);
    }

    @Test
    @DisplayName("reads a card out of a Gemini-shaped answer")
    void readsGeminiShape() throws Exception {
        serve("/v1/chat/completions", 200, """
                {"candidates": [{"content": {"parts": [{"text": %s}]},
                                 "finishReason": "STOP"}]}
                """.formatted(objectMapper.writeValueAsString(CARD_JSON)));

        String card = service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg");

        assertThat(objectMapper.readTree(card).get("holes")).hasSize(2);
    }

    @Test
    @DisplayName("asks again with max_completion_tokens when the server wants that spelling")
    void retriesWithTheOtherTokenSpelling() throws Exception {
        // Newer OpenAI-shaped models reject `max_tokens` and name the
        // replacement in the 400. An operator who repoints the alias at one of
        // them should not lose an afternoon to a parameter name.
        var bodies = new ArrayList<String>();
        String success = openAiAnswer(CARD_JSON);
        server.createContext("/v1/chat/completions", exchange -> {
            String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            bodies.add(body);
            if (body.contains("\"max_tokens\"")) {
                respond(exchange, 400, "{\"error\":{\"message\":\"Use 'max_completion_tokens' instead.\"}}");
            } else {
                respond(exchange, 200, success);
            }
        });

        String card = service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg");

        assertThat(objectMapper.readTree(card).get("holes")).hasSize(2);
        assertThat(bodies).hasSize(2);
        assertThat(bodies.get(1)).contains("max_completion_tokens");
    }

    @Test
    @DisplayName("a 400 that is not about the token spelling is not retried")
    void doesNotRetryOtherBadRequests() {
        var calls = new ArrayList<String>();
        server.createContext("/v1/chat/completions", exchange -> {
            calls.add("x");
            respond(exchange, 400, "{\"error\":{\"message\":\"model not routed\"}}");
        });

        assertThatThrownBy(() -> service(baseUrl()).extractCourse(new byte[]{1, 2, 3}, "image/jpeg"))
                .isInstanceOf(VspApiException.class);
        assertThat(calls).hasSize(1);
    }

    @Test
    @DisplayName("a row of handwriting comes back with the golfer's own arithmetic")
    void checksARowAgainstItsWrittenTotals() throws Exception {
        // The check that earned its place: on the development card the back
        // nine read one hole wrong and summed to 2 against the 1 the golfer
        // had written in IN. Nothing in the numbers themselves showed it.
        serve("/v1/chat/completions", 200, openAiAnswer("""
                {"players": [{"player": "A", "notation": "to_par",
                              "writtenOut": 2, "writtenIn": 1,
                              "holes": [{"hole": 1, "written": 2},
                                        {"hole": 10, "written": 2}]}]}
                """));

        String scores = service(baseUrl()).extractScores(new byte[]{1, 2, 3}, "image/jpeg");
        var row = objectMapper.readTree(scores).get("players").get(0);

        assertThat(row.get("notation").asText()).isEqualTo("to_par");
        assertThat(row.get("checks").get("writtenOut").asInt()).isEqualTo(2);
        assertThat(row.get("checks").get("outAgrees").asBoolean()).isTrue();
        assertThat(row.get("checks").get("inAgrees").asBoolean()).isFalse();
    }

    @Test
    @DisplayName("a nine with an unread hole in it agrees with nothing")
    void doesNotClaimAgreementAcrossABlank() throws Exception {
        // A sum missing a hole matches its written total only by coincidence,
        // and claiming it disagrees would send the golfer hunting for a
        // misread that is really a blank they can already see.
        serve("/v1/chat/completions", 200, openAiAnswer("""
                {"players": [{"player": "A", "notation": "strokes",
                              "writtenOut": 9,
                              "holes": [{"hole": 1, "written": 4},
                                        {"hole": 2, "written": 5},
                                        {"hole": 3, "written": null}]}]}
                """));

        String scores = service(baseUrl()).extractScores(new byte[]{1, 2, 3}, "image/jpeg");
        var checks = objectMapper.readTree(scores).get("players").get(0).get("checks");

        assertThat(checks.get("cellsRead").asInt()).isEqualTo(2);
        assertThat(checks.get("outAgrees").asBoolean()).isFalse();
    }

    /// The answer in pieces, the way a stream delivers it.
    private static List<String> split(String text) {
        var pieces = new ArrayList<String>();
        for (int i = 0; i < text.length(); i += 17) {
            pieces.add(text.substring(i, Math.min(text.length(), i + 17)));
        }
        return pieces;
    }

    @Test
    @DisplayName("no key configured is a field error, not a call to nowhere")
    void staysOffWithoutAKey() {
        var off = new ScorecardOcrService(objectMapper,
                new vnpt.vsp.module.ai.LlmGateway(objectMapper, "  ", baseUrl(), "image"));

        assertThat(off.isEnabled()).isFalse();
        assertThatThrownBy(() -> off.extractCourse(new byte[]{1}, "image/jpeg"))
                .isInstanceOf(VspApiException.class)
                .asInstanceOf(type(VspApiException.class))
                .extracting(e -> e.getDetails().get("image"))
                .isEqualTo("scorecard reading is not configured on this server");
        assertThat(pathsAsked).isEmpty();
    }
}
