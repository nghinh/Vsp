package vnpt.vsp.module.course;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseAdminServiceImpl} validateForPublish.
 * Per Story 8.1 AC-2: validation prevents incomplete required data from publication.
 */
@ExtendWith(MockitoExtension.class)
class CourseAdminServiceImplTest {

    @Mock private CourseService courseService;
    @Mock private GolfFacilityRepository facilityRepository;
    @Mock private CourseRepository courseRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private TeeSetRepository teeSetRepository;

    private CourseAdminServiceImpl courseAdminService;

    @BeforeEach
    void setUp() {
        courseAdminService = new CourseAdminServiceImpl(
                courseService, facilityRepository, courseRepository,
                holeRepository, teeSetRepository);
    }

    // ─── validateForPublish tests ─────────────────────────────────────────

    @Test
    void validateForPublish_returnsNoErrors_whenCourseIsComplete() {
        // Given: facility with name, course with name/holesCount/parTotal, hole with number/par/green
        GolfFacility facility = new GolfFacility();
        facility.setId(1L);
        facility.setName("Tan Son Nhat Golf");

        Course course = new Course();
        course.setId(1L);
        course.setName("Main Course");
        course.setHolesCount(18);
        course.setParTotal(72);
        course.setFacility(facility);

        Hole hole = new Hole();
        hole.setId(1L);
        hole.setHoleNumber(1);
        hole.setPar(4);
        hole.setGreenLocation("POINT(106.123 10.456)");

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of(hole));

        // When
        List<String> errors = courseAdminService.validateForPublish(1L);

        // Then
        assertTrue(errors.isEmpty(), "Expected no errors for a complete course");
    }

    @Test
    void validateForPublish_returnsError_whenFacilityNameIsMissing() {
        // Given: facility with no name
        GolfFacility facility = new GolfFacility();
        facility.setId(1L);
        // name is null

        Course course = new Course();
        course.setId(1L);
        course.setName("Main Course");
        course.setHolesCount(18);
        course.setParTotal(72);
        course.setFacility(facility);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of());

        // When
        List<String> errors = courseAdminService.validateForPublish(1L);

        // Then
        assertTrue(errors.contains("Facility name is required"));
    }

    @Test
    void validateForPublish_returnsError_whenCourseNameIsMissing() {
        GolfFacility facility = new GolfFacility();
        facility.setId(1L);
        facility.setName("Tan Son Nhat Golf");

        Course course = new Course();
        course.setId(1L);
        // name is null
        course.setHolesCount(18);
        course.setParTotal(72);
        course.setFacility(facility);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of());

        // When
        List<String> errors = courseAdminService.validateForPublish(1L);

        // Then
        assertTrue(errors.contains("Course name is required for publication"));
    }

    @Test
    void validateForPublish_returnsError_whenCourseHasNoHoles() {
        GolfFacility facility = new GolfFacility();
        facility.setId(1L);
        facility.setName("Tan Son Nhat Golf");

        Course course = new Course();
        course.setId(1L);
        course.setName("Main Course");
        course.setHolesCount(18);
        course.setParTotal(72);
        course.setFacility(facility);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of());

        // When
        List<String> errors = courseAdminService.validateForPublish(1L);

        // Then
        assertTrue(errors.contains("Course must have at least one hole for publication"));
    }

    @Test
    void validateForPublish_returnsError_whenHoleGreenLocationIsMissing() {
        GolfFacility facility = new GolfFacility();
        facility.setId(1L);
        facility.setName("Tan Son Nhat Golf");

        Course course = new Course();
        course.setId(1L);
        course.setName("Main Course");
        course.setHolesCount(18);
        course.setParTotal(72);
        course.setFacility(facility);

        Hole hole = new Hole();
        hole.setId(1L);
        hole.setHoleNumber(1);
        hole.setPar(4);
        // greenLocation is null

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of(hole));

        // When
        List<String> errors = courseAdminService.validateForPublish(1L);

        // Then
        assertTrue(errors.stream().anyMatch(e -> e.contains("green location is required")));
    }

    @Test
    void validateForPublish_returnsMultipleErrors_whenMultipleIssues() {
        // Given: facility without name, course without name, no holes
        GolfFacility facility = new GolfFacility();
        facility.setId(1L);
        // name null

        Course course = new Course();
        course.setId(1L);
        // name null
        course.setHolesCount(18);
        course.setParTotal(72);
        course.setFacility(facility);

        when(courseRepository.findById(1L)).thenReturn(Optional.of(course));
        when(holeRepository.findByCourseIdOrderByHoleNumber(1L)).thenReturn(List.of());

        // When
        List<String> errors = courseAdminService.validateForPublish(1L);

        // Then
        assertTrue(errors.size() >= 2);
        assertTrue(errors.contains("Facility name is required"));
        assertTrue(errors.contains("Course name is required for publication"));
    }

    @Test
    void validateForPublish_returnsCourseNotFound_whenCourseDoesNotExist() {
        when(courseRepository.findById(99L)).thenReturn(Optional.empty());

        // When
        List<String> errors = courseAdminService.validateForPublish(99L);

        // Then
        assertEquals(1, errors.size());
        assertEquals("Course not found", errors.get(0));
    }
}
