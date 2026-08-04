package vnpt.vsp.api.admin;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.CourseAdminService;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.role.RoleService;

import java.util.List;
import java.util.stream.Collectors;

/**
 * REST controller for course admin endpoints.
 * Per Story 8.1 AC-1: requires COURSE_ADMIN or SUPER_ADMIN role.
 *
 * Endpoints:
 * - POST   /admin/facilities/{facilityId}/courses      — create course
 * - GET    /admin/facilities/{facilityId}/courses      — list courses
 * - GET    /admin/courses/{courseId}                  — get course
 * - PUT    /admin/courses/{courseId}                  — update course
 * - DELETE /admin/courses/{courseId}                  — delete course
 */
@RestController
@RequestMapping("/admin")
public class CourseAdminController {

    private static final Logger log = LoggerFactory.getLogger(CourseAdminController.class);

    private final CourseAdminService courseService;
    private final RoleService roleService;

    public CourseAdminController(CourseAdminService courseService, RoleService roleService) {
        this.courseService = courseService;
        this.roleService = roleService;
    }

    @PostMapping("/facilities/{facilityId}/courses")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<CourseResponse> createCourse(
            Authentication authentication,
            @PathVariable Long facilityId,
            @Valid @RequestBody CourseCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /admin/facilities/{}/courses - accountId={}, name={}", facilityId, accountId, request.getName());

        Course course = new Course();
        course.setName(request.getName());
        course.setHolesCount(request.getHolesCount());
        course.setParTotal(request.getParTotal());
        course.setLocation(request.getLocation());

        Course saved = courseService.createCourse(facilityId, course);
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(saved));
    }

    @GetMapping("/facilities/{facilityId}/courses")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<List<CourseResponse>> listCourses(
            Authentication authentication,
            @PathVariable Long facilityId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/facilities/{}/courses - accountId={}", facilityId, accountId);

        List<CourseResponse> courses = courseService.listCoursesByFacility(facilityId).stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(courses);
    }

    @GetMapping("/courses/{courseId}")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<CourseResponse> getCourse(
            Authentication authentication,
            @PathVariable Long courseId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/courses/{} - accountId={}", courseId, accountId);

        Course course = courseService.getCourse(courseId);
        return ResponseEntity.ok(toResponse(course));
    }

    @PutMapping("/courses/{courseId}")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<CourseResponse> updateCourse(
            Authentication authentication,
            @PathVariable Long courseId,
            @Valid @RequestBody CourseUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("PUT /admin/courses/{} - accountId={}", courseId, accountId);

        Course update = new Course();
        update.setName(request.getName());
        update.setHolesCount(request.getHolesCount());
        update.setParTotal(request.getParTotal());
        update.setLocation(request.getLocation());

        Course updated = courseService.updateCourse(courseId, update);
        return ResponseEntity.ok(toResponse(updated));
    }

    @DeleteMapping("/courses/{courseId}")
    @PreAuthorize("hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<Void> deleteCourse(
            Authentication authentication,
            @PathVariable Long courseId) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("DELETE /admin/courses/{} - accountId={}", courseId, accountId);

        throw new VspApiException(VspErrorCode.INTERNAL_004, "Delete not implemented for courses");
    }

    private void requireAdminRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005, "COURSE_ADMIN or SUPER_ADMIN role required");
        }
    }

    private CourseResponse toResponse(Course c) {
        CourseResponse r = new CourseResponse();
        r.setId(c.getId());
        r.setFacilityId(c.getFacility() != null ? c.getFacility().getId() : null);
        r.setName(c.getName());
        r.setHolesCount(c.getHolesCount());
        r.setParTotal(c.getParTotal());
        r.setLocation(c.getLocation());
        if (c.getDataQuality() != null) {
            r.setDataQuality(new DataQualityDto(
                    c.getDataQuality().getAccuracyClass() != null
                            ? c.getDataQuality().getAccuracyClass().name() : null,
                    c.getDataQuality().getVerificationStatus() != null
                            ? c.getDataQuality().getVerificationStatus().name() : null
            ));
        }
        if (c.getTeeSets() != null) {
            r.setTeeSets(c.getTeeSets().stream().map(ts -> {
                TeeSetSummaryDto dto = new TeeSetSummaryDto();
                dto.setId(ts.getId());
                dto.setName(ts.getName());
                dto.setTotalPar(ts.getTotalPar());
                return dto;
            }).collect(Collectors.toList()));
        }
        r.setCreatedAt(c.getMetadata() != null ? c.getMetadata().getCreatedAt() : null);
        r.setUpdatedAt(c.getMetadata() != null ? c.getMetadata().getUpdatedAt() : null);
        return r;
    }
}
