package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.Hole;

import java.util.List;
import java.util.Optional;

@Repository
public interface HoleRepository extends JpaRepository<Hole, Long> {

    List<Hole> findByCourseIdOrderByHoleNumber(Long courseId);

    /**
     * Which of these courses have any holes at all, in one query.
     *
     * <p>A course row can exist with none. Splitting a facility into its sân or
     * đường writes the units a club actually has and deliberately writes no
     * hole rows, because a hole needs a par and a par nobody read off the
     * club's card is invented. The pars arrive later through the scorecard
     * correction queue.
     *
     * <p>Until they do, the row is a name and nothing else, and the round-setup
     * picker must not offer it: `holes_count` on the course says 18 because the
     * club has eighteen, so the golfer is shown "Kings Course · 18 holes",
     * picks it, and arrives at a scorecard with nothing on it.
     */
    @org.springframework.data.jpa.repository.Query(
        "SELECT DISTINCT h.course.id FROM Hole h WHERE h.course.id IN :courseIds")
    List<Long> findCourseIdsWithHoles(
        @org.springframework.data.repository.query.Param("courseIds") java.util.Collection<Long> courseIds);

    Optional<Hole> findByCourseIdAndHoleNumber(Long courseId, Integer holeNumber);

    boolean existsByCourseIdAndHoleNumber(Long courseId, Integer holeNumber);

    @org.springframework.data.jpa.repository.Query(
        "SELECT COALESCE(SUM(h.par), 0) FROM Hole h WHERE h.course.id = :courseId")
    int sumParByCourseId(@org.springframework.data.repository.query.Param("courseId") Long courseId);

    /**
     * How many of a course's holes the app will actually treat as surveyed.
     *
     * <p>Uses the mobile provenance gate verbatim — VERIFIED and not class D.
     * A course listing badged itself from the course's {@code data_version}
     * metadata instead, which geometry review never touches, so Long Thành
     * showed "Chưa xác minh" to every golfer while all eighteen of its holes
     * were verified and its strategic map was drawing. The badge has to answer
     * the same question the map does.</p>
     */
    @org.springframework.data.jpa.repository.Query("""
        SELECT COUNT(h) FROM Hole h
        WHERE h.course.id = :courseId
          AND h.metadata.verificationStatus = vnpt.vsp.module.course.entity.VerificationStatus.VERIFIED
          AND h.metadata.accuracyClass <> vnpt.vsp.module.course.entity.AccuracyClass.D_UNVERIFIED_COMMUNITY
        """)
    long countSurveyedHoles(
            @org.springframework.data.repository.query.Param("courseId") Long courseId);

    long countByCourseId(Long courseId);

    /**
     * The weakest accuracy class among a course's holes.
     *
     * <p>The client's badge needs the class as well as the status — it treats
     * "verified" plus class D as unverified, exactly as the hole map does. So
     * deriving one from the holes and leaving the other on the course's stale
     * {@code data_version} left the two disagreeing, and the badge kept showing
     * the old answer.</p>
     *
     * <p>Weakest rather than best, because a course badge describes what a
     * golfer can rely on across the whole course. Enum names sort A, B, C, D
     * from best to worst, so the maximum name is the weakest class.</p>
     */
    @org.springframework.data.jpa.repository.Query("""
        SELECT MAX(h.metadata.accuracyClass) FROM Hole h WHERE h.course.id = :courseId
        """)
    vnpt.vsp.module.course.entity.AccuracyClass weakestAccuracyClass(
            @org.springframework.data.repository.query.Param("courseId") Long courseId);
}
