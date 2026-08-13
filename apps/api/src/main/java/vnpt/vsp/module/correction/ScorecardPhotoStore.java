package vnpt.vsp.module.correction;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * Keeps the photograph a card was read from.
 *
 * <p>Until this existed the photograph was the one thing the whole flow threw
 * away. The reader took an image, returned eighteen pars and ninety yardages,
 * and dropped the bytes; the submission carried an {@code evidenceUrl} the
 * golfer had to type by hand, and the portal's evidence panel said "Không có
 * ảnh kèm theo" for every card ever submitted. A reviewer approved numbers,
 * not a card.
 *
 * <p>That is the same shape as the failure this project has already paid for.
 * Nine fabricated cards were loaded because a table that adds up cannot be told
 * from a table that was transcribed — the photograph is what tells them apart,
 * and once it is gone the published card is a table again, permanently.
 *
 * <h2>Content-addressed</h2>
 *
 * <p>The file is named for the SHA-256 of its own bytes. That gives two things
 * for free: one club card photographed by four golfers is stored once, and the
 * name cannot be guessed by anyone who has not already seen the image. The
 * second is what makes it safe to serve these without a bearer token — a phone
 * showing {@code <img src>} does not send one, and neither would a CDN, which
 * is the same reason {@code /packages/**} is open.
 *
 * <h2>An unconfigured deployment still works</h2>
 *
 * <p>A directory that is missing, unwritable or unset turns this off rather
 * than failing the request: reading a card is still worth doing without the
 * evidence, and a golfer standing on the first tee should not be told that a
 * server-side volume is not mounted. It is logged loudly once, because a
 * deployment quietly discarding evidence is exactly what this class exists to
 * end.
 *
 * <h2>Phones that have not been updated</h2>
 *
 * <p>An app that already knows about {@code photoUrl} hands it back on the
 * submission and the link is explicit. Every app already installed does not,
 * and waiting for a release before evidence starts being kept would mean every
 * card submitted in the meantime is unverifiable forever.
 *
 * <p>So the read also remembers, briefly, which photograph a golfer last had
 * read for a course, and a submission that arrives with no evidence of its own
 * is matched to it. Keyed on the golfer and the course together, so it can only
 * ever attach a photograph to the submission of the person who took it, for the
 * course they took it at. Redis holds it, and a Redis that is down costs the
 * link and nothing else.
 */
@Service
public class ScorecardPhotoStore {

    private static final Logger log = LoggerFactory.getLogger(ScorecardPhotoStore.class);

    /// The path a stored photograph is served at, and the prefix the app hands
    /// straight back as `evidenceUrl`.
    public static final String URL_PREFIX = "/scorecard-photos/";

    /// A name this store could have written, and nothing else. Sixty-four hex
    /// characters and a known extension — no separators, so no traversal is
    /// expressible in the first place rather than being stripped out after.
    private static final Pattern STORED_NAME = Pattern.compile("^[0-9a-f]{64}\\.(jpg|png|webp)$");

    private static final Map<String, String> EXTENSIONS = Map.of(
            "image/jpeg", "jpg",
            "image/png", "png",
            "image/webp", "webp");

    private static final Map<String, String> MEDIA_TYPES = Map.of(
            "jpg", "image/jpeg",
            "png", "image/png",
            "webp", "image/webp");

    /// How long a read stays available to a submission that carries no
    /// evidence of its own. A golfer photographs the card at the first tee and
    /// submits it there or in the clubhouse after; a week is far past that and
    /// costs one short string per scan.
    private static final Duration RECALL_TTL = Duration.ofDays(7);

    private final Path directory;
    private final boolean enabled;
    private final RedisTemplate<String, Object> redis;

    public ScorecardPhotoStore(
            @Value("${vsp.scorecard-photos.dir:}") String configured,
            RedisTemplate<String, Object> redis) {
        this.redis = redis;
        Path resolved = null;
        boolean usable = false;

        if (configured != null && !configured.isBlank()) {
            resolved = Path.of(configured.trim()).toAbsolutePath().normalize();
            try {
                Files.createDirectories(resolved);
                usable = Files.isWritable(resolved);
                if (!usable) {
                    log.error("Scorecard photographs cannot be kept: {} is not writable by this process."
                            + " Cards will be published with no image behind them.", resolved);
                }
            } catch (IOException e) {
                log.error("Scorecard photographs cannot be kept: {} could not be created."
                        + " Cards will be published with no image behind them.", resolved, e);
            }
        } else {
            log.warn("vsp.scorecard-photos.dir is unset, so the photograph a card is read from is"
                    + " discarded. Set VSP_SCORECARD_PHOTO_DIR to a mounted volume to keep it.");
        }

        this.directory = resolved;
        this.enabled = usable;
    }

    /** True when a photograph handed to {@link #store} will actually be kept. */
    public boolean isEnabled() {
        return enabled;
    }

    /**
     * Keep this photograph and give back the path it is served at.
     *
     * <p>Returns null when the deployment has nowhere to put it, or when the
     * write fails. Both are the caller's cue to carry on without an evidence
     * URL rather than to fail the read: the golfer's card is still readable and
     * the numbers are still worth having.
     */
    public String store(byte[] data, String mediaType) {
        String extension = EXTENSIONS.get(mediaType);
        if (!enabled || data == null || data.length == 0 || extension == null) {
            return null;
        }

        String name = sha256(data) + "." + extension;
        Path target = directory.resolve(name);

        try {
            // The same card photographed by four golfers hashes to one name.
            // Rewriting identical bytes would only risk a torn read for
            // whoever is fetching it at that moment.
            if (!Files.exists(target)) {
                Files.write(target, data);
                log.info("Kept the photograph a card was read from: {} ({} bytes)", name, data.length);
            }
            return URL_PREFIX + name;
        } catch (IOException e) {
            log.error("Could not keep the photograph a card was read from", e);
            return null;
        }
    }

    /**
     * A stored photograph, or empty when this store never wrote it.
     *
     * <p>Anything that is not a name this store could have produced is empty
     * without touching the filesystem.
     */
    public Optional<Photo> read(String name) {
        if (!enabled || name == null || !STORED_NAME.matcher(name).matches()) {
            return Optional.empty();
        }
        Path target = directory.resolve(name).normalize();
        if (!target.startsWith(directory) || !Files.isRegularFile(target)) {
            return Optional.empty();
        }
        try {
            String extension = name.substring(name.lastIndexOf('.') + 1);
            return Optional.of(new Photo(Files.readAllBytes(target), MEDIA_TYPES.get(extension)));
        } catch (IOException e) {
            log.error("A stored scorecard photograph could not be read back: {}", name, e);
            return Optional.empty();
        }
    }

    /**
     * Remember that this golfer just had a card read for this course.
     *
     * <p>So that a submission from an app too old to know about
     * {@code photoUrl} can still be joined to the photograph behind it. Keyed
     * on both the golfer and the course, so it can never attach one person's
     * photograph to another's card.
     */
    public void remember(Long reporterId, Long courseId, String photoUrl) {
        if (photoUrl == null || reporterId == null || courseId == null) {
            return;
        }
        try {
            redis.opsForValue().set(recallKey(reporterId, courseId), photoUrl, RECALL_TTL);
        } catch (Exception e) {
            // The photograph is on disk either way. Losing the link is worth
            // less than failing the read the golfer is waiting on.
            log.warn("Could not remember which photograph course {} was read from: {}",
                    courseId, e.getMessage());
        }
    }

    /**
     * The photograph this golfer last had read for this course, if any.
     *
     * <p>Null is ordinary: a card typed by hand was never read from a
     * photograph, and there is nothing to attach.
     */
    public String recall(Long reporterId, Long courseId) {
        if (reporterId == null || courseId == null) {
            return null;
        }
        try {
            Object remembered = redis.opsForValue().get(recallKey(reporterId, courseId));
            return remembered == null ? null : remembered.toString();
        } catch (Exception e) {
            log.warn("Could not recall which photograph course {} was read from: {}",
                    courseId, e.getMessage());
            return null;
        }
    }

    private static String recallKey(Long reporterId, Long courseId) {
        return "scorecard-photo:" + reporterId + ":" + courseId;
    }

    private static String sha256(byte[] data) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data));
        } catch (NoSuchAlgorithmException e) {
            // Every JVM ships SHA-256; this cannot happen, and pretending it
            // can would mean a checked exception on every caller.
            throw new IllegalStateException(e);
        }
    }

    /** The bytes of a stored photograph and what they are. */
    public record Photo(byte[] data, String mediaType) {}
}
