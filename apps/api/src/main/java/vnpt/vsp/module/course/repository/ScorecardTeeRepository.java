package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vnpt.vsp.module.course.entity.ScorecardTee;

import java.util.List;

/**
 * The tee rows of a card, saved through their own repository rather than left
 * to cascade from the scorecard.
 *
 * <p>They used to cascade, and the yardages did not arrive: a card approved on
 * production logged "2 tee(s), 36 yardage(s)" and left {@code
 * scorecard_tee_yardages} empty. The tees themselves landed — they cascade one
 * level from the card, the same as the holes — but the yardages hang a second
 * level down, added to a collection after the card had already been flushed,
 * and nothing carried them to the insert.
 *
 * <p>One explicit save of the tee, one cascade to its yardages: the same shape
 * that has always worked for {@code scorecard_holes}. A failure surfaces here
 * rather than as rows that were counted and never written.
 */
public interface ScorecardTeeRepository extends JpaRepository<ScorecardTee, Long> {

    List<ScorecardTee> findByScorecardId(Long scorecardId);
}
