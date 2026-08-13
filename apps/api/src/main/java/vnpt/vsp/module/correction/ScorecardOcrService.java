package vnpt.vsp.module.correction;

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
 * Reads a club's printed scorecard out of a photograph.
 *
 * <p>The alternative is what the form does today: a golfer types eighteen pars
 * and eighteen stroke indexes by hand off a photo on their phone, at the first
 * tee. That is the step where the numbers go wrong, and a wrong stroke index
 * misallocates strokes for everyone who plays that card afterwards.
 *
 * <p>What comes back here is a <em>draft</em>, never a submission. The golfer
 * confirms it against the card in their hand and an admin reviews it after
 * that — the same two human checks as a hand-typed card. A model that misreads
 * a 4 as a 1 is not different in kind from a thumb that does.
 */
@Service
public class ScorecardOcrService {

    private static final Logger log = LoggerFactory.getLogger(ScorecardOcrService.class);


    private static final String COURSE_PROMPT = """
            This is a photograph of a golf club's printed scorecard, from Vietnam.

            Read the table and return one line per hole, in hole order, for \
            every hole visible in the photograph.

            HOW THESE CARDS ARE LAID OUT

            - The card is usually two tables side by side: holes 1-9 on the \
            left, holes 10-18 on the right. Read both. Hole numbers run 1 to \
            18 across the whole photograph, so a hole in the right-hand table \
            keeps the number printed above it — do not renumber it from 1.
            - Columns headed OUT, IN or TOTAL are sums of the row, not holes. \
            Skip them.
            - The rows named after tee colours — GOLD, BLACK, BLUE, WHITE, \
            RED — are yardages, three digits each. They are not par. Par is \
            its own row, labelled PAR, and its values are single digits: 3, 4 \
            or 5, occasionally 6.
            - The stroke index is the handicap ranking row, often printed at \
            the very bottom of the card, well below par and separated from it \
            by the empty rows golfers write their scores into. It is labelled \
            Index, HDC, HCP, S.I. or "Chỉ số". Across eighteen holes it uses \
            each number 1 to 18 exactly once — commonly all the even numbers \
            on one nine and all the odd numbers on the other.
            - Many cards print a SECOND index row for the ladies' tees, \
            because a hole's difficulty ranking changes with the distance \
            played. It is labelled "Ladies", "LDS", "Nữ" or sits under the red \
            tee's block, and it is also a complete 1 to 18. When the card has \
            two index rows, give the general or men's row as `strokeIndex` and \
            the ladies' row as `strokeIndexLadies`. When it prints only one \
            row, give it as `strokeIndex` and leave `strokeIndexLadies` null — \
            do not copy one into the other.

            WHAT TO IGNORE

            - Handwriting. A card that has been played on carries a golfer's \
            own strokes in the score rows, and often a player's name and \
            totals as well. None of that is the card's par or index.
            - Course rating and slope rating rows. Those are per tee, not per \
            hole.

            WHEN A CELL IS NOT LEGIBLE

            Set that field to null rather than guessing. A wrong stroke index \
            misallocates strokes for every golfer who plays this card; a null \
            is corrected in one tap.

            If the photograph is not a scorecard at all, return an empty holes \
            list.

            ALSO READ WHAT THE CARD ADDS UP TO

            The card prints its own sums: the PAR row's OUT, IN and TOTAL. \
            Give them as printed, so the numbers can be checked against the \
            holes you read.

            ALSO READ THE TEES

            The tee rows are the course's own measurements and belong with the \
            card. For each tee, give the name exactly as printed (GOLD, BLACK, \
            BLUE, WHITE, RED, or a Vietnamese name), the yardage printed for \
            each hole, and the Course Rating and Slope Rating for that tee if \
            the card prints them — they usually sit in a small table of their \
            own, one column per tee. Course rating is a decimal near par \
            (68.0-77.0); slope rating is a whole number between 55 and 155.

            Give each tee row's own OUT, IN and TOTAL as printed, the same way \
            you gave them for par. These are the numbers in the OUT, IN and \
            TOTAL columns of that tee's row — four digits for the total, \
            usually — and they are what makes a misread yardage findable: a \
            row of nine yardages that does not add up to the OUT beside it has \
            a digit wrong somewhere.

            A course is rated separately for men and for women, so a rating \
            table often has two entries for the same tee colour — the men's \
            and the ladies' course rating and slope for one set of yardages. \
            When the card says which is which, give each as its own entry with \
            the same `name` and a `gender` of "MEN" or "LADIES". When the card \
            does not say, use "UNSPECIFIED" — do not guess that an unlabelled \
            rating is the men's one.

            Return only a JSON object, with no prose around it and no markdown \
            fences:

            {"name": "A + B" or null,
             "parOut": 36, "parIn": 36, "parTotal": 72,
             "holes": [{"hole": 1, "par": 4, "strokeIndex": 7,
                        "strokeIndexLadies": 9}, ...],
             "tees": [{"name": "GOLD", "gender": "MEN",
                       "courseRating": 75.5, "slopeRating": 138,
                       "yardsOut": 3520, "yardsIn": 3480, "yardsTotal": 7000,
                       "yardages": [{"hole": 1, "yards": 416}, ...]}, ...]}
            """;

