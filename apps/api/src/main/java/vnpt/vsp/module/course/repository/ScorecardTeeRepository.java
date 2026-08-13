package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import vnpt.vsp.module.course.entity.ScorecardTee;

import java.util.Collection;
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

    /**
     * Every tee row of these cards, yardages included, in two queries' worth of
     * work done as one.
     *
     * <p>Reading them off {@code card.getTees()} instead would be a query per
     * card for the tees and another per tee for its yardages. A club with five
     * cards of five tees is thirty-one round trips for ninety rows apiece, and
     * the endpoint that lists a facility's cards would get slower every time a
     * club published another one — which is the one thing it exists to
     * encourage.
     *
     * <p>Ordered by id so the tees come back the way the card printed them,
     * left to right, rather than in whatever order the rows happen to arrive.
     */
    @Query("""
            select t from ScorecardTee t
            left join fetch t.yardages
            where t.scorecard.id in :scorecardIds
            order by t.id
            """)
    List<ScorecardTee> findWithYardagesByScorecardIdIn(
            @Param("scorecardIds") Collection<Long> scorecardIds);

    /**
     * The tees of whatever card was published for this one đường.
     *
     * <p>Reached through {@code scorecard_segments}, because a card names the
     * đường it was printed for rather than belonging to one. Restricted to
     * cards of a single segment: a card printed for A+B measures the pairing,
     * and its hole 12 is đường B's hole 3, so lifting its yardages onto đường
     * A alone would put the wrong numbers against the wrong holes.
     */
    @Query("""
            select distinct t from ScorecardTee t
            left join fetch t.yardages
            where t.scorecard.id in (
                select s.scorecard.id from ScorecardSegment s
                where s.courseId = :courseId
                group by s.scorecard.id
                having count(s) = 1
            )
            order by t.id
            """)
    List<ScorecardTee> findWithYardagesByCourseId(@Param("courseId") Long courseId);
}
