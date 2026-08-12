package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;

import java.io.Serializable;
import java.util.Objects;

/**
 * What one tee measures on one hole.
 *
 * <p>The hole number is the card's — 1..18 across the pairing of đường it was
 * printed for — the same number {@link ScorecardHole} counts to, so a par and
 * a yardage on the same line are about the same hole.
 */
@Entity
@Table(name = "scorecard_tee_yardages")
public class ScorecardTeeYardage {

    @EmbeddedId
    private ScorecardTeeYardageId id;

    @MapsId("scorecardTeeId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "scorecard_tee_id", nullable = false)
    private ScorecardTee tee;

    @Column(nullable = false)
    private Integer yards;

    protected ScorecardTeeYardage() {
    }

    public ScorecardTeeYardage(ScorecardTee tee, int holeNumber, int yards) {
        this.tee = tee;
        this.id = new ScorecardTeeYardageId(tee.getId(), holeNumber);
        this.yards = yards;
    }

    public ScorecardTeeYardageId getId() { return id; }
    public ScorecardTee getTee() { return tee; }
    public Integer getYards() { return yards; }
    public void setYards(Integer yards) { this.yards = yards; }
    public int getHoleNumber() { return id == null ? 0 : id.getHoleNumber(); }

    @Embeddable
    public static class ScorecardTeeYardageId implements Serializable {

        @Column(name = "scorecard_tee_id")
        private Long scorecardTeeId;

        @Column(name = "hole_number")
        private int holeNumber;

        protected ScorecardTeeYardageId() {
        }

        public ScorecardTeeYardageId(Long scorecardTeeId, int holeNumber) {
            this.scorecardTeeId = scorecardTeeId;
            this.holeNumber = holeNumber;
        }

        public Long getScorecardTeeId() { return scorecardTeeId; }
        public int getHoleNumber() { return holeNumber; }

        @Override
        public boolean equals(Object other) {
            if (this == other) return true;
            if (!(other instanceof ScorecardTeeYardageId that)) return false;
            return holeNumber == that.holeNumber && Objects.equals(scorecardTeeId, that.scorecardTeeId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(scorecardTeeId, holeNumber);
        }
    }
}
