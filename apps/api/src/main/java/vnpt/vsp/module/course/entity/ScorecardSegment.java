package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;

import java.io.Serializable;
import java.util.Objects;

/** One đường of a printed card, in the order the card lists it. */
@Entity
@Table(name = "scorecard_segments")
public class ScorecardSegment {

    @EmbeddedId
    private ScorecardSegmentId id;

    @MapsId("scorecardId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "scorecard_id", nullable = false)
    private Scorecard scorecard;

    @Column(name = "course_id", nullable = false)
    private Long courseId;

    protected ScorecardSegment() {
    }

    public ScorecardSegment(Scorecard scorecard, int position, Long courseId) {
        this.scorecard = scorecard;
        this.id = new ScorecardSegmentId(scorecard.getId(), (short) position);
        this.courseId = courseId;
    }

    public ScorecardSegmentId getId() { return id; }
    public Scorecard getScorecard() { return scorecard; }
    public Long getCourseId() { return courseId; }
    public short getPosition() { return id == null ? 0 : id.getPosition(); }

    @Embeddable
    public static class ScorecardSegmentId implements Serializable {

        @Column(name = "scorecard_id")
        private Long scorecardId;

        @Column(name = "position")
        private short position;

        protected ScorecardSegmentId() {
        }

        public ScorecardSegmentId(Long scorecardId, short position) {
            this.scorecardId = scorecardId;
            this.position = position;
        }

        public Long getScorecardId() { return scorecardId; }
        public short getPosition() { return position; }

        @Override
        public boolean equals(Object other) {
            if (this == other) return true;
            if (!(other instanceof ScorecardSegmentId that)) return false;
            return position == that.position && Objects.equals(scorecardId, that.scorecardId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(scorecardId, position);
        }
    }
}