    private static final String SCORES_PROMPT = """
            This is a photograph of a golf scorecard that has been played on. \
            Read the strokes a golfer wrote on it by hand.

            HOW THESE CARDS ARE LAID OUT

            - Two tables side by side: holes 1-9 on the left, holes 10-18 on \
            the right. Hole numbers run 1 to 18 across the whole photograph — \
            a hole in the right-hand table keeps the number printed above it.
            - Columns headed OUT, IN or TOTAL hold sums, not a hole's score. \
            Skip them.
            - The printed rows — the tee colours GOLD, BLACK, BLUE, WHITE, \
            RED, and the rows labelled PAR, Index, HDC, HCP or "Chỉ số" — are \
            the course's own numbers, printed on every copy of this card. They \
            are never a golfer's score.
            - The handwritten numbers sit in the blank rows between them, one \
            row per player. Each row usually has a name or initial written at \
            its left edge.

            WHAT TO RETURN

            Return one row per player whose handwriting you can read, in the \
            order the rows appear down the card, with a `player` label taken \
            from whatever is written at the left of the row (or null if \
            nothing is written there).

            A handwritten number may be the strokes taken (4, 5, 6) or the \
            score relative to par (0, +1, -1, sometimes written as a bare 1 or \
            a circled figure). Report the number as written in `written`, and \
            say which convention the row uses in `notation`: "strokes" when \
            the numbers look like stroke counts for the hole, "to_par" when \
            they are small numbers around zero, including negatives. If you \
            cannot tell, use null.

            WHEN A CELL IS NOT LEGIBLE

            Set that hole's `written` to null rather than guessing. \
            Handwriting on a card carried round eighteen holes is often \
            smudged, and a wrong stroke silently changes the golfer's round.

            If nothing has been written on this card by hand, return an empty \
            players list.

            ALSO READ WHAT THE ROW ADDS UP TO

            A golfer almost always writes their own totals at the end of each \
            nine, in the OUT, IN and TOTAL columns of their own row. Give them \
            as written, in the same convention as the rest of the row, so the \
            holes you read can be checked against the golfer's own arithmetic. \
            Use null for any of them that is not written.

            Return only a JSON object, with no prose around it and no markdown \
            fences:

            {"players": [{"player": "A" or null,
                          "notation": "strokes" | "to_par" | null,
                          "writtenOut": 2, "writtenIn": 1, "writtenTotal": 3,
                          "holes": [{"hole": 1, "written": 4}, ...]}]}
            """;

    private static final String CHAT_COMPLETIONS = "/chat/completions";
    private static final String MESSAGES = "/messages";
    private static final int MAX_TOKENS = 12000;

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

    public ScorecardOcrService(
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

    /**
     * The card as read from the photograph, as JSON in the shape the phone's
     * form fills itself from.
     */
    public String extractCourse(byte[] image, String mediaType) {
        return readCard(ask(image, mediaType, COURSE_PROMPT));
    }

    /**
     * The strokes a golfer wrote on the card, as JSON, for the app to show
     * them before anything is saved.
     *
     * <p>The scoring flow reads the same photograph as the course flow and
     * wants the opposite half of it: here the printed rows are the noise and
     * the handwriting is the signal.
     */
    public String extractScores(byte[] image, String mediaType) {
        return readScores(ask(image, mediaType, SCORES_PROMPT));
    }

    private String ask(byte[] image, String mediaType, String prompt) {
        if (!isEnabled()) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                    Map.of("image", "scorecard reading is not configured on this server"));
        }

