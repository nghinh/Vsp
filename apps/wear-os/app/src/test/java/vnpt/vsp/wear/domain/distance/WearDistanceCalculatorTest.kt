package vnpt.vsp.wear.domain.distance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import vnpt.vsp.wear.domain.model.HazardType
import vnpt.vsp.wear.domain.model.WearHoleSubset

class WearDistanceCalculatorTest {

    // A tee roughly due south of a green in Hanoi; ~150 m front / ~165 m back.
    private val playerLat = 21.02000
    private val playerLon = 105.83000

    private fun holeWithGreen() = WearHoleSubset(
        holeNumber = 1,
        par = 4,
        holeLengthMeters = 380,
        centerLat = 21.02140,
        centerLon = 105.83000,
        frontLat = 21.02130,
        frontLon = 105.83000,
        backLat = 21.02155,
        backLon = 105.83000,
        pinLat = 21.02142,
        pinLon = 105.83000,
    )

    @Test
    fun `haversine matches known short distance`() {
        // ~155 m north along a meridian (0.00140 deg latitude).
        val d = WearDistanceCalculator.haversineMeters(
            playerLat, playerLon, 21.02140, playerLon,
        )
        assertEquals(155.6, d, 1.0)
    }

    @Test
    fun `compute returns front center back in ascending order`() {
        val distance = WearDistanceCalculator.compute(
            playerLat, playerLon, accuracyMeters = 4.0, hole = holeWithGreen(),
        )
        assertNotNull(distance)
        distance!!
        assertTrue(
            "front should be nearer than center",
            distance.frontGreen.meters < distance.centerGreen.meters,
        )
        assertTrue(
            "center should be nearer than back",
            distance.centerGreen.meters < distance.backGreen.meters,
        )
        assertNotNull(distance.pin)
        assertEquals(4, distance.par)
        assertEquals(380, distance.holeLengthMeters)
    }

    @Test
    fun `compute returns null when green geometry is incomplete`() {
        val holeNoEdges = holeWithGreen().copy(
            frontLat = null, frontLon = null, backLat = null, backLon = null,
        )
        assertNull(
            WearDistanceCalculator.compute(
                playerLat, playerLon, accuracyMeters = 4.0, hole = holeNoEdges,
            ),
        )
    }

    @Test
    fun `confidence decreases as accuracy worsens`() {
        val good = WearDistanceCalculator.confidenceForAccuracy(3.0)
        val poor = WearDistanceCalculator.confidenceForAccuracy(40.0)
        assertTrue(good > poor)
        assertTrue(good <= 1.0 && poor >= 0.0)
    }

    @Test
    fun `hazard distance uses nearest edge of bounding box`() {
        val hole = holeWithGreen().copy(
            hazards = listOf(
                WearHoleSubset.WearHazardGeometry(
                    type = HazardType.WATER,
                    label = "Lake",
                    minLat = 21.02050,
                    minLon = 105.82990,
                    maxLat = 21.02070,
                    maxLon = 105.83010,
                ),
            ),
        )
        val distance = WearDistanceCalculator.compute(
            playerLat, playerLon, accuracyMeters = 5.0, hole = hole,
        )
        assertNotNull(distance)
        val hazard = distance!!.hazards.single()
        // Player is south of the box; nearest edge is minLat (~55 m away),
        // clearly less than the distance to the box centre (~66 m).
        assertTrue("hazard distance should be positive", hazard.meters > 0)
        assertTrue("nearest-edge distance should be under 60 m", hazard.meters < 60.0)
    }
}
