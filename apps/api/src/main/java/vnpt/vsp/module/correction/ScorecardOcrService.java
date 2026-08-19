package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vnpt.vsp.module.ai.LlmGateway;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

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

            The photograph may be rotated, upside down, or taken at an \
            angle, and the card may be folded along its middle. Read it in \
            whatever orientation the printing runs.

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

            Return one row for EVERY row that has anything handwritten in \
            it, in the order the rows appear down the card, with a `player` \
            label taken from whatever is written at the left of the row (or \
            null if nothing is written there).

            Every row means every row. A row whose numbers you can barely make \
            out is still returned, with the cells you cannot read set to null; \
            a row you cannot read at all is still returned, with every cell \
            null. Dropping a row hides a player from the golfer checking this \
            card, and they cannot correct what they are not shown. Four names \
            down the left edge means four rows in the answer.

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

    /// A five-tee card is ninety yardages plus par and index, and at 4096 the
    /// answer was cut off mid-yardage on hole 13 of the fourth tee — a
    /// truncation that reads as a short card rather than an error.
    private static final int MAX_TOKENS = 12000;

    /// Below this many legible cells, the picture is worth turning.
    ///
    /// A four-player eighteen holds seventy-two cells. Ten is a card that was
    /// found but barely read, well below anything a golfer could use.
    ///
    /// Zero counts as thin and does buy the turns. A card nobody has written on
    /// yet reads the same as a card the model could not make out, and there is
    /// no way to tell them apart from the answer — the sideways card measured
    /// here returned two of its four rows completely empty. Charging the rare
    /// photograph of a blank card two extra calls is the cheaper mistake.
    private static final int THIN_READ = 10;

    /// A card whose longest side is under this is enlarged before it is read.
    ///
    /// Measured: 598 by 1280 is unreadable, 2560 works. The threshold sits
    /// well above the size that failed and below anything a phone camera
    /// produces, so a photograph taken in the app is never touched.
    private static final int ENOUGH_PIXELS = 1600;

    /// What a small card is enlarged to.
    private static final int ENLARGE_TO = 2560;

    private final ObjectMapper objectMapper;
    private final LlmGateway gateway;

    public ScorecardOcrService(ObjectMapper objectMapper, LlmGateway gateway) {
        this.objectMapper = objectMapper;
        this.gateway = gateway;
    }

    /** True when the deployment has a key and the endpoint can answer. */
    public boolean isEnabled() {
        return gateway.isEnabled();
    }

    /**
     * The card as read from the photograph, as JSON in the shape the phone's
     * form fills itself from.
     */
    public String extractCourse(byte[] image, String mediaType) {
        return readCard(gateway.ask(image, mediaType, COURSE_PROMPT, MAX_TOKENS));
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
        // A card shared through a chat app arrives shrunk, and the same
        // photograph reads completely differently depending on how big it is.
        //
        // Measured on one: a Korean card, four players, 598 by 1280. Read at
        // that size the model returned three players and numbers that matched
        // no row on the card. The identical pixels enlarged to 2560 returned
        // four players, all four names, and a front nine that agrees with the
        // card hole for hole on one row and misses one cell on two others.
        //
        // Enlarging adds no information. It buys the picture more of the
        // model's attention, and that turns out to be what was missing.
        byte[] photograph = enlargeIfSmall(image);
        String type = photograph == image ? mediaType : "image/jpeg";

        String best = null;
        int rank = -1;
        RuntimeException refusal = null;
        try {
            best = readScores(gateway.ask(photograph, type, SCORES_PROMPT, MAX_TOKENS));
            rank = rank(best);
            if (cellsRead(best) >= THIN_READ) {
                return best;
            }
        } catch (RuntimeException e) {
            // Not the end of it. Measured on the same card: upright the model
            // answered with nothing this could parse, while a quarter turn of
            // it answered fine. A photograph the model refuses at one angle is
            // still worth showing it at another.
            log.info("The first read failed, turning the picture: {}", e.toString());
            refusal = e;
        }

        // A thin read is usually a sideways card, not an unreadable one.
        //
        // Measured on a real card — Hilltop Valley, four players, folded and
        // photographed in a car with the card lying across the frame. Read as
        // photographed: four rows found and two legible cells out of eighteen
        // on the best of them. The same photograph turned a quarter turn:
        // four rows, sixteen and seventeen cells each, and identical between
        // runs.
        //
        // EXIF does not help here. The phone was held the right way up; it is
        // the card on the seat that is sideways, and no orientation tag records
        // that. Nor does the card lie one way: a card across the frame can have
        // its first hole at either end, so both quarter turns are tried.
        for (int quarters : new int[] {1, 3}) {
            byte[] turned = turn(photograph, quarters);
            if (turned == null) {
                break;
            }
            String sideways;
            try {
                // JPEG, whatever arrived: the turned copy is what ImageIO
                // wrote, and a PNG announced as a JPEG is refused by the model.
                sideways = readScores(gateway.ask(turned, "image/jpeg", SCORES_PROMPT, MAX_TOKENS));
            } catch (RuntimeException e) {
                // A turned read that fails where the first one did not is not
                // worth losing the answer we already have over.
                log.info("A turned read failed, keeping the best so far: {}", e.toString());
                continue;
            }
            int turnedRank = rank(sideways);
            if (turnedRank > rank) {
                best = sideways;
                rank = turnedRank;
            }
            if (cellsRead(best) >= THIN_READ) {
                break;
            }
        }

        if (best == null) {
            // Every angle refused. The golfer is owed the original complaint
            // rather than a new one invented here.
            throw refusal;
        }
        return best;
    }

    /**
     * How much to believe a read, for choosing between two of them.
     *
     * <p>Cells alone rank a fabrication above the truth: the sideways read of
     * the Korean card filled all fifty-four of its cells with numbers that are
     * on no row of the card, while an honest read of a smudged card leaves
     * cells null. So a row that adds up to the total the golfer wrote at the
     * end of it counts for more than any number of cells — it is the one piece
     * of arithmetic the card checks itself with.
     */
    private int rank(String json) {
        return agreeingRows(json) * 100 + cellsRead(json);
    }

    /// Rows whose holes add up to the total written at the end of them.
    private int agreeingRows(String json) {
        try {
            var players = objectMapper.readTree(json).get("players");
            if (players == null || !players.isArray()) {
                return 0;
            }
            int agreeing = 0;
            for (var player : players) {
                var checks = player.get("checks");
                if (checks == null) {
                    continue;
                }
                if (isTrue(checks.get("outAgrees")) || isTrue(checks.get("inAgrees"))) {
                    agreeing++;
                }
            }
            return agreeing;
        } catch (Exception e) {
            return 0;
        }
    }

    private boolean isTrue(com.fasterxml.jackson.databind.JsonNode node) {
        return node != null && node.asBoolean(false);
    }

    /// The picture enlarged to something the model can work with, or the
    /// original when it is already big enough or cannot be decoded.
    private byte[] enlargeIfSmall(byte[] image) {
        try {
            var source = javax.imageio.ImageIO.read(new java.io.ByteArrayInputStream(image));
            if (source == null) {
                return image;
            }
            int longest = Math.max(source.getWidth(), source.getHeight());
            if (longest >= ENOUGH_PIXELS) {
                return image;
            }

            double scale = (double) ENLARGE_TO / longest;
            int width = (int) Math.round(source.getWidth() * scale);
            int height = (int) Math.round(source.getHeight() * scale);
            var bigger = new java.awt.image.BufferedImage(
                    width, height, java.awt.image.BufferedImage.TYPE_INT_RGB);
            var g = bigger.createGraphics();
            g.setRenderingHint(java.awt.RenderingHints.KEY_INTERPOLATION,
                    java.awt.RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            g.drawImage(source, 0, 0, width, height, null);
            g.dispose();

            var out = new java.io.ByteArrayOutputStream();
            javax.imageio.ImageIO.write(bigger, "jpg", out);
            log.info("Enlarged a {}x{} card to {}x{} before reading it",
                    source.getWidth(), source.getHeight(), width, height);
            return out.toByteArray();
        } catch (Exception e) {
            log.info("Could not enlarge the picture: {}", e.toString());
            return image;
        }
    }

    /// How much of the card an answer actually contains.
    ///
    /// Counting cells rather than rows, because the failure this guards
    /// against returns every row with nothing in it.
    private int cellsRead(String json) {
        try {
            var players = objectMapper.readTree(json).get("players");
            if (players == null || !players.isArray()) {
                return 0;
            }
            int cells = 0;
            for (var player : players) {
                var holes = player.get("holes");
                if (holes == null || !holes.isArray()) {
                    continue;
                }
                for (var hole : holes) {
                    var written = hole.get("written");
                    if (written != null && !written.isNull()) {
                        cells++;
                    }
                }
            }
            return cells;
        } catch (Exception e) {
            return 0;
        }
    }

    /// Turns the picture [quarters] quarter-turns clockwise, or null if it
    /// cannot be decoded.
    private byte[] turn(byte[] image, int quarters) {
        try {
            var source = javax.imageio.ImageIO.read(new java.io.ByteArrayInputStream(image));
            if (source == null) {
                return null;
            }
            int w = source.getWidth();
            int h = source.getHeight();
            boolean sideways = quarters % 2 != 0;
            var turned = new java.awt.image.BufferedImage(
                    sideways ? h : w, sideways ? w : h,
                    java.awt.image.BufferedImage.TYPE_INT_RGB);
            var g = turned.createGraphics();
            g.translate(turned.getWidth() / 2.0, turned.getHeight() / 2.0);
            g.rotate(Math.PI / 2 * quarters);
            g.drawImage(source, -w / 2, -h / 2, null);
            g.dispose();

            var out = new java.io.ByteArrayOutputStream();
            javax.imageio.ImageIO.write(turned, "jpg", out);
            return out.toByteArray();
        } catch (Exception e) {
            log.info("Could not turn the picture: {}", e.toString());
            return null;
        }
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
