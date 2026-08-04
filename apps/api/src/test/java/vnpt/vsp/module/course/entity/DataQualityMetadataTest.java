package vnpt.vsp.module.course.entity;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for DataQualityMetadata embeddable.
 * Verifies field defaults, nullability, and data integrity per Story 3.1 AC-3.
 */
class DataQualityMetadataTest {

    @Test
    void defaultValues_areSet() {
        DataQualityMetadata metadata = new DataQualityMetadata();

        assertNull(metadata.getSource());
        assertNull(metadata.getLicense());
        assertEquals(AccuracyClass.D_UNVERIFIED_COMMUNITY, metadata.getAccuracyClass());
        assertEquals(BigDecimal.ZERO, metadata.getConfidence());
        assertEquals(VerificationStatus.UNVERIFIED, metadata.getVerificationStatus());
        assertNull(metadata.getLastVerifiedAt());
        assertEquals(LocalDate.now(), metadata.getEffectiveDate());
        assertNull(metadata.getExpiryDate());
        assertNull(metadata.getPublisher());
        assertEquals(1, metadata.getVersion());
    }

    @Test
    void setAllFields_allFieldsAreRetrievable() {
        DataQualityMetadata metadata = new DataQualityMetadata();
        metadata.setSource("Vietnam Golf Survey Co.");
        metadata.setLicense("CC BY 4.0");
        metadata.setAccuracyClass(AccuracyClass.A_RTK_SURVEYED);
        metadata.setConfidence(new BigDecimal("95.50"));
        metadata.setVerificationStatus(VerificationStatus.VERIFIED);
        metadata.setLastVerifiedAt(Instant.parse("2026-08-01T10:00:00Z"));
        metadata.setEffectiveDate(LocalDate.parse("2026-09-01"));
        metadata.setExpiryDate(LocalDate.parse("2026-12-31"));
        metadata.setPublisher("admin@golf.vn");
        metadata.setVersion(3);

        assertEquals("Vietnam Golf Survey Co.", metadata.getSource());
        assertEquals("CC BY 4.0", metadata.getLicense());
        assertEquals(AccuracyClass.A_RTK_SURVEYED, metadata.getAccuracyClass());
        assertEquals(new BigDecimal("95.50"), metadata.getConfidence());
        assertEquals(VerificationStatus.VERIFIED, metadata.getVerificationStatus());
        assertEquals(Instant.parse("2026-08-01T10:00:00Z"), metadata.getLastVerifiedAt());
        assertEquals(LocalDate.parse("2026-09-01"), metadata.getEffectiveDate());
        assertEquals(LocalDate.parse("2026-12-31"), metadata.getExpiryDate());
        assertEquals("admin@golf.vn", metadata.getPublisher());
        assertEquals(3, metadata.getVersion());
    }

    @Test
    void confidence_allowsZeroAnd100() {
        DataQualityMetadata metadata = new DataQualityMetadata();

        metadata.setConfidence(BigDecimal.ZERO);
        assertEquals(BigDecimal.ZERO, metadata.getConfidence());

        metadata.setConfidence(new BigDecimal("100.00"));
        assertEquals(new BigDecimal("100.00"), metadata.getConfidence());
    }

    @Test
    void accuracyClass_allFourValues() {
        DataQualityMetadata metadata = new DataQualityMetadata();

        metadata.setAccuracyClass(AccuracyClass.A_RTK_SURVEYED);
        assertEquals(AccuracyClass.A_RTK_SURVEYED, metadata.getAccuracyClass());

        metadata.setAccuracyClass(AccuracyClass.B_LICENSED_PROVIDER);
        assertEquals(AccuracyClass.B_LICENSED_PROVIDER, metadata.getAccuracyClass());

        metadata.setAccuracyClass(AccuracyClass.C_VERIFIED_SATELLITE);
        assertEquals(AccuracyClass.C_VERIFIED_SATELLITE, metadata.getAccuracyClass());

        metadata.setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
        assertEquals(AccuracyClass.D_UNVERIFIED_COMMUNITY, metadata.getAccuracyClass());
    }

    @Test
    void verificationStatus_allFourValues() {
        DataQualityMetadata metadata = new DataQualityMetadata();

        metadata.setVerificationStatus(VerificationStatus.UNVERIFIED);
        assertEquals(VerificationStatus.UNVERIFIED, metadata.getVerificationStatus());

        metadata.setVerificationStatus(VerificationStatus.PENDING_REVIEW);
        assertEquals(VerificationStatus.PENDING_REVIEW, metadata.getVerificationStatus());

        metadata.setVerificationStatus(VerificationStatus.VERIFIED);
        assertEquals(VerificationStatus.VERIFIED, metadata.getVerificationStatus());

        metadata.setVerificationStatus(VerificationStatus.REJECTED);
        assertEquals(VerificationStatus.REJECTED, metadata.getVerificationStatus());
    }
}
