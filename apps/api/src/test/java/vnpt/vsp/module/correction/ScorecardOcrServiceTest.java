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
        return new ScorecardOcrService(objectMapper, "sk-test-key", baseUrl, "image");
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
    @DisplayName("no key configured is a field error, not a call to nowhere")
    void staysOffWithoutAKey() {
        var off = new ScorecardOcrService(objectMapper, "  ", baseUrl(), "image");

        assertThat(off.isEnabled()).isFalse();
        assertThatThrownBy(() -> off.extractCourse(new byte[]{1}, "image/jpeg"))
                .isInstanceOf(VspApiException.class)
                .asInstanceOf(type(VspApiException.class))
                .extracting(e -> e.getDetails().get("image"))
                .isEqualTo("scorecard reading is not configured on this server");
        assertThat(pathsAsked).isEmpty();
    }
}
