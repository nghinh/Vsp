package vnpt.vsp.module.course.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.ActiveProfiles;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.entity.RecentCourse;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Repository tests for {@link RecentCourseRepository}.
 * Per Story 3.2 SD-BACK-1.
 */
@DataJpaTest
@ActiveProfiles("test")
class RecentCourseRepositoryTest {

    @Autowired
    private RecentCourseRepository repository;

    @Autowired
    private GolfFacilityRepository facilityRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private TestEntityManager em;

    private GolfFacility createFacility(String name) {
        GolfFacility f = new GolfFacility();
        f.getMetadata().setPublisher("TEST");
        f.setName(name);
        return facilityRepository.save(f);
    }

    private Course createCourse(GolfFacility facility, String name) {
        Course c = new Course();
        c.getMetadata().setPublisher("TEST");
        c.setFacility(facility);
        c.setName(name);
        c.setHolesCount(18);
        c.setParTotal(72);
        return courseRepository.save(c);
    }

    @Test
    void save_andFindById_works() {
        GolfFacility facility = createFacility("Test Facility");
        Course course = createCourse(facility, "Test Course");

        RecentCourse recent = new RecentCourse();
        recent.setUserId(100L);
        recent.setCourse(course);
        RecentCourse saved = repository.save(recent);
        em.flush();

        assertNotNull(saved.getId());
        assertNotNull(saved.getViewedAt());
        assertEquals(100L, saved.getUserId());
    }

    @Test
    void findByUserIdOrderByViewedAtDesc_returnsInOrder() throws Exception {
        GolfFacility facility = createFacility("Test Facility");
        Course course1 = createCourse(facility, "Course 1");
        Course course2 = createCourse(facility, "Course 2");

        RecentCourse recent1 = new RecentCourse();
        recent1.setUserId(100L);
        recent1.setCourse(course1);
        repository.save(recent1);
        Thread.sleep(10);

        RecentCourse recent2 = new RecentCourse();
        recent2.setUserId(100L);
        recent2.setCourse(course2);
        repository.save(recent2);
        em.flush();

        List<RecentCourse> results = repository.findByUserIdOrderByViewedAtDesc(100L, PageRequest.of(0, 10));
        assertEquals(2, results.size());
        // Most recently viewed is first
        assertEquals(course2.getId(), results.get(0).getCourse().getId());
    }

    @Test
    void findByUserIdOrderByViewedAtDesc_respectsLimit() throws Exception {
        GolfFacility facility = createFacility("Test Facility");
        for (int i = 0; i < 5; i++) {
            Course course = createCourse(facility, "Course " + i);
            RecentCourse recent = new RecentCourse();
            recent.setUserId(100L);
            recent.setCourse(course);
            repository.save(recent);
            Thread.sleep(5);
        }
        em.flush();

        List<RecentCourse> limited = repository.findByUserIdOrderByViewedAtDesc(100L, PageRequest.of(0, 3));
        assertEquals(3, limited.size());
    }

    @Test
    void findByUserIdAndCourseId_returnsCorrectRecent() {
        GolfFacility facility = createFacility("Test Facility");
        Course course = createCourse(facility, "Test Course");

        RecentCourse recent = new RecentCourse();
        recent.setUserId(100L);
        recent.setCourse(course);
        repository.save(recent);
        em.flush();

        Optional<RecentCourse> found = repository.findByUserIdAndCourseId(100L, course.getId());
        assertTrue(found.isPresent());

        Optional<RecentCourse> notFound = repository.findByUserIdAndCourseId(100L, 99999L);
        assertFalse(notFound.isPresent());
    }

    @Test
    void countByUserId_returnsCorrectCount() {
        GolfFacility facility = createFacility("Test Facility");
        for (int i = 0; i < 3; i++) {
            Course course = createCourse(facility, "Course " + i);
            RecentCourse recent = new RecentCourse();
            recent.setUserId(100L);
            recent.setCourse(course);
            repository.save(recent);
        }
        em.flush();

        assertEquals(3, repository.countByUserId(100L));
        assertEquals(0, repository.countByUserId(99999L));
    }

    @Test
    void uniqueConstraint_sameUserSameCourse_throwsException() {
        GolfFacility facility = createFacility("Test Facility");
        Course course = createCourse(facility, "Test Course");

        RecentCourse recent1 = new RecentCourse();
        recent1.setUserId(100L);
        recent1.setCourse(course);
        repository.save(recent1);
        em.flush();

        RecentCourse recent2 = new RecentCourse();
        recent2.setUserId(100L);
        recent2.setCourse(course);

        assertThrows(Exception.class, () -> {
            repository.saveAndFlush(recent2);
        });
    }

    @Test
    void findByUserIdAndCourseId_notFound_returnsEmpty() {
        Optional<RecentCourse> result = repository.findByUserIdAndCourseId(99999L, 99999L);
        assertTrue(result.isEmpty());
    }
}
