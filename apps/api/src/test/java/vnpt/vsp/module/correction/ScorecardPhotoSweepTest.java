package vnpt.vsp.module.correction;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Sweeping the photographs nothing points at.
 *
 * <p>The asymmetry is the whole design and is what these assert: a photograph
 * deleted in error cannot be recovered and takes a published card's evidence
 * with it, while one kept in error costs a few megabytes. Every test here is
 * about something the sweep must refuse to delete.
 */
class ScorecardPhotoSweepTest {

    @TempDir Path dir;

    private ScorecardPhotoStore store;
    private EntityManager em;

    private static final byte[] IMAGE = "a photograph".getBytes();

    @BeforeEach
    void setUp() {
        store = new ScorecardPhotoStore(dir.toString(), null);
        em = mock(EntityManager.class);
        referencedUrls(List.of());
    }

    private void referencedUrls(List<String> urls) {
        Query query = mock(Query.class);
        when(em.createNativeQuery(anyString())).thenReturn(query);
        when(query.getResultList()).thenReturn(urls);
    }

    private ScorecardPhotoSweep sweep(Duration grace) {
        return new ScorecardPhotoSweep(store, em, grace);
    }

    private String write(byte[] bytes, Duration age) throws IOException {
        String url = store.store(bytes, "image/jpeg");
        String name = url.substring(ScorecardPhotoStore.URL_PREFIX.length());
        Files.setLastModifiedTime(dir.resolve(name),
                FileTime.from(Instant.now().minus(age)));
        return name;
    }

    @Test
    void removesAnOldPhotographNothingRefersTo() throws Exception {
        String name = write(IMAGE, Duration.ofDays(30));

        assertThat(sweep(Duration.ofDays(10)).sweepOnce()).isEqualTo(1);
        assertThat(store.read(name)).isEmpty();
    }

    /// The reason the photographs are kept at all. An approved card's image is
    /// how it can still be checked a year later, so age never makes it stale.
    @Test
    void keepsAPhotographACorrectionNamesAsEvidence() throws Exception {
        String name = write(IMAGE, Duration.ofDays(365));
        referencedUrls(List.of(ScorecardPhotoStore.URL_PREFIX + name));

        assertThat(sweep(Duration.ofDays(10)).sweepOnce()).isZero();
        assertThat(store.read(name)).isPresent();
    }

    /// A golfer scans at the first tee and submits from the clubhouse, and the
    /// server holds its matching note for seven days. Sweeping inside that
    /// window would break exactly the case the note exists for.
    @Test
    void keepsAPhotographYoungerThanTheGracePeriod() throws Exception {
        String name = write(IMAGE, Duration.ofDays(2));

        assertThat(sweep(Duration.ofDays(10)).sweepOnce()).isZero();
        assertThat(store.read(name)).isPresent();
    }

    /// A URL a golfer pasted themselves carries a host in front of the name.
    /// Matching on the whole string would delete the image it refers to.
    @Test
    void recognisesAReferenceWrittenAsAFullUrl() throws Exception {
        String name = write(IMAGE, Duration.ofDays(30));
        referencedUrls(List.of("https://vps-api.vnteki.com" + ScorecardPhotoStore.URL_PREFIX + name));

        assertThat(sweep(Duration.ofDays(10)).sweepOnce()).isZero();
        assertThat(store.read(name)).isPresent();
    }

    /// A deployment that keeps no photographs has nothing to sweep, and must
    /// not touch a directory it was never given.
    @Test
    void doesNothingWhenNoDirectoryIsConfigured() {
        var off = new ScorecardPhotoSweep(
                new ScorecardPhotoStore("", null), em, Duration.ofDays(10));

        assertThat(off.sweepOnce()).isZero();
    }
}
