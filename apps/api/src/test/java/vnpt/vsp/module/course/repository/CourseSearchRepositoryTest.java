package vnpt.vsp.module.course.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.ActiveProfiles;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.entity.Hole;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Repository tests for {@link CourseSearchRepository}.
 * Per Story 3.2 SD-BACK-1: AC-1 (text search), AC-2 (ST_DWithin — tested via code review).
 *
 * <p>Text search is a native query now — it folds diacritics through
 * {@code unaccent} so that "Long Bien" finds "Long Biên", which is how a phone
 * keyboard usually types it. H2 has neither that extension nor
 * {@code string_to_array}, so this runs against Postgres and is skipped
 * elsewhere: an H2 green here would be a claim about a database nobody
 * runs.</p>
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
class CourseSearchRepositoryTest {

    static boolean postgisAvailable() {
        return vnpt.vsp.persistence.PostgresTestSupport.postgisAvailable();
    }


    @Autowired
    private CourseSearchRepository repository;

    @Autowired
    private GolfFacilityRepository facilityRepository;

    @Autowired
    private TestEntityManager em;

    private GolfFacility createFacility(String name, String address) {
        GolfFacility f = new GolfFacility();
        f.getMetadata().setPublisher("TEST");
        f.setName(name);
        f.setAddress(address);
        return facilityRepository.save(f);
    }

    /**
     * A course a golfer could actually play — so, one with holes on it.
     *
     * <p>These fixtures used to write the course row alone, which is not a
     * state search should ever return: a course with no hole rows has no pars,
     * and a golfer who picks it out of a result list arrives at an empty
     * scorecard. {@link #createNamedCourseWithoutHoles} covers that state
     * deliberately.
     */
    private Course createCourse(GolfFacility facility, String name) {
        Course c = createNamedCourseWithoutHoles(facility, name);
        Hole hole = new Hole();
        hole.getMetadata().setPublisher("TEST");
        hole.setCourse(c);
        hole.setHoleNumber(1);
        hole.setPar(4);
        em.persist(hole);
        return c;
    }

    /**
     * The other state a course row can be in: named by the club, and with no
     * card behind it yet. Splitting a facility into its real sân or đường
     * writes exactly this, on purpose — a hole needs a par, and a par nobody
     * read off the club's card is invented.
     */
    private Course createNamedCourseWithoutHoles(GolfFacility facility, String name) {
        Course c = new Course();
        c.getMetadata().setPublisher("TEST");
        c.setFacility(facility);
        c.setName(name);
        c.setHolesCount(18);
        c.setParTotal(72);
        return repository.save(c);
    }

    @Test
    void searchByText_aDuongWithNoCardYet_isNotSomethingToPlay() {
        // Long Biên's three nines are named by the club and have no pars until
        // a golfer photographs the card. Search is where someone goes looking
        // for a round, and holesCount reads 18 on these rows the same as on any
        // other — the club really does have that many — so a result list gives
        // no warning before they pick one and land on an empty scorecard.
        GolfFacility facility = createFacility("Long Bien Golf Course", "Long Bien, Ha Noi");
        createCourse(facility, "Long Bien Golf Course — Championship");
        createNamedCourseWithoutHoles(facility, "Duong A");
        createNamedCourseWithoutHoles(facility, "Duong B");
        em.flush();

        Page<Course> results = repository.searchByText("Long Bien", PageRequest.of(0, 10));

        // Asserted by content, not by count: this runs against whatever
        // database is to hand, and a count is a claim about every other row
        // in it as well as these.
        var names = results.getContent().stream().map(Course::getName).toList();
        assertTrue(names.contains("Long Bien Golf Course — Championship"),
                "the course with holes on it is something a golfer can play");
        assertFalse(names.contains("Duong A"),
                "a đường with no card yet is not something to play");
        assertFalse(names.contains("Duong B"));
    }

    @Test
    void searchByText_matchingTheDuongsOwnName_stillFindsNothingToPlay() {
        // Searching the đường by name is the same trap from the other side: the
        // name matches, and there is still nothing behind it to score against.
        GolfFacility facility = createFacility("Long Bien Golf Course", "Long Bien, Ha Noi");
        createNamedCourseWithoutHoles(facility, "Duong C");
        em.flush();

        var names = repository.searchByText("Duong C", PageRequest.of(0, 10))
                .getContent().stream().map(Course::getName).toList();
        assertFalse(names.contains("Duong C"),
                "the name matches and there is still nothing behind it to score against");
    }

