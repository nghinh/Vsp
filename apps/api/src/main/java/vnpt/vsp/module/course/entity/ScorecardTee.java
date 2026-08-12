package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * One tee row of a printed card: what it measures and how it is rated.
 *
 * <p>A score only means something against the tee it was played from — the
 * same 82 is a different round off 7,311 yards than off 5,631 — and course
 * rating and slope are what turn a round into a handicap differential at all.
 *
 * <p>These hang off the card rather than the course because that is where a
 * club publishes them: one photograph, one review, one row per tee. A club
 * that reprints its card with new ratings replaces the card, and the tees go
 * with it.
 */
@Entity
@Table(name = "scorecard_tees")
public class ScorecardTee {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "scorecard_id", nullable = false)
    private Scorecard scorecard;

    /** As the club prints it: GOLD, BLACK, BLUE, WHITE, RED, or a Vietnamese name. */
    @Column(nullable = false, length = 60)
    private String name;

    /**
     * Both nullable, and often absent together: plenty of cards print yardages
     * and no ratings at all, and a card read from a photograph may have had
     * the rating table cut off at the edge of the frame.
     */
    @Column(name = "course_rating")
    private BigDecimal courseRating;

    @Column(name = "slope_rating")
    private Integer slopeRating;

    @OneToMany(mappedBy = "tee", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<ScorecardTeeYardage> yardages = new ArrayList<>();

    protected ScorecardTee() {
    }

    public ScorecardTee(Scorecard scorecard, String name, BigDecimal courseRating, Integer slopeRating) {
        this.scorecard = scorecard;
        this.name = name;
        this.courseRating = courseRating;
        this.slopeRating = slopeRating;
    }

    public Long getId() { return id; }
    public Scorecard getScorecard() { return scorecard; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public BigDecimal getCourseRating() { return courseRating; }
    public void setCourseRating(BigDecimal courseRating) { this.courseRating = courseRating; }
    public Integer getSlopeRating() { return slopeRating; }
    public void setSlopeRating(Integer slopeRating) { this.slopeRating = slopeRating; }
    public List<ScorecardTeeYardage> getYardages() { return yardages; }
}
