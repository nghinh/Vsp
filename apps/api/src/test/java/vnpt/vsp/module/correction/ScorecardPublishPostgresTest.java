package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.module.correction.dto.ScorecardSubmissionRequest;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.ScorecardRepository;
import vnpt.vsp.module.course.entity.ScorecardTee;
import vnpt.vsp.module.course.repository.ScorecardTeeRepository;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Publishing an approved card, against the database that has to hold it.
 *
 * <p>{@link ScorecardCorrectionServiceImplTest} covers the same path with a
 * mocked repository, and passed while production wrote nothing: it asserted
 * that the right objects were hung off the right collections, which is a claim
 * about a Java object graph and not about any row. A card approved on
 * production logged "2 tee(s), 36 yardage(s)" and left {@code
 * scorecard_tee_yardages} empty, because the yardages were added to a
 * collection a level below one that had already been flushed and nothing
 * carried them to an insert.
 *
 * <p>Everything load-bearing here is what JPA does at flush — a derived
 * {@code @MapsId} key that cannot be built before its parent has an id, a
 * cascade across two levels, a unique constraint on the tee name — and none of
 * it can be checked without a database. Skipped rather than run against H2:
 * a skipped test is honest, and an H2 green here would say exactly what the
 * mock said.
 */
@DataJpaTest(properties = {
        "spring.datasource.url=jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DB:vsp}",
        "spring.datasource.username=${POSTGRES_USER:vsp}",
        "spring.datasource.password=${POSTGRES_PASSWORD:vsp_dev_password}",
        "spring.datasource.driver-class-name=org.postgresql.Driver",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.flyway.enabled=false",
        "spring.sql.init.mode=never"
})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@EnabledIf("postgisAvailable")
class ScorecardPublishPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private CourseCorrectionRepository correctionRepository;
    @Autowired private ScorecardRepository scorecardRepository;
    @Autowired private ScorecardTeeRepository scorecardTeeRepository;
    @Autowired private CourseRepository courseRepository;
    @Autowired private vnpt.vsp.module.identity.repository.GolferAccountRepository golferAccountRepository;
    @Autowired private EntityManager em;

    private ScorecardCorrectionServiceImpl service;
    private Long courseId;

    @BeforeEach
    void setUp() {
        // No photograph store: this probe is about what reaches the tables,
        // and an unconfigured store is what a deployment without a mounted
        // volume has — the card still publishes, with no image behind it.
        service = new ScorecardCorrectionServiceImpl(
                correctionRepository, scorecardRepository, scorecardTeeRepository,
                courseRepository, new ScorecardPhotoStore("", null), golferAccountRepository,
                "", new ObjectMapper());

        GolfFacility facility = new GolfFacility();
        facility.setName("Scorecard publish probe facility");
        stamp(facility.getMetadata());
        em.persist(facility);

        Course course = new Course();
        course.setFacility(facility);
        course.setName("Scorecard publish probe course");
        course.setHolesCount(18);
        course.setParTotal(72);
        stamp(course.getMetadata());
        em.persist(course);
        em.flush();

        courseId = course.getId();
    }

    private static void stamp(DataQualityMetadata metadata) {
        metadata.setPublisher("scorecard-publish-test");
        metadata.setEffectiveDate(LocalDate.now());
        metadata.setConfidence(BigDecimal.ZERO);
    }

    private ScorecardSubmissionRequest card(List<ScorecardSubmissionRequest.TeeLine> tees) {
        List<ScorecardSubmissionRequest.HoleLine> holes = java.util.stream.IntStream.rangeClosed(1, 18)
                .mapToObj(i -> new ScorecardSubmissionRequest.HoleLine(i, i % 3 == 0 ? 3 : 4, i))
                .toList();
        return new ScorecardSubmissionRequest(
                "Probe card", List.of(courseId), holes, tees, null, null);
    }

    private ScorecardSubmissionRequest.TeeLine tee(String name, String rating, Integer slope, int holes) {
        return tee(name, rating, slope, holes, null);
    }

    private ScorecardSubmissionRequest.TeeLine tee(
            String name, String rating, Integer slope, int holes, String gender) {
        return new ScorecardSubmissionRequest.TeeLine(
                name,
                rating == null ? null : new BigDecimal(rating),
                slope,
                gender,
                null, null, null,
                java.util.stream.IntStream.rangeClosed(1, holes)
                        .mapToObj(i -> new ScorecardSubmissionRequest.Yardage(i, 300 + i))
                        .toList());
    }

    @Test
    @DisplayName("a tee rated for men and for women keeps both rows")
    void bothRatingsOfOneTeeSurvive() {
        // A course is rated separately for men and for women, and a card that
        // prints ratings prints both — commonly two rows against the same
        // colour. The dedupe keyed on the name alone, so whichever arrived
        // second went on the floor with its ratings and its eighteen
        // yardages, and nothing recorded that it had.
        CourseCorrection correction = service.submit(courseId, 11L,
                card(List.of(tee("RED", "68.2", 118, 18, "MEN"),
                             tee("RED", "72.4", 128, 18, "LADIES"))));

        service.applyIfScorecard(correction);
        em.flush();
        em.clear();

        var card = scorecardRepository.findByFacilityIdAndName(
                courseRepository.findById(courseId).orElseThrow().getFacility().getId(),
                "Probe card").orElseThrow();

        var tees = scorecardTeeRepository.findByScorecardId(card.getId());
        assertThat(tees).hasSize(2);
        assertThat(tees).extracting(t -> t.getGender())
                .containsExactlyInAnyOrder(ScorecardTee.Gender.MEN, ScorecardTee.Gender.LADIES);

        var ladies = tees.stream()
                .filter(t -> t.getGender() == ScorecardTee.Gender.LADIES)
                .findFirst().orElseThrow();
        assertThat(ladies.getCourseRating()).isEqualByComparingTo(new BigDecimal("72.4"));
        assertThat(ladies.getSlopeRating()).isEqualTo(128);
    }

    @Test
    @DisplayName("the same row read twice is still dropped, gender or no gender")
    void aRepeatedRowIsStillOneRow() {
        CourseCorrection correction = service.submit(courseId, 11L,
                card(List.of(tee("GOLD", "75.5", 138, 18, "MEN"),
                             tee("GOLD", "75.5", 138, 18, "MEN"))));

        service.applyIfScorecard(correction);
        em.flush();
        em.clear();

        var card = scorecardRepository.findByFacilityIdAndName(
                courseRepository.findById(courseId).orElseThrow().getFacility().getId(),
                "Probe card").orElseThrow();

        assertThat(scorecardTeeRepository.findByScorecardId(card.getId())).hasSize(1);
    }

    @Test
    @DisplayName("an unlabelled rating is unspecified, never assumed to be the men's")
    void anUnlabelledRatingIsNotAssumed() {
        // Reading it as the men's would be a guess that looks like data: a
        // woman playing off it gets a handicap differential computed against
        // the wrong rating, with nothing anywhere to show where it came from.
        CourseCorrection correction = service.submit(courseId, 11L,
                card(List.of(tee("BLUE", "71.0", 125, 18))));

        service.applyIfScorecard(correction);
        em.flush();
        em.clear();

        var card = scorecardRepository.findByFacilityIdAndName(
                courseRepository.findById(courseId).orElseThrow().getFacility().getId(),
                "Probe card").orElseThrow();

        assertThat(scorecardTeeRepository.findByScorecardId(card.getId()))
                .singleElement()
                .extracting(t -> t.getGender())
                .isEqualTo(ScorecardTee.Gender.UNSPECIFIED);
    }

    @Test
    @DisplayName("an approved card's yardages reach the table, not just the object graph")
    void yardagesAreWritten() {
        CourseCorrection correction = service.submit(courseId, 11L,
                card(List.of(tee("GOLD", "75.5", 138, 18), tee("RED", "72.9", 129, 18))));

        service.applyIfScorecard(correction);
        em.flush();
        em.clear();

        var card = scorecardRepository.findByFacilityIdAndName(
                courseRepository.findById(courseId).orElseThrow().getFacility().getId(),
                "Probe card").orElseThrow();

        Long rows = (Long) em.createQuery("""
                SELECT count(y) FROM ScorecardTeeYardage y
                WHERE y.tee.scorecard.id = :cardId
                """).setParameter("cardId", card.getId()).getSingleResult();

        assertThat(rows).isEqualTo(36L);

        var tees = scorecardTeeRepository.findByScorecardId(card.getId());
        assertThat(tees).hasSize(2);
        assertThat(tees).extracting(t -> t.getName()).containsExactlyInAnyOrder("GOLD", "RED");

        var gold = tees.stream().filter(t -> t.getName().equals("GOLD")).findFirst().orElseThrow();
        assertThat(gold.getCourseRating()).isEqualByComparingTo(new BigDecimal("75.5"));
        assertThat(gold.getSlopeRating()).isEqualTo(138);
        assertThat(gold.getYardages()).hasSize(18);
        assertThat(gold.getYardages().stream().mapToInt(y -> y.getYards()).sum())
                .isEqualTo(java.util.stream.IntStream.rangeClosed(1, 18).map(i -> 300 + i).sum());
    }

    @Test
    @DisplayName("a reprint replaces the tees rather than colliding with them")
    void aReprintReplacesTheTees() {
        // `scorecard_tees` is unique on (scorecard_id, name), so a second card
        // of the same name has to remove the old rows before it writes its
        // own. Whether the orphan removal actually runs before the insert is a
        // question only the database answers.
        CourseCorrection first = service.submit(courseId, 11L,
                card(List.of(tee("GOLD", "75.5", 138, 18))));
        service.applyIfScorecard(first);
        em.flush();

        CourseCorrection second = service.submit(courseId, 11L,
                card(List.of(tee("GOLD", "74.1", 136, 9), tee("BLUE", "71.9", 133, 9))));
        service.applyIfScorecard(second);
        em.flush();
        em.clear();

        var card = scorecardRepository.findByFacilityIdAndName(
                courseRepository.findById(courseId).orElseThrow().getFacility().getId(),
                "Probe card").orElseThrow();
        var tees = scorecardTeeRepository.findByScorecardId(card.getId());

        assertThat(tees).hasSize(2);
        var gold = tees.stream().filter(t -> t.getName().equals("GOLD")).findFirst().orElseThrow();
        assertThat(gold.getSlopeRating()).isEqualTo(136);
        assertThat(gold.getYardages()).hasSize(9);
    }

    @Test
    @DisplayName("a card with no tee rows still publishes its pars")
    void aCardWithoutTeesStillPublishes() {
        CourseCorrection correction = service.submit(courseId, 11L, card(List.of()));

        service.applyIfScorecard(correction);
        em.flush();
        em.clear();

        var card = scorecardRepository.findByFacilityIdAndName(
                courseRepository.findById(courseId).orElseThrow().getFacility().getId(),
                "Probe card").orElseThrow();

        assertThat(card.getHoles()).hasSize(18);
        assertThat(scorecardTeeRepository.findByScorecardId(card.getId())).isEmpty();
    }
}
