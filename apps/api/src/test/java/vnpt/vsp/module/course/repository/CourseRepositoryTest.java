package vnpt.vsp.module.course.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.GolfFacility;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Repository tests for {@link CourseRepository}.
 * Verifies CRUD operations and FK cascade per Story 3.1 AC-1.
 */
@DataJpaTest
@ActiveProfiles("test")
class CourseRepositoryTest {

    @Autowired
    private CourseRepository repository;

    @Autowired
    private GolfFacilityRepository facilityRepository;

    @Autowired
    private TestEntityManager em;

    private GolfFacility createFacility(String name) {
        GolfFacility facility = new GolfFacility();
        facility.getMetadata().setPublisher("TEST");
        facility.setName(name);
        return facilityRepository.save(facility);
    }

    @Test
    void save_andFindById_works() {
        GolfFacility facility = createFacility("Test Facility");
        Course course = new Course();
        course.getMetadata().setPublisher("TEST");
        course.setFacility(facility);
        course.setName("Championship Course");
        course.setHolesCount(18);
        course.setParTotal(72);

        Course saved = repository.save(course);
        em.flush();

        assertNotNull(saved.getId());
        assertEquals("Championship Course", saved.getName());
        assertEquals(18, saved.getHolesCount());
        assertEquals(72, saved.getParTotal());
    }

    @Test
    void findByGolfFacilityId_returnsCoursesForFacility() {
        GolfFacility facility = createFacility("Multi-Course Facility");
        Course course1 = new Course();
        course1.getMetadata().setPublisher("TEST");
        course1.setFacility(facility);
        course1.setName("East Course");
        course1.setHolesCount(18);
        course1.setParTotal(72);
        repository.save(course1);

        Course course2 = new Course();
        course2.getMetadata().setPublisher("TEST");
        course2.setFacility(facility);
        course2.setName("West Course");
        course2.setHolesCount(18);
        course2.setParTotal(72);
        repository.save(course2);
        em.flush();

        List<Course> results = repository.findByGolfFacilityId(facility.getId());
        assertEquals(2, results.size());
    }

    @Test
    void findByGolfFacilityId_returnsEmptyForNonExistentFacility() {
        // Use a non-existent Long ID
        List<Course> results = repository.findByGolfFacilityId(99999L);
        assertTrue(results.isEmpty());
    }

    @Test
    void findByGolfFacilityIdAndName_exactMatch() {
        GolfFacility facility = createFacility("Named Facility");
        Course course = new Course();
        course.getMetadata().setPublisher("TEST");
        course.setFacility(facility);
        course.setName("Unique Course Name");
        course.setHolesCount(9);
        course.setParTotal(36);
        repository.save(course);
        em.flush();

        Optional<Course> found = repository.findByGolfFacilityIdAndName(facility.getId(), "Unique Course Name");
        assertTrue(found.isPresent());

        Optional<Course> notFound = repository.findByGolfFacilityIdAndName(facility.getId(), "Wrong Name");
        assertFalse(notFound.isPresent());
    }

    @Test
    void countHolesByCourseId_returnsZeroForNewCourse() {
        GolfFacility facility = createFacility("New Course Facility");
        Course course = new Course();
        course.getMetadata().setPublisher("TEST");
        course.setFacility(facility);
        course.setName("Empty Course");
        course.setHolesCount(9);
        course.setParTotal(36);
        Course saved = repository.save(course);
        em.flush();

        long count = repository.countHolesByCourseId(saved.getId());
        assertEquals(0, count);
    }

    @Test
    void delete_courseDoesNotDeleteFacility() {
        GolfFacility facility = createFacility("Facility To Preserve");
        Course course = new Course();
        course.getMetadata().setPublisher("TEST");
        course.setFacility(facility);
        course.setName("Course To Delete");
        course.setHolesCount(9);
        course.setParTotal(36);
        Course saved = repository.save(course);
        em.flush();

        Long facilityId = facility.getId();
        repository.delete(saved);
        em.flush();

        assertFalse(repository.findById(saved.getId()).isPresent());
        assertTrue(facilityRepository.findById(facilityId).isPresent());
    }
}
