package vnpt.vsp.module.round.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

/**
 * One đường of a round, in the order it was played.
 *
 * <p>A club may hold several: Long Biên has đường A, B and C, and a round
 * there is a pairing of two of them chosen by the golfer on the day. A round
 * on a single eighteen has exactly one segment, which is why every existing
 * round could be backfilled without changing what it means.
 *
 * <p>The hole numbers a golfer counts — 1 to 18 — belong to the round, not to
 * any one đường. Round hole 12 on A+B is đường B's hole 3, and finding that
 * out means walking these segments in order against each course's hole count.
 */
@Entity
@Table(name = "round_segments")
public class RoundSegment {

    @EmbeddedId
    private RoundSegmentId id;

    @Column(name = "course_id", nullable = false)
    private Long courseId;

    protected RoundSegment() {
    }

    public RoundSegment(UUID roundId, int position, Long courseId) {
        this.id = new RoundSegmentId(roundId, (short) position);
        this.courseId = courseId;
    }

    public RoundSegmentId getId() {
        return id;
    }

    public void setId(RoundSegmentId id) {
        this.id = id;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public UUID getRoundId() {
        return id == null ? null : id.getRoundId();
    }

    public short getPosition() {
        return id == null ? 0 : id.getPosition();
    }

    @Embeddable
    public static class RoundSegmentId implements Serializable {

        @Column(name = "round_id", nullable = false)
        private UUID roundId;

        @Column(name = "position", nullable = false)
        private short position;

        protected RoundSegmentId() {
        }

        public RoundSegmentId(UUID roundId, short position) {
            this.roundId = roundId;
            this.position = position;
        }

        public UUID getRoundId() {
            return roundId;
        }

        public short getPosition() {
            return position;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) {
                return true;
            }
            if (!(other instanceof RoundSegmentId that)) {
                return false;
            }
            return position == that.position && Objects.equals(roundId, that.roundId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(roundId, position);
        }
    }
}
