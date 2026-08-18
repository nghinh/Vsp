package vnpt.vsp.module.pkg;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.GolfFacilityRepository;
import vnpt.vsp.module.pkg.entity.CoursePackageManifest;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link PackageController}.
 *
 * Covers G3 (Stories 4-1 / 6-2): the optional facility/course descriptor fields
 * are populated in the manifest DTO from the course + facility geo, and the DTO
 * serializes those fields for the mobile offline detection flow.
 */
@ExtendWith(MockitoExtension.class)
class PackageControllerTest {

    @Mock private PackageService packageService;
    @Mock private CourseRepository courseRepository;
    @Mock private GolfFacilityRepository facilityRepository;

    private PackageController controller;

    @BeforeEach
    void setUp() {
        // No configured CDN and no servlet request in a unit test, so the
        // rehost is a no-op here and these assertions still read the stored
        // URLs. See PublicPackageUrlsTest for the rehosting itself.
        controller = new PackageController(
                packageService, courseRepository, facilityRepository,
                new PublicPackageUrls(""));
    }

    private CoursePackageManifest manifest(Long courseId) {
        CoursePackageManifest m = new CoursePackageManifest(
                courseId,
                courseId,               // dataVersionId
                "1.0." + courseId,      // version
                1_024L,                 // packageSizeBytes — a published package has payload
                "abc123",               // checksum
                Instant.parse("2026-08-01T00:00:00Z"),
                "1.0.0",
                CoursePackageManifest.TilesFormat.PMTILES,
                "https://cdn.vnptgolf.vn/packages/" + courseId + "/1.0." + courseId + "/tiles/tiles.pmtiles",
                "https://cdn.vnptgolf.vn/packages/" + courseId + "/1.0." + courseId + "/geometry/geometry.geojson",
                Instant.parse("2026-08-01T00:00:00Z"),
                "dev-seed");
        // id is JPA-generated; set it for the DTO mapping in unit context.
        ReflectionTestUtils.setField(m, "id", UUID.randomUUID());
        return m;
    }

    private Course courseWithFacility() {
        GolfFacility facility = new GolfFacility();
        facility.setId(7L);
        facility.setName("BRG Kings Island Golf Resort");
        facility.setAddress("Kings Island, Hanoi");

        Course course = new Course();
        course.setId(1L);
        course.setName("BRG Kings Island — Championship");
        course.setHolesCount(18);
        course.setParTotal(72);
        course.setFacility(facility);
        return course;
    }

    @Test
    void getCurrentManifest_populatesFacilityAndCourseDescriptorFields() {
        CoursePackageManifest m = manifest(1L);
        when(packageService.getActiveManifest(1L)).thenReturn(Optional.of(m));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(courseWithFacility()));
        when(facilityRepository.findLatitudeByFacilityId(7L)).thenReturn(21.0333);
        when(facilityRepository.findLongitudeByFacilityId(7L)).thenReturn(105.4);

        ResponseEntity<PackageController.CoursePackageManifestDto> resp =
                controller.getCurrentManifest(1L, null);

        assertEquals(HttpStatus.OK, resp.getStatusCode());
        PackageController.CoursePackageManifestDto dto = resp.getBody();
        assertNotNull(dto);
        assertEquals("7", dto.getFacilityId());
        assertEquals("BRG Kings Island Golf Resort", dto.getFacilityName());
        assertEquals("Kings Island, Hanoi", dto.getFacilityAddress());
        assertEquals(21.0333, dto.getFacilityLatitude());
        assertEquals(105.4, dto.getFacilityLongitude());
        assertEquals("BRG Kings Island — Championship", dto.getCourseName());
        assertEquals(18, dto.getHolesCount());
        assertEquals(72, dto.getParTotal());
    }

    @Test
    void getCurrentManifest_returnsNotFoundWhenNoManifest() {
        when(packageService.getActiveManifest(99L)).thenReturn(Optional.empty());

        ResponseEntity<PackageController.CoursePackageManifestDto> resp =
                controller.getCurrentManifest(99L, null);

        assertEquals(HttpStatus.NOT_FOUND, resp.getStatusCode());
    }

    @Test
    void getCurrentManifest_toleratesMissingCourseWithNullDescriptorFields() {
        CoursePackageManifest m = manifest(2L);
        when(packageService.getActiveManifest(2L)).thenReturn(Optional.of(m));
        when(courseRepository.findById(2L)).thenReturn(Optional.empty());

        ResponseEntity<PackageController.CoursePackageManifestDto> resp =
                controller.getCurrentManifest(2L, null);

        assertEquals(HttpStatus.OK, resp.getStatusCode());
        PackageController.CoursePackageManifestDto dto = resp.getBody();
        assertNotNull(dto);
        assertNull(dto.getFacilityId());
        assertNull(dto.getFacilityLatitude());
        assertNull(dto.getCourseName());
        // Core manifest fields still present.
        assertEquals("1.0.2", dto.getVersion());
    }

    @Test
    void dto_serializesFacilityFieldsToJson() throws Exception {
        CoursePackageManifest m = manifest(1L);
        when(packageService.getActiveManifest(1L)).thenReturn(Optional.of(m));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(courseWithFacility()));
        when(facilityRepository.findLatitudeByFacilityId(7L)).thenReturn(21.0333);
        when(facilityRepository.findLongitudeByFacilityId(7L)).thenReturn(105.4);

        PackageController.CoursePackageManifestDto dto =
                controller.getCurrentManifest(1L, null).getBody();

        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        String json = mapper.writeValueAsString(dto);

        assertTrue(json.contains("\"facilityLatitude\":21.0333"), json);
        assertTrue(json.contains("\"facilityLongitude\":105.4"), json);
        assertTrue(json.contains("\"facilityId\":\"7\""), json);
        assertTrue(json.contains("\"holesCount\":18"), json);
        assertTrue(json.contains("\"parTotal\":72"), json);
        assertTrue(json.contains("\"courseName\":"), json);
    }
}
