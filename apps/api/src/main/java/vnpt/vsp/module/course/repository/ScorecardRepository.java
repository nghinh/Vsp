package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
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
}
