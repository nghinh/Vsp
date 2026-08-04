package vnpt.vsp.module.course.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.FavoriteCourse;
import vnpt.vsp.module.course.entity.GolfFacility;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Repository tests for {@link FavoriteCourseRepository}.
 * Per Story 3.2 SD-BACK-1.
 */
@DataJpaTest
@ActiveProfiles("test")
class FavoriteCourseRepositoryTest {

    @Autowired
    private FavoriteCourseRepository repository;

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

        FavoriteCourse fav = new FavoriteCourse();
        fav.setUserId(100L);
        fav.setCourse(course);
        FavoriteCourse saved = repository.save(fav);
        em.flush();

        assertNotNull(saved.getId());
        assertNotNull(saved.getCreatedAt());
        assertEquals(100L, saved.getUserId());
    }

    @Test
    void findByUserIdOrderByCreatedAtDesc_returnsInOrder() throws Exception {
        GolfFacility facility = createFacility("Test Facility");
        Course course1 = createCourse(facility, "Course 1");
        Course course2 = createCourse(facility, "Course 2");

        FavoriteCourse fav1 = new FavoriteCourse();
        fav1.setUserId(100L);
        fav1.setCourse(course1);
        repository.save(fav1);
        Thread.sleep(10); // ensure different timestamps

        FavoriteCourse fav2 = new FavoriteCourse();
        fav2.setUserId(100L);
        fav2.setCourse(course2);
        repository.save(fav2);
        em.flush();

        List<FavoriteCourse> results = repository.findByUserIdOrderByCreatedAtDesc(100L);
        assertEquals(2, results.size());
        // Most recently created is first
        assertEquals(course2.getId(), results.get(0).getCourse().getId());
    }

    @Test
    void findByUserIdAndCourseId_returnsCorrectFavorite() {
        GolfFacility facility = createFacility("Test Facility");
        Course course = createCourse(facility, "Test Course");

        FavoriteCourse fav = new FavoriteCourse();
        fav.setUserId(100L);
        fav.setCourse(course);
        repository.save(fav);
        em.flush();

        Optional<FavoriteCourse> found = repository.findByUserIdAndCourseId(100L, course.getId());
        assertTrue(found.isPresent());

        Optional<FavoriteCourse> notFound = repository.findByUserIdAndCourseId(100L, 99999L);
        assertFalse(notFound.isPresent());
    }

    @Test
    void existsByUserIdAndCourseId_returnsTrueWhenExists() {
        GolfFacility facility = createFacility("Test Facility");
        Course course = createCourse(facility, "Test Course");

        FavoriteCourse fav = new FavoriteCourse();
        fav.setUserId(100L);
        fav.setCourse(course);
        repository.save(fav);
        em.flush();

        assertTrue(repository.existsByUserIdAndCourseId(100L, course.getId()));
        assertFalse(repository.existsByUserIdAndCourseId(100L, 99999L));
    }

    @Test
    void deleteByUserIdAndCourseId_removesFavorite() {
        GolfFacility facility = createFacility("Test Facility");
        Course course = createCourse(facility, "Test Course");

        FavoriteCourse fav = new FavoriteCourse();
        fav.setUserId(100L);
        fav.setCourse(course);
        repository.save(fav);
        em.flush();

        repository.deleteByUserIdAndCourseId(100L, course.getId());
        em.flush();

        assertFalse(repository.existsByUserIdAndCourseId(100L, course.getId()));
    }

    @Test
    void countByUserId_returnsCorrectCount() {
        GolfFacility facility = createFacility("Test Facility");
        Course course1 = createCourse(facility, "Course 1");
        Course course2 = createCourse(facility, "Course 2");

        FavoriteCourse fav1 = new FavoriteCourse();
        fav1.setUserId(100L);
        fav1.setCourse(course1);
        repository.save(fav1);

        FavoriteCourse fav2 = new FavoriteCourse();
        fav2.setUserId(100L);
        fav2.setCourse(course2);
        repository.save(fav2);
        em.flush();

        assertEquals(2, repository.countByUserId(100L));
        assertEquals(0, repository.countByUserId(99999L));
    }

    @Test
    void uniqueConstraint_sameUserSameCourse_throwsException() {
        GolfFacility facility = createFacility("Test Facility");
        Course course = createCourse(facility, "Test Course");

        FavoriteCourse fav1 = new FavoriteCourse();
        fav1.setUserId(100L);
        fav1.setCourse(course);
        repository.save(fav1);
        em.flush();

        FavoriteCourse fav2 = new FavoriteCourse();
        fav2.setUserId(100L);
        fav2.setCourse(course);

        assertThrows(Exception.class, () -> {
            repository.saveAndFlush(fav2);
        });
    }
}
