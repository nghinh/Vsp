package vnpt.vsp.wear.domain.model

import org.junit.Assert.assertEquals
import org.junit.Test

class WearHoleScoreTest {

    @Test
    fun `scoreToPar returns correct value`() {
        val score = WearHoleScore(
            id = "test-1",
            roundId = "round-1",
            playerId = "player-1",
            holeNumber = 1,
            strokes = 5,
            putts = 2,
            penalties = 1
        )

        // Par 4, strokes 5 = +1 to par
        assertEquals(1, score.scoreToPar(par = 4))
    }

    @Test
    fun `scoreToPar returns null when strokes is null`() {
        val score = WearHoleScore(
            id = "test-2",
            roundId = "round-1",
            playerId = "player-1",
            holeNumber = 1,
            strokes = null
        )

        assertEquals(null, score.scoreToPar(par = 4))
    }

    @Test
    fun `scoreToPar returns negative for under par`() {
        val score = WearHoleScore(
            id = "test-3",
            roundId = "round-1",
            playerId = "player-1",
            holeNumber = 1,
            strokes = 3
        )

        // Par 4, strokes 3 = -1 (under par / birdie)
        assertEquals(-1, score.scoreToPar(par = 4))
    }
}
