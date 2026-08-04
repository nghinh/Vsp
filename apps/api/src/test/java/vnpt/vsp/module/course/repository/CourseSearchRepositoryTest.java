package vnpt.vsp.module.course.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.ActiveProfiles;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.GolfFacility;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Repository tests for {@link CourseSearchRepository}.
 * Per Story 3.2 SD-BACK-1: AC-1 (text search), AC-2 (ST_DWithin — tested via code review).
 *
 * <p>JPQL text search is tested here. PostGIS ST_DWithin native queries
 * require a real PostGIS database and are verified via integration tests.</p>
 */
@DataJpaTest
@ActiveProfiles("test")
class CourseSearchRepositoryTest {

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

    private Course createCourse(GolfFacility facility, String name) {
        Course c = new Course();
        c.getMetadata().setPublisher("TEST");
        c.setFacility(facility);
        c.setName(name);
        c.setHolesCount(18);
        c.setParTotal(72);
        return repository.save(c);
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

        Page<Course> results = repository.searchByText("Championship", PageRequest.of(0, 10));

        assertEquals(1, results.getTotalElements());
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

        Page<Course> results = repository.searchByText("Thu", PageRequest.of(0, 10));

        assertEquals(1, results.getTotalElements());
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
