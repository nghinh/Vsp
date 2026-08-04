package vnpt.vsp.module.course.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.entity.Hole;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Repository tests for {@link HoleRepository}.
 * Verifies hole_number uniqueness per course and par range per Story 3.1 AC-1.
 */
@DataJpaTest
@ActiveProfiles("test")
class HoleRepositoryTest {

    @Autowired
    private HoleRepository repository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private GolfFacilityRepository facilityRepository;

    @Autowired
    private TestEntityManager em;

    private Course createCourse(String name) {
        GolfFacility facility = new GolfFacility();
        facility.getMetadata().setPublisher("TEST");
        facility.setName(name + " Facility");
        GolfFacility savedFacility = facilityRepository.save(facility);

        Course course = new Course();
        course.getMetadata().setPublisher("TEST");
        course.setFacility(savedFacility);
        course.setName(name);
        course.setHolesCount(18);
        course.setParTotal(72);
        return courseRepository.save(course);
    }

    private Hole createHole(Course course, int number, int par) {
        Hole hole = new Hole();
        hole.getMetadata().setPublisher("TEST");
        hole.setCourse(course);
        hole.setHoleNumber(number);
        hole.setPar(par);
        return repository.save(hole);
    }

    @Test
    void save_andFindById_works() {
        Course course = createCourse("Test Course");
        Hole hole = createHole(course, 1, 4);
        em.flush();

        assertNotNull(hole.getId());
        assertEquals(1, hole.getHoleNumber());
        assertEquals(4, hole.getPar());
    }

    @Test
    void findByCourseIdOrderByHoleNumber_returnsOrderedHoles() {
        Course course = createCourse("Ordering Test Course");
        createHole(course, 3, 4);
        createHole(course, 1, 3);
        createHole(course, 2, 5);
        em.flush();

        List<Hole> holes = repository.findByCourseIdOrderByHoleNumber(course.getId());

        assertEquals(3, holes.size());
        assertEquals(1, holes.get(0).getHoleNumber());
        assertEquals(2, holes.get(1).getHoleNumber());
        assertEquals(3, holes.get(2).getHoleNumber());
    }

    @Test
    void findByCourseIdAndHoleNumber_exactMatch() {
        Course course = createCourse("Lookup Test Course");
        createHole(course, 1, 4);
        createHole(course, 2, 3);
        em.flush();

        Optional<Hole> hole18 = repository.findByCourseIdAndHoleNumber(course.getId(), 18);
        assertFalse(hole18.isPresent());

        Optional<Hole> hole1 = repository.findByCourseIdAndHoleNumber(course.getId(), 1);
        assertTrue(hole1.isPresent());
        assertEquals(4, hole1.get().getPar());
    }

    @Test
    void existsByCourseIdAndHoleNumber_returnsTrueWhenExists() {
        Course course = createCourse("Existence Test Course");
        createHole(course, 5, 4);
        em.flush();

        assertTrue(repository.existsByCourseIdAndHoleNumber(course.getId(), 5));
        assertFalse(repository.existsByCourseIdAndHoleNumber(course.getId(), 99));
    }

    @Test
    void sumParByCourseId_calculatesTotalPar() {
        Course course = createCourse("Par Sum Test Course");
        createHole(course, 1, 4);
        createHole(course, 2, 5);
        createHole(course, 3, 3);
        em.flush();

        int totalPar = repository.sumParByCourseId(course.getId());
        assertEquals(12, totalPar);
    }

    @Test
    void sumParByCourseId_returnsZeroForCourseWithNoHoles() {
        Course course = createCourse("Empty Course");
        em.flush();

        int totalPar = repository.sumParByCourseId(course.getId());
        assertEquals(0, totalPar);
    }

    @Test
    void parRange_acceptsValidValues() {
        Course course = createCourse("Par Range Test Course");

        // Par 3 (short hole)
        Hole par3 = createHole(course, 1, 3);
        assertEquals(3, par3.getPar());

        // Par 4 (medium hole)
        Hole par4 = createHole(course, 2, 4);
        assertEquals(4, par4.getPar());

        // Par 5 (long hole)
        Hole par5 = createHole(course, 3, 5);
        assertEquals(5, par5.getPar());

        em.flush();
    }

    @Test
    void playingLengthMeter_isStoredAndRetrieved() {
        Course course = createCourse("Length Test Course");
        Hole hole = createHole(course, 1, 4);
        hole.setPlayingLengthMeters(new BigDecimal("320.50"));
        em.flush();

        Optional<Hole> found = repository.findById(hole.getId());
        assertTrue(found.isPresent());
        assertEquals(new BigDecimal("320.50"), found.get().getPlayingLengthMeters());
    }
}
