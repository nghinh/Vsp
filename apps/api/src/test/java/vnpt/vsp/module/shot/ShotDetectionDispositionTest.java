package vnpt.vsp.module.shot;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for the shot-detection confidence-threshold policy.
 * Per Story 10.4: confidence thresholds determine automatic, review-later,
 * confirm, or discard behavior.
 */
class ShotDetectionDispositionTest {

    @Test
    void nullConfidence_isDiscard() {
        assertEquals(ShotDetectionDisposition.DISCARD, ShotDetectionDisposition.forConfidence(null));
    }

    @Test
    void zero_isDiscard() {
        assertEquals(ShotDetectionDisposition.DISCARD, ShotDetectionDisposition.forConfidence(BigDecimal.ZERO));
    }

    @Test
    void justBelowDiscardMax_isDiscard() {
        assertEquals(ShotDetectionDisposition.DISCARD, ShotDetectionDisposition.forConfidence(new BigDecimal("0.19")));
    }

    @Test
    void atDiscardMax_isReviewLater() {
        assertEquals(ShotDetectionDisposition.REVIEW_LATER, ShotDetectionDisposition.forConfidence(new BigDecimal("0.20")));
    }

    @Test
    void midReviewLater_isReviewLater() {
        assertEquals(ShotDetectionDisposition.REVIEW_LATER, ShotDetectionDisposition.forConfidence(new BigDecimal("0.35")));
    }

    @Test
    void atReviewLaterMax_isConfirm() {
        assertEquals(ShotDetectionDisposition.CONFIRM, ShotDetectionDisposition.forConfidence(new BigDecimal("0.50")));
    }

    @Test
    void midConfirm_isConfirm() {
        assertEquals(ShotDetectionDisposition.CONFIRM, ShotDetectionDisposition.forConfidence(new BigDecimal("0.60")));
    }

    @Test
    void atConfirmMax_isAutomatic() {
        assertEquals(ShotDetectionDisposition.AUTOMATIC, ShotDetectionDisposition.forConfidence(new BigDecimal("0.75")));
    }

    @Test
    void high_isAutomatic() {
        assertEquals(ShotDetectionDisposition.AUTOMATIC, ShotDetectionDisposition.forConfidence(new BigDecimal("0.95")));
    }

    @Test
    void one_isAutomatic() {
        assertEquals(ShotDetectionDisposition.AUTOMATIC, ShotDetectionDisposition.forConfidence(BigDecimal.ONE));
    }

    @Test
    void discardDoesNotPersist_othersDo() {
        assertFalse(ShotDetectionDisposition.DISCARD.shouldPersist());
        assertTrue(ShotDetectionDisposition.REVIEW_LATER.shouldPersist());
        assertTrue(ShotDetectionDisposition.CONFIRM.shouldPersist());
        assertTrue(ShotDetectionDisposition.AUTOMATIC.shouldPersist());
    }
}
