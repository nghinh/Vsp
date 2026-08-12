package vnpt.vsp.module.correction;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.models.messages.Base64ImageSource;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.ImageBlockParam;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.TextBlockParam;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.util.Base64;
import java.util.List;
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

            Return only a JSON object, with no prose around it and no markdown \
            fences:

            {"name": "A + B" or null,
             "parOut": 36, "parIn": 36, "parTotal": 72,
             "holes": [{"hole": 1, "par": 4, "strokeIndex": 7}, ...],
             "tees": [{"name": "GOLD", "courseRating": 75.5, "slopeRating": 138,
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

            Return only a JSON object, with no prose around it and no markdown \
            fences:

            {"players": [{"player": "A" or null,
                          "notation": "strokes" | "to_par" | null,
                          "holes": [{"hole": 1, "written": 4}, ...]}]}
            """;

    private final ObjectMapper objectMapper;
    private final String apiKey;
    private final String baseUrl;
    private final String model;
    private AnthropicClient client;

    public ScorecardOcrService(
            ObjectMapper objectMapper,
            @Value("${vsp.ocr.api-key:}") String apiKey,
            @Value("${vsp.ocr.base-url:}") String baseUrl,
            @Value("${vsp.ocr.model:}") String model) {
        this.objectMapper = objectMapper;
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.baseUrl = baseUrl == null ? "" : baseUrl.trim();
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

        // No `output_config` schema. The configured gateway accepts the
        // parameter and answers as if it had not been sent — asking for a
        // schema and trusting the answer would be worse than not asking, so
        // the shape is requested in the prompt and checked here instead.
        MessageCreateParams params = MessageCreateParams.builder()
                .model(model)
                // A five-tee card is ninety yardages plus par and index, and
                // at 4096 the answer was cut off mid-yardage on hole 13 of
                // the fourth tee — a truncation that reads as a short card
                // rather than an error.
                .maxTokens(12000L)
                // The SDK's non-streaming call omits `stream` entirely, and
                // the configured gateway reads a missing `stream` as "stream
                // it" — so the answer came back as server-sent events and the
                // parser rejected it on the word "event". Saying so
                // explicitly costs nothing against a server that already
                // defaults to false.
                .putAdditionalBodyProperty("stream", com.anthropic.core.JsonValue.from(false))
                .addUserMessageOfBlockParams(List.of(
                        ContentBlockParam.ofImage(ImageBlockParam.builder()
                                .source(Base64ImageSource.builder()
                                        .mediaType(Base64ImageSource.MediaType.of(mediaType))
                                        .data(base64)
                                        .build())
                                .build()),
                        ContentBlockParam.ofText(TextBlockParam.builder().text(prompt).build())))
                .build();

        Message response = client().messages().create(params);

        // A refusal is a successful HTTP response with no content to read, so
        // it has to be checked before the content blocks are touched.
        if ("refusal".equals(response.stopReason().map(Object::toString).orElse(""))) {
            log.warn("Scorecard reading was refused for a {} image of {} bytes", mediaType, image.length);
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "image",
                    Map.of("image", "this image could not be read"));
        }

        log.info("Read a scorecard from a {} image of {} bytes", mediaType, image.length);
        return response.content().stream()
                .flatMap(block -> block.text().stream())
                .map(text -> text.text())
                .findFirst()
                .orElseThrow(this::unreadable);
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
        int parCells = 0;
        int indexCells = 0;
        var indexes = new java.util.ArrayList<Integer>();
        for (var line : lines) {
            if (line.hasNonNull("par")) {
                parRead += line.get("par").asInt();
                parCells++;
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

        Integer printed = intInRange(node.get("parTotal"), 27, 80);
        checks.set("parTotalPrinted", nullable(printed));
        checks.put("parTotalAgrees", printed != null && printed == parRead);

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

        var seenNames = new java.util.HashSet<String>();
        for (var tee : tees) {
            String name = tee.hasNonNull("name") ? tee.get("name").asText().trim() : "";
            // A card names each tee once. A repeat is the same column read
            // twice, and keeping both would put two ratings on one tee.
            if (name.isEmpty() || name.length() > 60 || !seenNames.add(name.toUpperCase())) {
                continue;
            }

            var entry = objectMapper.createObjectNode();
            entry.put("name", name);
            entry.set("courseRating", decimalInRange(tee.get("courseRating"), 60.0, 80.0));
            entry.set("slopeRating", nullable(intInRange(tee.get("slopeRating"), 55, 155)));

            var yardages = objectMapper.createArrayNode();
            var seenHoles = new java.util.HashSet<Integer>();
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
                }
            }
            entry.set("yardages", yardages);
            result.add(entry);
        }
        return result;
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

    /// Built on first use rather than at startup: a deployment without a key
    /// must still boot, and every other endpoint must still work.
    private synchronized AnthropicClient client() {
        if (client == null) {
            var builder = AnthropicOkHttpClient.builder().apiKey(apiKey);
            if (!baseUrl.isEmpty()) {
                builder.baseUrl(baseUrl);
            }
            client = builder.build();
        }
        return client;
    }
}
