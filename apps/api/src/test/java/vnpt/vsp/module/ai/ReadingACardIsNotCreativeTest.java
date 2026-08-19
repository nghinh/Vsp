package vnpt.vsp.module.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Every request this gateway sends asks for the same answer twice.
 *
 * <p>Nothing set a temperature, so the provider's default applied — around 1.0
 * on an OpenAI-shaped router — and the same photograph came back different
 * every time it was asked.
 *
 * <p>Measured on one real card: Hilltop Valley, four players, folded and
 * photographed sideways in a car. Seven reads returned one player, then two,
 * then three, and never the four that are on it; the per-hole numbers
 * disagreed between reads, and one read interpreted them as strokes where the
 * one before had read them as figures against par.
 *
 * <p>A scorecard has one right answer. Sampling is for prose, and the cost of
 * it here lands on a golfer's card.
 */
class ReadingACardIsNotCreativeTest {

    private ObjectNode requestFor(String path) throws Exception {
        var gateway = new LlmGateway(new ObjectMapper(), "key", "", "");
        Method request = LlmGateway.class.getDeclaredMethod(
                "request", String.class, String.class, String.class,
                String.class, String.class, int.class);
        request.setAccessible(true);
        return (ObjectNode) request.invoke(
                gateway, path, null, null, "read this", "max_tokens", 100);
    }

    @Test
    @DisplayName("a chat-completions request pins the temperature to zero")
    void chatCompletionsAsksForOneAnswer() throws Exception {
        var body = requestFor("/chat/completions");

        assertThat(body.has("temperature"))
                .as("with no temperature the provider picks one, and it samples")
                .isTrue();
        assertThat(body.get("temperature").asInt()).isZero();
    }

    @Test
    @DisplayName("and so does a messages request")
    void messagesAsksForOneAnswer() throws Exception {
        var body = requestFor("/v1/messages");

        assertThat(body.has("temperature")).isTrue();
        assertThat(body.get("temperature").asInt()).isZero();
    }

    @Test
    @DisplayName("the rest of the request is unchanged")
    void nothingElseMoved() throws Exception {
        var body = requestFor("/chat/completions");

        // The stream flag is load-bearing: this gateway once read an absent
        // `stream` as "stream it" and got server-sent events back.
        assertThat(body.get("stream").asBoolean()).isFalse();
        assertThat(body.get("max_tokens").asInt()).isEqualTo(100);
        assertThat(body.get("model").asText()).isNotBlank();
    }
}
