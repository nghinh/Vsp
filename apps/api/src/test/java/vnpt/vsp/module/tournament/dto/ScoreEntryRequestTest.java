package vnpt.vsp.module.tournament.dto;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Absent is not the same as null.
 *
 * Two screens post scores to one endpoint and each writes a different subset of
 * the card: the fast list sends a total with birdie and eagle counts, the
 * hole-by-hole grid sends eighteen holes with a total. While this was a record,
 * both arrived as null and the service applied them all — so saving in the grid
 * wiped birdies typed in the list. Nothing errored; the counts were simply gone
 * by the time the birdie prize was worked out.
 *
 * These tests pin the distinction the fix depends on.
 */
class ScoreEntryRequestTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private ScoreEntryRequest parse(String json) throws Exception {
        return MAPPER.readValue(json, ScoreEntryRequest.class);
    }

    @Test
    void aFieldTheClientOmittedIsNotMarkedAsSet() throws Exception {
        // What the hole-by-hole grid sends: no mention of birdies at all.
        ScoreEntryRequest r = parse("""
                {"tournamentPlayerId":"11111111-1111-4111-8111-111111111111",
                 "grossTotal":77,"holeScores":[4,4,3]}""");

        assertTrue(r.hasGrossTotal());
        assertTrue(r.hasHoleScores());
        assertFalse(r.hasBirdieCount(), "birdies were never mentioned; leave them alone");
        assertFalse(r.hasEagleCount());
    }

    @Test
    void anExplicitNullIsMarkedAsSet() throws Exception {
        // Clearing a value has to stay possible, and it is a different request
        // from not mentioning it.
        ScoreEntryRequest r = parse("""
                {"tournamentPlayerId":"11111111-1111-4111-8111-111111111111",
                 "grossTotal":null,"birdieCount":null}""");

        assertTrue(r.hasGrossTotal());
        assertNull(r.getGrossTotal());
        assertTrue(r.hasBirdieCount());
        assertNull(r.getBirdieCount());
    }

    @Test
    void whatTheFastListSendsCarriesTheCountsAndNotTheHoles() throws Exception {
        ScoreEntryRequest r = parse("""
                {"tournamentPlayerId":"11111111-1111-4111-8111-111111111111",
                 "grossTotal":77,"birdieCount":3,"eagleCount":1}""");

        assertTrue(r.hasBirdieCount());
        assertFalse(r.hasHoleScores(), "the fast list has no hole detail to send");
    }

    @Test
    void anEmptyBodyTouchesNothing() throws Exception {
        ScoreEntryRequest r = parse("{}");

        assertFalse(r.hasGrossTotal());
        assertFalse(r.hasHoleScores());
        assertFalse(r.hasBirdieCount());
        assertFalse(r.hasEagleCount());
    }
}
