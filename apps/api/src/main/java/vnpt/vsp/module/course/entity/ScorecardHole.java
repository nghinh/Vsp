package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;

import java.io.Serializable;
import java.util.Objects;

/**
 * One numbered line of a printed card.
 *
 * <p>{@code holeNumber} is the number the golfer counts to — 1..18 across the
 * pairing — not the number painted on the đường's own tee marker. The stroke
 * index is the card's, and means nothing away from it.
 */
@Entity
@Table(name = "scorecard_holes")
public class ScorecardHole {

    @EmbeddedId
    private ScorecardHoleId id;

    @MapsId("scorecardId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "scorecard_id", nullable = false)
    private Scorecard scorecard;

    @Column(nullable = false)
    private Integer par;

    @Column(name = "stroke_index")
    private Integer strokeIndex;

    /**
     * The ladies index row, where the card prints a second one.
     *
     * <p>A hole's difficulty ranking changes with the distance played, so many
     * Vietnamese cards rank the eighteen twice. Null means the card printed one
     * index row — not that women play the hole unranked.
     */
    @Column(name = "stroke_index_ladies")
    private Integer strokeIndexLadies;

    protected ScorecardHole() {
    }

    public ScorecardHole(Scorecard scorecard, int holeNumber, Integer par, Integer strokeIndex) {
        this.scorecard = scorecard;
        this.id = new ScorecardHoleId(scorecard.getId(), holeNumber);
        this.par = par;
        this.strokeIndex = strokeIndex;
    }

    public ScorecardHoleId getId() { return id; }
    public Scorecard getScorecard() { return scorecard; }
    public Integer getPar() { return par; }
    public void setPar(Integer par) { this.par = par; }
    public Integer getStrokeIndex() { return strokeIndex; }
    public void setStrokeIndex(Integer strokeIndex) { this.strokeIndex = strokeIndex; }
    public Integer getStrokeIndexLadies() { return strokeIndexLadies; }
    public void setStrokeIndexLadies(Integer value) { this.strokeIndexLadies = value; }
    public int getHoleNumber() { return id == null ? 0 : id.getHoleNumber(); }

    @Embeddable
    public static class ScorecardHoleId implements Serializable {

        @Column(name = "scorecard_id")
        private Long scorecardId;

        @Column(name = "hole_number")
        private int holeNumber;

        protected ScorecardHoleId() {
        }

        public ScorecardHoleId(Long scorecardId, int holeNumber) {
            this.scorecardId = scorecardId;
            this.holeNumber = holeNumber;
        }

        public Long getScorecardId() { return scorecardId; }
        public int getHoleNumber() { return holeNumber; }

        @Override
        public boolean equals(Object other) {
            if (this == other) return true;
            if (!(other instanceof ScorecardHoleId that)) return false;
            return holeNumber == that.holeNumber && Objects.equals(scorecardId, that.scorecardId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(scorecardId, holeNumber);
        }
    }
}
