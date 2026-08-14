package vnpt.vsp.module.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.Map;

/**
 * The one way this service talks to a language model.
 *
 * <p>Extracted from the scorecard reader, which had all of it inline and was
 * for a long time the only caller. It is here because the transport is the part
 * that had to learn the awkward truths — and none of them are about scorecards:
 *
 * <ul>
 *   <li>the deployment points at a router whose model alias is repointed
 *       whenever a better model appears, so the <em>shape</em> of the answer
 *       follows the model rather than the path it was asked on;</li>
 *   <li>that router reads an absent {@code stream} as "stream it", and answers
 *       in server-sent events;</li>
 *   <li>the OpenAI-shaped world spells the token budget two ways, and a server
 *       wanting the other one says so only in a 400.</li>
 * </ul>
 *
 * <p>A second caller written from scratch would have rediscovered every one of
 * those, and probably not all of them.
 */
@Service
public class LlmGateway {

    private static final Logger log = LoggerFactory.getLogger(LlmGateway.class);

    private static final String CHAT_COMPLETIONS = "/chat/completions";
    private static final String MESSAGES = "/messages";

    /// The two spellings of a token budget, in the order they are tried. Newer
    /// OpenAI-shaped models reject the first and name the second in the 400.
    private static final String[] TOKEN_KEYS = {"max_tokens", "max_completion_tokens"};

    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String baseUrl;
    private final String model;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15))
            .build();

    public LlmGateway(
            ObjectMapper objectMapper,
            @Value("${vsp.ocr.api-key:}") String apiKey,
            @Value("${vsp.ocr.base-url:}") String baseUrl,
            @Value("${vsp.ocr.model:}") String model) {
        this.objectMapper = objectMapper;
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.baseUrl = baseUrl == null || baseUrl.isBlank()
                ? "https://api.anthropic.com" : baseUrl.trim();
        this.model = model == null || model.isBlank() ? "claude-opus-5" : model.trim();
    }

    /** True when the deployment has a key and the endpoint can answer. */
    public boolean isEnabled() {
        return !apiKey.isEmpty();
    }

    /** An answer to a prompt with no image attached. */
    public String ask(String prompt, int maxTokens) {
        return ask(null, null, prompt, maxTokens);
    }

    /** An answer to a prompt about an image. */
    public String ask(byte[] image, String mediaType, String prompt, int maxTokens) {
        if (!isEnabled()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                    Map.of("image", "scorecard reading is not configured on this server"));
        }

        String base64 = image == null ? null : Base64.getEncoder().encodeToString(image);

        // The chat-completions surface first, because that is the one an
        // OpenAI-compatible router is defined by. The Anthropic surface is
        // tried only if the router does not serve that path at all.
        String body = post(CHAT_COMPLETIONS, base64, mediaType, prompt, maxTokens);
        if (body == null) {
            body = post(MESSAGES, base64, mediaType, prompt, maxTokens);
        }
        if (body == null) {
            log.error("The model gateway serves neither {} nor {}", CHAT_COMPLETIONS, MESSAGES);
            throw unreadable();
        }

        return answerOf(body, mediaType, base64 == null ? 0 : image.length);
    }

    private ObjectNode request(String path, String base64, String mediaType,
                               String prompt, String tokenKey, int maxTokens) {
        var body = objectMapper.createObjectNode();
        body.put("model", model);
        body.put(tokenKey, maxTokens);
        // Left in deliberately: this gateway reads an absent `stream` as
        // "stream it", and the answer came back as server-sent events.
        body.put("stream", false);

        var text = objectMapper.createObjectNode();
        text.put("type", "text");
        text.put("text", prompt);

        var content = objectMapper.createArrayNode();
        if (base64 != null) {
            var image = objectMapper.createObjectNode();
            if (MESSAGES.equals(path)) {
                image.put("type", "image");
                var source = image.putObject("source");
                source.put("type", "base64");
                source.put("media_type", mediaType);
                source.put("data", base64);
            } else {
                image.put("type", "image_url");
                image.putObject("image_url")
                        .put("url", "data:" + mediaType + ";base64," + base64);
            }
            content.add(image);
        }
        content.add(text);

        var message = objectMapper.createObjectNode();
        message.put("role", "user");
        message.set("content", content);
        body.putArray("messages").add(message);
        return body;
    }

    /**
     * The gateway's answer as it came off the wire, or null when it does not
     * serve this path at all.
     */
    private String post(String path, String base64, String mediaType,
                        String prompt, int maxTokens) {
        for (String tokenKey : TOKEN_KEYS) {
            HttpResponse<String> response =
                    send(path, request(path, base64, mediaType, prompt, tokenKey, maxTokens));

            if (response.statusCode() == 404 || response.statusCode() == 405) {
                return null;
            }
            if (response.statusCode() / 100 == 2) {
                return response.body();
            }

            String complaint = response.body() == null ? "" : response.body();
            boolean wrongSpelling = response.statusCode() == 400
                    && !tokenKey.equals(TOKEN_KEYS[TOKEN_KEYS.length - 1])
                    && complaint.contains(TOKEN_KEYS[1]);
            if (wrongSpelling) {
                log.info("The model gateway wants {} rather than {} — asking again",
                        TOKEN_KEYS[1], tokenKey);
                continue;
            }

            // The gateway's own words, trimmed: a 402 for exhausted credit and
            // a 401 for a rotated key are the two failures an operator can
            // actually act on, and neither is visible from a status code.
            log.error("The model gateway answered {} at {}: {}", response.statusCode(), path,
                    abbreviate(complaint));
            throw unreadable();
        }
        throw unreadable();
    }

    private HttpResponse<String> send(String path, ObjectNode body) {
        HttpRequest request;
        try {
            request = HttpRequest.newBuilder(URI.create(endpoint(path)))
                    .header("content-type", "application/json")
                    // Both schemes, because the router accepts either and a
                    // deployment may be pointed at one that only reads one.
                    .header("authorization", "Bearer " + apiKey)
                    .header("x-api-key", apiKey)
                    .header("anthropic-version", "2023-06-01")
                    .timeout(Duration.ofSeconds(150))
                    .POST(HttpRequest.BodyPublishers.ofString(
                            objectMapper.writeValueAsString(body), StandardCharsets.UTF_8))
                    .build();
        } catch (Exception e) {
            throw unreadable();
        }

        try {
            return http.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        } catch (IOException e) {
            log.error("The model gateway could not be reached at {}", path, e);
            throw unreadable();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw unreadable();
        }
    }

    /**
     * The model's text, out of whichever shape the answer arrived in — OpenAI,
     * Anthropic, Gemini, or any of them delivered as server-sent events, which
     * is what this gateway does when it forgets it was asked not to.
     */
    private String answerOf(String body, String mediaType, int bytes) {
        String trimmed = body == null ? "" : body.trim();
        String text;

        if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
            JsonNode json;
            try {
                json = objectMapper.readTree(trimmed);
            } catch (Exception e) {
                log.error("The model gateway answered with a body that is not JSON: {}",
                        abbreviate(body));
                throw unreadable();
            }
            refuseIfRefused(json, mediaType, bytes);
            warnIfTruncated(json.path("choices").path(0).path("finish_reason")
                    .asText(json.path("stop_reason").asText("")));
            text = textIn(json);
        } else {
            text = textInEvents(trimmed, mediaType, bytes);
        }

        if (text == null || text.isBlank()) {
            log.error("The model gateway answered in a shape with no text in it: {}",
                    abbreviate(body));
            throw unreadable();
        }
        return text;
    }

    private String textInEvents(String body, String mediaType, int bytes) {
        var joined = new StringBuilder();
        for (String line : body.split("\\R")) {
            if (!line.startsWith("data:")) {
                continue;
            }
            String payload = line.substring("data:".length()).trim();
            if (payload.isEmpty() || "[DONE]".equals(payload)) {
                continue;
            }
            JsonNode frame;
            try {
                frame = objectMapper.readTree(payload);
            } catch (Exception e) {
                continue;
            }
            refuseIfRefused(frame, mediaType, bytes);
            warnIfTruncated(frame.path("choices").path(0).path("finish_reason").asText(""));
            String piece = textIn(frame);
            if (piece != null) {
                joined.append(piece);
            }
        }
        return joined.isEmpty() ? null : joined.toString();
    }

    private void refuseIfRefused(JsonNode node, String mediaType, int bytes) {
        boolean refused = "refusal".equals(node.path("stop_reason").asText())
                || "refusal".equals(node.path("choices").path(0).path("finish_reason").asText())
                || node.path("choices").path(0).path("message").hasNonNull("refusal")
                || node.path("choices").path(0).path("delta").hasNonNull("refusal");
        if (refused) {
            log.warn("The model refused a {} request of {} bytes", mediaType, bytes);
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                    Map.of("image", "this image could not be read"));
        }
    }

    private void warnIfTruncated(String finish) {
        if ("length".equals(finish) || "max_tokens".equals(finish) || "MAX_TOKENS".equals(finish)) {
            log.warn("The model gateway stopped at its token limit — the answer is only as far as it got");
        }
    }

    private String textIn(JsonNode node) {
        JsonNode choice = node.path("choices").path(0);
        String text = contentText(choice.path("message").path("content"));   // OpenAI, whole
        if (text == null) {
            text = contentText(choice.path("delta").path("content"));        // OpenAI, streamed
        }
        if (text == null) {
            text = contentText(choice.path("text"));                         // legacy completions
        }
        if (text == null) {
            text = contentText(node.path("content"));                        // Anthropic, whole
        }
        if (text == null) {
            text = contentText(node.path("delta").path("text"));             // Anthropic, streamed
        }
        if (text == null) {
            text = contentText(node.path("candidates").path(0)
                    .path("content").path("parts"));                         // Gemini
        }
        return text;
    }

    /// A content field, a bare string in some dialects and a list of typed
    /// parts in others. Anything without text reads as absent, so the caller
    /// can try the next dialect rather than stopping on an empty answer that
    /// was really a shape it did not recognise.
    private String contentText(JsonNode content) {
        if (content.isTextual()) {
            return content.asText();
        }
        if (content.isArray()) {
            var joined = new StringBuilder();
            for (var part : content) {
                if (part.hasNonNull("text")) {
                    joined.append(part.get("text").asText());
                } else if (part.isTextual()) {
                    joined.append(part.asText());
                }
            }
            return joined.isEmpty() ? null : joined.toString();
        }
        return null;
    }

    /// The configured base URL may or may not already carry the version
    /// segment: the gateway is documented as `.../v1` and Spring config has
    /// been written both ways.
    private String endpoint(String path) {
        String base = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return base.endsWith("/v1") ? base + path : base + "/v1" + path;
    }

    /// Enough of a gateway error to act on, without putting a base64 echo of
    /// the photograph into the log.
    private String abbreviate(String body) {
        if (body == null) {
            return "";
        }
        String flat = body.replaceAll("\\s+", " ").trim();
        return flat.length() <= 400 ? flat : flat.substring(0, 400) + "…";
    }

    private VspApiException unreadable() {
        return VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                Map.of("image", "this image could not be read"));
    }
}
