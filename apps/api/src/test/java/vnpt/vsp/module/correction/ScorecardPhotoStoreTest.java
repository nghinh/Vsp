package vnpt.vsp.module.correction;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The photograph a card was read from, and the two ways it can go missing:
 * a deployment with nowhere to put it, and a name nobody stored.
 */
class ScorecardPhotoStoreTest {

    private static final byte[] CARD = "a photograph of a scorecard".getBytes();

    private ScorecardPhotoStore store(Path directory) {
        return new ScorecardPhotoStore(directory.toString(), null);
    }

    @Test
    void keepsThePhotographAndServesItBack(@TempDir Path dir) {
        ScorecardPhotoStore store = store(dir);

        String url = store.store(CARD, "image/jpeg");

        assertThat(url).startsWith(ScorecardPhotoStore.URL_PREFIX).endsWith(".jpg");
        String name = url.substring(ScorecardPhotoStore.URL_PREFIX.length());
        assertThat(store.read(name)).get()
                .extracting(ScorecardPhotoStore.Photo::mediaType)
                .isEqualTo("image/jpeg");
        assertThat(store.read(name).orElseThrow().data()).isEqualTo(CARD);
    }

    /// One club card photographed by four golfers is one file. The name is the
    /// SHA-256 of the bytes, so this falls out rather than being arranged.
    @Test
    void storesOneCopyOfOnePhotograph(@TempDir Path dir) throws Exception {
        ScorecardPhotoStore store = store(dir);

        String first = store.store(CARD, "image/jpeg");
        String second = store.store(CARD, "image/jpeg");

        assertThat(first).isEqualTo(second);
        try (var files = Files.list(dir)) {
            assertThat(files).hasSize(1);
        }
    }

    /// The name is what stands in for a bearer token on an open endpoint, so
    /// it has to be the content's own hash and not anything a caller supplied.
    @Test
    void namesThePhotographForItsOwnBytes(@TempDir Path dir) {
        ScorecardPhotoStore store = store(dir);

        String one = store.store(CARD, "image/jpeg");
        String other = store.store("a different card".getBytes(), "image/jpeg");

        assertThat(one).isNotEqualTo(other);
        assertThat(one.substring(ScorecardPhotoStore.URL_PREFIX.length()))
                .matches("[0-9a-f]{64}\\.jpg");
    }

    @Test
    void refusesANameItCouldNotHaveWritten(@TempDir Path dir) throws Exception {
        ScorecardPhotoStore store = store(dir);
        Files.writeString(dir.resolve("secret.txt"), "not a photograph");

        // Traversal, a name of the wrong shape, and a real file that this
        // store did not name — none of them are readable.
        assertThat(store.read("../secret.txt")).isEmpty();
        assertThat(store.read("secret.txt")).isEmpty();
        assertThat(store.read("../../etc/passwd")).isEmpty();
        assertThat(store.read("ZZZZ.jpg")).isEmpty();
    }

    @Test
    void refusesSomethingThatIsNotAPhotograph(@TempDir Path dir) {
        assertThat(store(dir).store(CARD, "application/pdf")).isNull();
        assertThat(store(dir).store(new byte[0], "image/jpeg")).isNull();
    }

    /// A deployment with no directory configured keeps nothing and says so by
    /// returning null — the card is still read, and the submission simply
    /// carries no evidence, exactly as it did before any of this existed.
    @Test
    void anUnconfiguredDeploymentKeepsNothing() {
        ScorecardPhotoStore store = new ScorecardPhotoStore("", null);

        assertThat(store.isEnabled()).isFalse();
        assertThat(store.store(CARD, "image/jpeg")).isNull();
        assertThat(store.read("a".repeat(64) + ".jpg")).isEmpty();
    }

    /// Redis being absent costs the link between a submission and its
    /// photograph, and nothing else. It must never cost the read itself.
    @Test
    void survivesRedisBeingUnreachable(@TempDir Path dir) {
        ScorecardPhotoStore store = store(dir);

        String url = store.store(CARD, "image/jpeg");

        assertThat(url).isNotNull();
        assertThat(store.recall(1L, 2L)).isNull();
        store.remember(1L, 2L, url);
    }
}
