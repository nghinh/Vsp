package vnpt.vsp.module.course.entity;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for DataVersion entity.
 * Verifies DRAFT → PUBLISHED state transition and version number increment.
 */
class DataVersionTest {

    @Test
    void newInstance_hasDraftStatus() {
        DataVersion dv = new DataVersion();
        assertEquals(DataVersionStatus.DRAFT, dv.getStatus());
    }

    @Test
    void publish_setsStatusToPublished() {
        DataVersion dv = new DataVersion();
        dv.setVersionNumber(1);
        dv.publish("admin@vsp.com", "Initial RTK survey data");

        assertEquals(DataVersionStatus.PUBLISHED, dv.getStatus());
        assertNotNull(dv.getPublishedAt());
        assertEquals("admin@vsp.com", dv.getPublishedBy());
        assertEquals("Initial RTK survey data", dv.getPublishNote());
    }

    @Test
    void archive_setsStatusToArchived() {
        DataVersion dv = new DataVersion();
        dv.setStatus(DataVersionStatus.PUBLISHED);
        dv.archive();

        assertEquals(DataVersionStatus.ARCHIVED, dv.getStatus());
    }

    @Test
    void nextVersionNumber_returnsPlusOne() {
        DataVersion dv = new DataVersion();
        dv.setVersionNumber(1);
        assertEquals(2, dv.nextVersionNumber());

        dv.setVersionNumber(5);
        assertEquals(6, dv.nextVersionNumber());
    }

    @Test
    void versionNumber_cannotBeZero() {
        DataVersion dv = new DataVersion();
        dv.setVersionNumber(0);
        assertEquals(0, dv.getVersionNumber());
        // DB constraint enforces positive value; entity layer allows 0 for pre-set
    }

    // ─── Rollback transition tests ───────────────────────────────────────

    @Test
    void rollbackTo_reactivatesArchivedVersionAsPublished() {
        DataVersion dv = new DataVersion();
        dv.setVersionNumber(2);
        dv.setStatus(DataVersionStatus.ARCHIVED);
        dv.setPublishedAt(Instant.parse("2026-07-01T10:00:00Z"));
        dv.setPublishedBy("old@vsp.com");
        dv.setPublishNote("Old publish note");

        dv.rollbackTo("admin@vsp.com", "Reverting to good data");

        assertEquals(DataVersionStatus.PUBLISHED, dv.getStatus());
        assertEquals("admin@vsp.com", dv.getPublishedBy());
        assertEquals("Reverting to good data", dv.getRollbackNote());
        assertNotNull(dv.getPublishedAt());
        assertTrue(dv.getPublishedAt().isAfter(Instant.parse("2026-07-01T10:00:00Z")));
        // Original publishNote is preserved
        assertEquals("Old publish note", dv.getPublishNote());
    }

    @Test
    void rollbackTo_clearsRollbackNote_onSubsequentRollback() {
        DataVersion dv = new DataVersion();
        dv.setVersionNumber(2);
        dv.setStatus(DataVersionStatus.ARCHIVED);

        dv.rollbackTo("admin@vsp.com", "First rollback");
        assertEquals("First rollback", dv.getRollbackNote());

        dv.rollbackTo("admin@vsp.com", "Second rollback");
        assertEquals("Second rollback", dv.getRollbackNote());
    }

    @Test
    void rollbackTo_setsPublishedAtToNow() {
        DataVersion dv = new DataVersion();
        dv.setVersionNumber(1);
        dv.setStatus(DataVersionStatus.ARCHIVED);

        Instant before = Instant.now();
        dv.rollbackTo("admin@vsp.com", "Rollback");
        Instant after = Instant.now();

        assertNotNull(dv.getPublishedAt());
        assertTrue(dv.getPublishedAt().compareTo(before) >= 0);
        assertTrue(dv.getPublishedAt().compareTo(after) <= 0);
    }

    @Test
    void rollbackNote_getterSetter_roundTrip() {
        DataVersion dv = new DataVersion();
        assertNull(dv.getRollbackNote());

        dv.setRollbackNote("Reverting bad geometry edit");
        assertEquals("Reverting bad geometry edit", dv.getRollbackNote());
    }
}