        String base64 = Base64.getEncoder().encodeToString(image);

        // The chat-completions surface first, because that is the one an
        // OpenAI-compatible router is defined by, and this deployment points
        // at a router whose `image` alias is repointed at a different model
        // whenever a better one turns up. The Anthropic surface is tried only
        // if the router does not serve that path at all.
        String body = post(CHAT_COMPLETIONS, base64, mediaType, prompt);
        if (body == null) {
            body = post(MESSAGES, base64, mediaType, prompt);
        }
        if (body == null) {
            log.error("The OCR gateway serves neither {} nor {}", CHAT_COMPLETIONS, MESSAGES);
            throw unreadable();
        }

        return answerOf(body, mediaType, image.length);
    }

    /**
     * The request, in the dialect the path expects.
     *
     * <p>The image goes inline either way: a data URI on the chat-completions
     * surface, a base64 source block on the Anthropic one.
     */
    private ObjectNode request(String path, String base64, String mediaType, String prompt, String tokenKey) {
        var body = objectMapper.createObjectNode();
        body.put("model", model);
        // A five-tee card is ninety yardages plus par and index, and at 4096
        // the answer was cut off mid-yardage on hole 13 of the fourth tee — a
        // truncation that reads as a short card rather than an error.
        body.put(tokenKey, MAX_TOKENS);
        // Left in deliberately: this gateway reads an absent `stream` as
        // "stream it", and the answer came back as server-sent events. Those
        // are read now too, but asking for one document is still cheaper than
        // reassembling a hundred frames.
        body.put("stream", false);

        var text = objectMapper.createObjectNode();
        text.put("type", "text");
        text.put("text", prompt);

        var image = objectMapper.createObjectNode();
        if (MESSAGES.equals(path)) {
            image.put("type", "image");
            var source = image.putObject("source");
            source.put("type", "base64");
            source.put("media_type", mediaType);
            source.put("data", base64);
        } else {
            image.put("type", "image_url");
            image.putObject("image_url").put("url", "data:" + mediaType + ";base64," + base64);
        }

        var message = objectMapper.createObjectNode();
        message.put("role", "user");
        message.set("content", objectMapper.createArrayNode().add(image).add(text));
        body.putArray("messages").add(message);
        return body;
    }

    /**
     * The gateway's answer as it came off the wire, or null when it does not
     * serve this path at all.
     *
     * <p>Everything else — a refused key, a model that is not routed — is this
     * server's problem to report, not a reason to go asking somewhere else.
     * The one exception is the token-budget parameter: the OpenAI-shaped world
     * spells it two ways and a server that wants the other one says so in a
     * 400, which is worth one retry rather than an operator's afternoon.
     */
    private String post(String path, String base64, String mediaType, String prompt) {
        for (String tokenKey : TOKEN_KEYS) {
            HttpResponse<String> response = send(path, request(path, base64, mediaType, prompt, tokenKey));

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
                log.info("The OCR gateway wants {} rather than {} — asking again",
                        TOKEN_KEYS[1], tokenKey);
                continue;
            }

            // The gateway's own words, trimmed: a 402 for exhausted credit and
            // a 401 for a rotated key are the two failures an operator can
            // actually act on, and neither is visible from a status code.
            log.error("The OCR gateway answered {} at {}: {}", response.statusCode(), path,
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
                    // deployment may be pointed at one that only reads one of
                    // them. Neither is meaningful to a server expecting the
                    // other.
                    .header("authorization", "Bearer " + apiKey)
                    .header("x-api-key", apiKey)
                    .header("anthropic-version", "2023-06-01")
                    // Reading a card takes this gateway around thirty seconds.
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
            log.error("The OCR gateway could not be reached at {}", path, e);
            throw unreadable();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw unreadable();
        }
    }

    /**
     * The model's text, out of whichever shape the answer arrived in.
     *
     * <p>The gateway routes one model alias at whatever model its operator has
     * pointed it at, and the answer's shape follows the model rather than the
     * path it was asked on: the same {@code /v1/messages} request that used to
     * come back with Anthropic {@code content} blocks now comes back as an
     * OpenAI {@code chat.completion}. Choosing the model is the operator's; a
     * deploy should not be the price of choosing.
     *
     * <p>So four dialects are read rather than one — OpenAI, Anthropic, Gemini,
     * and any of them delivered as server-sent events, which is what this
     * gateway does when it forgets it was asked not to.
     */
    private String answerOf(String body, String mediaType, int bytes) {
        String trimmed = body == null ? "" : body.trim();
        String text;

        if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
            JsonNode json;
            try {
                json = objectMapper.readTree(trimmed);
            } catch (Exception e) {
                log.error("The OCR gateway answered with a body that is not JSON: {}", abbreviate(body));
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
            log.error("The OCR gateway answered in a shape with no text in it: {}", abbreviate(body));
            throw unreadable();
        }

        log.info("Read a scorecard from a {} image of {} bytes", mediaType, bytes);
        return text;
    }

    /**
     * The text out of a stream of server-sent events.
     *
     * <p>Every dialect streams the same way — {@code data:} per line, one JSON
     * fragment each — so the fragments are read with the same reader as a whole
     * answer and joined. A stream that carries a refusal or stops at its token
     * limit says so in one of those fragments, and is treated exactly as it
     * would be in a single document.
     */
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
            log.warn("Scorecard reading was refused for a {} image of {} bytes", mediaType, bytes);
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                    Map.of("image", "this image could not be read"));
        }
    }

    private void warnIfTruncated(String finish) {
        // Worth saying out loud: a cut-off answer parses as a card with fewer
        // holes on it, which reads like a nine-hole course rather than a
        // failure.
        if ("length".equals(finish) || "max_tokens".equals(finish) || "MAX_TOKENS".equals(finish)) {
            log.warn("The OCR gateway stopped at its token limit — the card was read only as far as it got");
        }
    }

    /**
     * Text out of one answer or one stream fragment, in any of the dialects a
     * router in front of several vendors can hand back.
     */
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

    /// A content field, which is a bare string in some dialects and a list of
    /// typed parts in others. Anything without text in it reads as absent, so
    /// the caller can try the next dialect rather than stopping on an empty
    /// answer that was really a shape it did not recognise.
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

    /**
     * The card, as JSON, out of whatever the model actually said.
     *
     * <p>Without a schema to constrain it the answer arrives as prose around
     * an object, inside a markdown fence, or with the numbers as strings, so
     * the object is located and every value is checked here. Anything outside
     * the range a printed card can hold becomes null: the golfer fills one
     * blank in, where a wrong number would have to be spotted first.
     */
    private String readCard(String answer) {
        int open = answer.indexOf('{');
        int close = answer.lastIndexOf('}');
        if (open < 0 || close <= open) {
            throw unreadable();
        }

        try {
            var node = objectMapper.readTree(answer.substring(open, close + 1));
            var holes = node.get("holes");
            if (holes == null || !holes.isArray() || holes.isEmpty()) {
                throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                        Map.of("image", "no scorecard could be read in this photograph"));
            }

            var seenIndexes = new java.util.HashSet<Integer>();
            var seenLadiesIndexes = new java.util.HashSet<Integer>();
            var lines = objectMapper.createArrayNode();
            for (var hole : holes) {
                Integer number = intInRange(hole.get("hole"), 1, 18);
                if (number == null) {
                    continue;
                }
                var line = objectMapper.createObjectNode();
                line.put("hole", number);
                line.set("par", nullable(intInRange(hole.get("par"), 3, 6)));

                // An index the card already gave another hole is a misread,
                // not a second hole with the same ranking. Dropping the
                // repeat leaves one blank to fill rather than two holes whose
                // strokes are allocated wrongly and look right.
                Integer index = intInRange(hole.get("strokeIndex"), 1, 18);
                if (index != null && !seenIndexes.add(index)) {
                    index = null;
                }
                line.set("strokeIndex", nullable(index));

                // The ladies row is its own complete 1-18, so it gets its own
                // seen-set: hole 3 being index 7 on one row and index 7 on the
                // other is two rankings agreeing, not a misread.
                Integer ladies = intInRange(hole.get("strokeIndexLadies"), 1, 18);
                if (ladies != null && !seenLadiesIndexes.add(ladies)) {
                    ladies = null;
                }
                line.set("strokeIndexLadies", nullable(ladies));
                lines.add(line);
            }

            if (lines.isEmpty()) {
                throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                        Map.of("image", "no scorecard could be read in this photograph"));
            }

            var card = objectMapper.createObjectNode();
            card.set("checks", check(lines, node));
            card.set("tees", readTees(node.get("tees")));
            var name = node.get("name");
            card.set("name", name == null || name.isNull() ? objectMapper.nullNode()
                    : objectMapper.getNodeFactory().textNode(name.asText()));
            card.set("holes", lines);
            return objectMapper.writeValueAsString(card);
        } catch (VspApiException e) {
            throw e;
        } catch (Exception e) {
            throw unreadable();
        }
    }


    /**
     * The strokes out of whatever the model said, checked hole by hole.
     *
     * <p>A stroke count is bounded by what a golfer can physically write on a
     * card: nothing below 1, and a number above 15 on a par 5 is a misread of
     * two digits, not a round. Out-of-range cells become null and the golfer
     * fills them in — a wrong stroke changes their score and looks right.
     */
    private String readScores(String answer) {
        int open = answer.indexOf('{');
        int close = answer.lastIndexOf('}');
        if (open < 0 || close <= open) {
            throw unreadable();
        }

        try {
            var node = objectMapper.readTree(answer.substring(open, close + 1));
            var players = node.get("players");
            if (players == null || !players.isArray() || players.isEmpty()) {
                throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                        Map.of("image", "no handwritten scores could be read on this card"));
            }

            var rows = objectMapper.createArrayNode();
            for (var player : players) {
                var holes = player.get("holes");
                if (holes == null || !holes.isArray()) {
                    continue;
                }
                var seenHoles = new java.util.HashSet<Integer>();
                var lines = objectMapper.createArrayNode();
                for (var hole : holes) {
                    Integer number = intInRange(hole.get("hole"), 1, 18);
                    // One row, one number per hole. A repeat means a column
                    // was read twice — most often an OUT or IN total pulled
                    // in as if it were the next hole.
                    if (number == null || !seenHoles.add(number)) {
                        continue;
                    }
                    var line = objectMapper.createObjectNode();
                    line.put("hole", number);
                    line.set("written", nullable(intInRange(hole.get("written"), -9, 15)));
                    lines.add(line);
                }
                if (lines.isEmpty()) {
                    continue;
                }

                var row = objectMapper.createObjectNode();
                var label = player.get("player");
                row.set("player", label == null || label.isNull() ? objectMapper.nullNode()
                        : objectMapper.getNodeFactory().textNode(label.asText()));
                String notation = player.hasNonNull("notation") ? player.get("notation").asText() : "";
                row.set("notation", switch (notation) {
                    case "strokes", "to_par" -> objectMapper.getNodeFactory().textNode(notation);
                    default -> objectMapper.nullNode();
                });
                row.set("checks", checkRow(lines, player));
                row.set("holes", lines);
                rows.add(row);
            }

            if (rows.isEmpty()) {
                throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                        Map.of("image", "no handwritten scores could be read on this card"));
            }

            var result = objectMapper.createObjectNode();
            result.set("players", rows);
            return objectMapper.writeValueAsString(result);
        } catch (VspApiException e) {
            throw e;
        } catch (Exception e) {
            throw unreadable();
        }
    }



    /**
     * What the golfer's own arithmetic says about their row.
     *
     * <p>A player writes their OUT, IN and TOTAL at the end of each nine, and
     * those three numbers are the only independent check on a row of
     * handwriting there will ever be. On the card this was developed against
     * they earned their place immediately: the front nine was read correctly
     * and summed to the +2 the golfer had written, while the back nine summed
     * to 2 against a written 1 — one hole misread, invisible in the numbers
     * themselves.
     *
     * <p>They are not proof. Two holes misread in opposite directions leave
     * the total standing, and a golfer who added up wrong disagrees with a
     * perfect read. Both are reasons to look, which is all this claims.
     */
    private com.fasterxml.jackson.databind.JsonNode checkRow(
            com.fasterxml.jackson.databind.node.ArrayNode lines,
            com.fasterxml.jackson.databind.JsonNode player) {
        var checks = objectMapper.createObjectNode();

        int cellsRead = 0;
        int out = 0;
        int in = 0;
        boolean outComplete = true;
        boolean inComplete = true;
        for (var line : lines) {
            int hole = line.get("hole").asInt();
            boolean read = line.hasNonNull("written");
            if (read) {
                cellsRead++;
                if (hole <= 9) {
                    out += line.get("written").asInt();
                } else {
                    in += line.get("written").asInt();
                }
            } else if (hole <= 9) {
                outComplete = false;
            } else {
                inComplete = false;
            }
        }

        checks.put("holesRead", lines.size());
        checks.put("cellsRead", cellsRead);

        // A sum of a nine with a hole missing from it agrees with nothing, and
        // saying it disagrees would send the golfer looking for a misread that
        // is really a blank they can already see.
        Integer writtenOut = intInRange(player.get("writtenOut"), -30, 99);
        Integer writtenIn = intInRange(player.get("writtenIn"), -30, 99);
        Integer writtenTotal = intInRange(player.get("writtenTotal"), -60, 199);

        checks.set("writtenOut", nullable(writtenOut));
        checks.set("writtenIn", nullable(writtenIn));
        checks.set("writtenTotal", nullable(writtenTotal));
        checks.put("outAgrees", outComplete && writtenOut != null && writtenOut == out);
        checks.put("inAgrees", inComplete && writtenIn != null && writtenIn == in);
        checks.put("totalAgrees", outComplete && inComplete
                && writtenTotal != null && writtenTotal == out + in);
        return checks;
    }

    /**
     * What the card's own arithmetic says about the read.
     *
     * <p>A printed card carries two facts that a correct read must satisfy:
     * the par row adds up to the total printed beside it, and the stroke
     * indexes are the numbers 1..18 used once each. Both are cheap to check
     * and worth surfacing — but neither is proof, and the app must not treat
     * a clean check as a reason to skip the golfer's eyes:
     *
     * <ul>
     *   <li>a read that swaps two pars leaves the total unchanged;</li>
     *   <li>a read that drops one index column and shifts the rest along is
     *       still a permutation of 1..18.</li>
     * </ul>
     *
     * Both of those were observed on a real card during development. What
     * these checks do is name the rows worth looking at first.
     */
    private com.fasterxml.jackson.databind.JsonNode check(
            com.fasterxml.jackson.databind.node.ArrayNode lines,
            com.fasterxml.jackson.databind.JsonNode node) {
        var checks = objectMapper.createObjectNode();

        int parRead = 0;
        int parOutRead = 0;
        int parInRead = 0;
        int parCells = 0;
        int indexCells = 0;
        boolean outComplete = true;
        boolean inComplete = true;
        var indexes = new java.util.ArrayList<Integer>();
        for (var line : lines) {
            int hole = line.get("hole").asInt();
            if (line.hasNonNull("par")) {
                int par = line.get("par").asInt();
                parRead += par;
                parCells++;
                if (hole <= 9) {
                    parOutRead += par;
                } else {
                    parInRead += par;
                }
            } else if (hole <= 9) {
                outComplete = false;
            } else {
                inComplete = false;
            }
            if (line.hasNonNull("strokeIndex")) {
                indexes.add(line.get("strokeIndex").asInt());
                indexCells++;
            }
        }

        checks.put("holesRead", lines.size());
        checks.put("parCellsRead", parCells);
        checks.put("strokeIndexCellsRead", indexCells);
        checks.put("parTotalRead", parRead);
        checks.put("parOutRead", parOutRead);
        checks.put("parInRead", parInRead);

        Integer printed = intInRange(node.get("parTotal"), 27, 80);
        checks.set("parTotalPrinted", nullable(printed));
        checks.put("parTotalAgrees", printed != null && printed == parRead);

        // The nines separately, because the total alone cannot see a swap
        // between them: reading the front nine's par onto the back and the
        // back's onto the front leaves the total exactly where it was. The
        // model was already being asked for these two numbers and nothing
        // compared them to anything.
        Integer printedOut = intInRange(node.get("parOut"), 9, 45);
        Integer printedIn = intInRange(node.get("parIn"), 9, 45);
        checks.set("parOutPrinted", nullable(printedOut));
        checks.set("parInPrinted", nullable(printedIn));
        checks.put("parOutAgrees",
                outComplete && printedOut != null && printedOut == parOutRead);
        checks.put("parInAgrees",
                inComplete && printedIn != null && printedIn == parInRead);

        var sorted = new java.util.ArrayList<>(indexes);
        java.util.Collections.sort(sorted);
        var expected = new java.util.ArrayList<Integer>();
        for (int i = 1; i <= lines.size(); i++) {
            expected.add(i);
        }
        checks.put("strokeIndexComplete", sorted.equals(expected));

        return checks;
    }

    /**
     * The tee rows of the card: what each tee measures and how it is rated.
     *
     * <p>These are the numbers that make a score mean something — a round is
     * only comparable against the tee it was played from — and the card is
     * the only place they are written down. Each is range-checked against
     * what a card can print: a yardage under 60 or over 700 is a misread of
     * the wrong row, a course rating outside 60-80 is a slope in the wrong
     * column, and either becomes null rather than a plausible wrong number.
     */
    private com.fasterxml.jackson.databind.JsonNode readTees(
            com.fasterxml.jackson.databind.JsonNode tees) {
        var result = objectMapper.createArrayNode();
        if (tees == null || !tees.isArray()) {
            return result;
        }

        var seenRows = new java.util.HashSet<String>();
        for (var tee : tees) {
            String name = tee.hasNonNull("name") ? tee.get("name").asText().trim() : "";
            // Whose rating this row carries. A course is rated separately for
            // men and for women, so a card can print RED twice with different
            // ratings — the dedupe used to key on the name alone and threw the
            // second away, which is why one of the two was always missing.
            String gender = gender(tee.get("gender"));
            if (name.isEmpty() || name.length() > 60
                    || !seenRows.add(name.toUpperCase() + "/" + gender)) {
                continue;
            }

            var entry = objectMapper.createObjectNode();
            entry.put("name", name);
            entry.put("gender", gender);
            entry.set("courseRating", decimalInRange(tee.get("courseRating"), 60.0, 80.0));
            entry.set("slopeRating", nullable(intInRange(tee.get("slopeRating"), 55, 155)));

            var yardages = objectMapper.createArrayNode();
            var seenHoles = new java.util.HashSet<Integer>();
            int readOut = 0;
            int readIn = 0;
            boolean anyFront = false;
            boolean anyBack = false;
            var printed = tee.get("yardages");
            if (printed != null && printed.isArray()) {
                for (var yardage : printed) {
                    Integer hole = intInRange(yardage.get("hole"), 1, 18);
                    Integer yards = intInRange(yardage.get("yards"), 60, 700);
                    if (hole == null || yards == null || !seenHoles.add(hole)) {
                        continue;
                    }
                    var line = objectMapper.createObjectNode();
                    line.put("hole", hole);
                    line.put("yards", yards);
                    yardages.add(line);
                    if (hole <= 9) {
                        readOut += yards;
                        anyFront = true;
                    } else {
                        readIn += yards;
                        anyBack = true;
                    }
                }
            }
            entry.set("yardages", yardages);
            entry.set("checks", yardageChecks(tee, readOut, readIn, anyFront, anyBack));
            result.add(entry);
        }
        return result;
    }

    /**
     * A tee row against the sums the club printed beside it.
     *
     * <p>The par row has had this from the start — read the eighteen cells,
     * add them, compare with the printed total — and it is the check that
     * catches a misread, because a card contradicting itself is visible in a
     * way a plausible wrong number is not.
     *
     * <p>The yardage rows had nothing, while being ten times the cells: five
     * tees over eighteen holes is ninety numbers of three digits each, against
     * par's eighteen of one digit. The portal showed a total, but it summed
     * what the model had just read, so a 3 read as an 8 produced a total that
     * agreed with itself perfectly.
     *
     * <p>Reported per nine as well as per card. A card photographed in two
     * halves, or one whose back nine sits outside the frame, gives a front nine
     * that adds up and a back nine that is simply absent — worth telling apart
     * from a row with a digit wrong in it.
     */
    private com.fasterxml.jackson.databind.JsonNode yardageChecks(
            com.fasterxml.jackson.databind.JsonNode tee,
            int readOut, int readIn, boolean anyFront, boolean anyBack) {
        var checks = objectMapper.createObjectNode();

        // A nine is 60-700 a hole, so 540 to 6,300; a card's total is two of
        // those. Anything outside is a column read from the wrong row.
        Integer printedOut = intInRange(tee.get("yardsOut"), 540, 6300);
        Integer printedIn = intInRange(tee.get("yardsIn"), 540, 6300);
        Integer printedTotal = intInRange(tee.get("yardsTotal"), 1080, 12600);

        checks.put("yardsOutRead", readOut);
        checks.put("yardsInRead", readIn);
        checks.set("yardsOutPrinted", nullable(printedOut));
        checks.set("yardsInPrinted", nullable(printedIn));
        checks.set("yardsTotalPrinted", nullable(printedTotal));

        // Only the halves the photograph actually shows are judged. Absent is
        // not the same as wrong, and calling it wrong would put a warning on
        // every nine-hole card in the country.
        boolean outAgrees = !anyFront || printedOut == null || printedOut == readOut;
        boolean inAgrees = !anyBack || printedIn == null || printedIn == readIn;
        boolean totalAgrees = printedTotal == null
                || (!anyFront && !anyBack)
                || printedTotal == readOut + readIn;

        checks.put("yardsAgree", outAgrees && inAgrees && totalAgrees);
        // Null where the card printed no sums at all: nothing was checked, and
        // saying so beats a green tick nobody earned.
        checks.set("yardsChecked", printedOut == null && printedIn == null
                && printedTotal == null
                ? objectMapper.nullNode()
                : objectMapper.getNodeFactory().booleanNode(true));

        return checks;
    }

    /**
     * Whose rating a tee row carries, as the card labels it.
     *
     * <p>Anything the card does not say is UNSPECIFIED, which is most cards.
     * Reading an unlabelled rating as the men's would be a guess that looks
     * like data: a woman playing off it would get a handicap differential
     * computed against the wrong rating, and nothing on the card or the screen
     * would show where the number came from.
     */
    private String gender(com.fasterxml.jackson.databind.JsonNode node) {
        if (node == null || node.isNull()) {
            return "UNSPECIFIED";
        }
        return switch (node.asText("").trim().toUpperCase()) {
            case "MEN", "MAN", "MENS", "MEN'S", "NAM" -> "MEN";
            case "LADIES", "LADY", "LADIES'", "WOMEN", "WOMENS", "NỮ", "NU" -> "LADIES";
            default -> "UNSPECIFIED";
        };
    }

    private com.fasterxml.jackson.databind.JsonNode decimalInRange(
            com.fasterxml.jackson.databind.JsonNode node, double min, double max) {
        if (node == null || node.isNull()) {
            return objectMapper.nullNode();
        }
        double value;
        if (node.isNumber()) {
            value = node.asDouble();
        } else {
            try {
                value = Double.parseDouble(node.asText().trim());
            } catch (NumberFormatException e) {
                return objectMapper.nullNode();
            }
        }
        return value < min || value > max
                ? objectMapper.nullNode()
                : objectMapper.getNodeFactory().numberNode(value);
    }

    /// A number the model gave, when a printed card could actually hold it.
    /// Accepts a quoted number: without a schema the model writes both.
    private Integer intInRange(com.fasterxml.jackson.databind.JsonNode node, int min, int max) {
        if (node == null || node.isNull()) {
            return null;
        }
        int value;
        if (node.isNumber()) {
            value = node.asInt();
        } else {
            try {
                value = Integer.parseInt(node.asText().trim());
            } catch (NumberFormatException e) {
                return null;
            }
        }
        return value < min || value > max ? null : value;
    }

    private com.fasterxml.jackson.databind.JsonNode nullable(Integer value) {
        return value == null
                ? objectMapper.nullNode()
                : objectMapper.getNodeFactory().numberNode(value);
    }

    private VspApiException unreadable() {
        return VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                Map.of("image", "this image could not be read"));
    }
}
