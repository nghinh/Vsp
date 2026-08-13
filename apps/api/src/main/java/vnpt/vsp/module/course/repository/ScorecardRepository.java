package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.Scorecard;

import java.util.List;
import java.util.Optional;

@Repository
public interface ScorecardRepository extends JpaRepository<Scorecard, Long> {

    /**
     * Every card this club has published.
     *
     * <p>Matching a card to a pairing is done in the service, in Java, over
     * this list: the comparison is "these đường, in this order", which JPQL
     * expresses only as a subquery with an index arithmetic that is harder to
     * read than the loop it replaces — and a club has three cards, not three
     * thousand.
     */
    List<Scorecard> findByFacilityId(Long facilityId);

    Optional<Scorecard> findByFacilityIdAndName(Long facilityId, String name);

    /**
     * Cards that carry this exact par row and this exact stroke index row.
     *
     * <p>No two real courses agree on all thirty-six of those numbers. Twelve
     * of the tables supplied for this project agreed on every one of them,
     * because they came off one template — and every other check passed all
     * twelve, since a generated table computes its own totals and so agrees
     * with itself perfectly. This is the only question asked about the world
     * rather than about the card.
     *
     * <p>Compared as strings built in the same order the card is written in.
     * A hole with no stroke index contributes {@code -1}, so a card that
     * prints no index row can only ever match another card that prints none —
     * and those are not judged on it, because par alone is far too weak.
     *
     * @param excludedId the card being written, so a reprint under its own
     *                   name does not collide with the copy it replaces
     */
    /// Native, because the signature is an ordered aggregate: the pars have to
    /// be joined in hole order, and JPQL has no way to say so — an unordered
    /// join would make two different cards look identical whenever the rows
    /// happened to come back in a different order.
    @Query(value = """
            SELECT s.id FROM scorecards s
            JOIN scorecard_holes sh ON sh.scorecard_id = s.id
            WHERE s.id <> :excludedId
            GROUP BY s.id
            HAVING string_agg(sh.par::text, ',' ORDER BY sh.hole_number) = :pars
               AND string_agg(coalesce(sh.stroke_index, -1)::text, ',' ORDER BY sh.hole_number) = :indexes
            """, nativeQuery = true)
    List<Long> findIdsWithSameParAndStrokeIndex(
            @Param("excludedId") Long excludedId,
            @Param("pars") String pars,
            @Param("indexes") String indexes);
}