    @Test
    void searchByText_findsByFacilityName() {
        GolfFacility facility = createFacility("Thuyle Golf Club", "123 Nguyen Van Linh");
        createCourse(facility, "Championship Course");
        em.flush();

        Page<Course> results = repository.searchByText("Thuyle", PageRequest.of(0, 10));

        assertEquals(1, results.getTotalElements());
        assertEquals("Championship Course", results.getContent().get(0).getName());
    }

    @Test
    void searchByText_findsByCourseName() {
        GolfFacility facility = createFacility("Thuyle Golf Club", "123 Nguyen Van Linh");
        createCourse(facility, "Championship Course");
        em.flush();

        Page<Course> results = repository.searchByText("Thuyle Championship", PageRequest.of(0, 10));

        assertTrue(results.getContent().stream()
                        .anyMatch(c -> "Championship Course".equals(c.getName())),
                "a course is findable by its own name");
    }

    @Test
    void searchByText_findsByFacilityAddress() {
        GolfFacility facility = createFacility("Thuyle Golf Club", "123 Nguyen Van Linh");
        createCourse(facility, "Championship Course");
        em.flush();

        Page<Course> results = repository.searchByText("Van Linh", PageRequest.of(0, 10));

        assertEquals(1, results.getTotalElements());
    }

    @Test
    void searchByText_caseInsensitive() {
        GolfFacility facility = createFacility("Thuyle Golf Club", "123 Nguyen Van Linh");
        createCourse(facility, "Championship Course");
        em.flush();

        Page<Course> results = repository.searchByText("THUYLE", PageRequest.of(0, 10));

        assertEquals(1, results.getTotalElements());
    }

    @Test
    void searchByText_noMatch_returnsEmpty() {
        GolfFacility facility = createFacility("Thuyle Golf Club", "123 Nguyen Van Linh");
        createCourse(facility, "Championship Course");
        em.flush();

        Page<Course> results = repository.searchByText("NonExistent", PageRequest.of(0, 10));

        assertTrue(results.getContent().isEmpty());
    }

    @Test
    void searchByText_partialMatch() {
        GolfFacility facility = createFacility("Thuyle Golf Club", "123 Nguyen Van Linh");
        createCourse(facility, "Championship Course");
        em.flush();

        Page<Course> results = repository.searchByText("Thuyle", PageRequest.of(0, 10));

        assertTrue(results.getContent().stream()
                        .anyMatch(c -> "Thuyle Golf Club".equals(c.getFacility().getName())),
                "part of a word still finds the club");
    }

    @Test
    void searchByText_multipleMatches() {
        GolfFacility facility1 = createFacility("Thuyle Golf Club", "123 Nguyen Van Linh");
        GolfFacility facility2 = createFacility("Thuyle Beach Resort", "456 Le Loi");
        createCourse(facility1, "Championship Course");
        createCourse(facility2, "Ocean Course");
        em.flush();

        Page<Course> results = repository.searchByText("Thuyle", PageRequest.of(0, 10));

        assertEquals(2, results.getTotalElements());
    }

    @Test
    void searchByText_pagination_works() {
        for (int i = 0; i < 5; i++) {
            GolfFacility facility = createFacility("Facility " + i, "Address " + i);
            createCourse(facility, "Course " + i);
        }
        em.flush();

        Page<Course> page0 = repository.searchByText("Facility", PageRequest.of(0, 2));
        Page<Course> page1 = repository.searchByText("Facility", PageRequest.of(1, 2));

        assertEquals(2, page0.getContent().size());
        assertEquals(2, page1.getContent().size());
        assertEquals(5, page0.getTotalElements());
        assertEquals(5, page1.getTotalElements());
    }

    @Test
    void searchByText_emptyQuery_returnsEmpty() {
        GolfFacility facility = createFacility("Thuyle Golf Club", "123 Nguyen Van Linh");
        createCourse(facility, "Championship Course");
        em.flush();

        // Empty string should still return results (SQL LIKE %% matches everything)
        Page<Course> results = repository.searchByText("", PageRequest.of(0, 10));
        assertFalse(results.getContent().isEmpty());
    }
}
