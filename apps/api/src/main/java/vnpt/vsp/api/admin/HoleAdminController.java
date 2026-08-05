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
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.role.RoleService;

import java.util.List;
import java.util.stream.Collectors;

/**
 * REST controller for hole admin endpoints.
 * Per Story 8.1 AC-1: requires COURSE_ADMIN or SUPER_ADMIN role.
 *
 * Endpoints:
 * - POST   /admin/courses/{courseId}/holes        — create hole
 * - GET    /admin/courses/{courseId}/holes        — list holes
 * - GET    /admin/holes/{holeId}                 — get hole
 * - PUT    /admin/holes/{holeId}                 — update hole
 * - DELETE /admin/holes/{holeId}                 — delete hole
 */
@RestController
@RequestMapping("/admin")
public class HoleAdminController {

    private static final Logger log = LoggerFactory.getLogger(HoleAdminController.class);

    private final CourseAdminService courseService;
    private final RoleService roleService;

    public HoleAdminController(CourseAdminService courseService, RoleService roleService) {
        this.courseService = courseService;
        this.roleService = roleService;
    }

    @PostMapping("/courses/{courseId}/holes")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<HoleResponse> createHole(
            Authentication authentication,
            @PathVariable Long courseId,
            @Valid @RequestBody HoleCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /admin/courses/{}/holes - accountId={}, holeNumber={}", courseId, accountId, request.getHoleNumber());

        Hole hole = new Hole();
        hole.setHoleNumber(request.getHoleNumber());
        hole.setPar(request.getPar());
        hole.setTeeingGroundLocation(request.getTeeingGroundLocation());
        hole.setGreenLocation(request.getGreenLocation());
        hole.setPlayingLengthMeters(request.getPlayingLengthMeters());

        Hole saved = courseService.createHole(courseId, hole);
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(saved));
    }

    @GetMapping("/courses/{courseId}/holes")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<HoleResponse>> listHoles(
            Authentication authentication,
            @PathVariable Long courseId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/courses/{}/holes - accountId={}", courseId, accountId);

        List<HoleResponse> holes = courseService.listHolesByCourse(courseId).stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(holes);
    }

    @GetMapping("/holes/{holeId}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<HoleResponse> getHole(
            Authentication authentication,
            @PathVariable Long holeId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/holes/{} - accountId={}", holeId, accountId);

        Hole hole = courseService.getHole(holeId);
        return ResponseEntity.ok(toResponse(hole));
    }

    @PutMapping("/holes/{holeId}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<HoleResponse> updateHole(
            Authentication authentication,
            @PathVariable Long holeId,
            @Valid @RequestBody HoleUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("PUT /admin/holes/{} - accountId={}", holeId, accountId);

        Hole update = new Hole();
        update.setHoleNumber(request.getHoleNumber());
        update.setPar(request.getPar());
        update.setTeeingGroundLocation(request.getTeeingGroundLocation());
        update.setGreenLocation(request.getGreenLocation());
        update.setPlayingLengthMeters(request.getPlayingLengthMeters());

        Hole updated = courseService.updateHole(holeId, update);
        return ResponseEntity.ok(toResponse(updated));
    }

    @DeleteMapping("/holes/{holeId}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<Void> deleteHole(
            Authentication authentication,
            @PathVariable Long holeId) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("DELETE /admin/holes/{} - accountId={}", holeId, accountId);

        throw new VspApiException(VspErrorCode.INTERNAL_004, "Delete not implemented for holes");
    }

    private void requireAdminRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005, "COURSE_ADMIN or SUPER_ADMIN role required");
        }
    }

    private HoleResponse toResponse(Hole h) {
        HoleResponse r = new HoleResponse();
        r.setId(h.getId());
        r.setCourseId(h.getCourse() != null ? h.getCourse().getId() : null);
        r.setHoleNumber(h.getHoleNumber());
        r.setPar(h.getPar());
        r.setTeeingGroundLocation(h.getTeeingGroundLocation());
        r.setGreenLocation(h.getGreenLocation());
        r.setPlayingLengthMeters(h.getPlayingLengthMeters());
        if (h.getDataQuality() != null) {
            r.setDataQuality(new DataQualityDto(
                    h.getDataQuality().getAccuracyClass() != null
                            ? h.getDataQuality().getAccuracyClass().name() : null,
                    h.getDataQuality().getVerificationStatus() != null
                            ? h.getDataQuality().getVerificationStatus().name() : null
            ));
        }
        r.setTeeBoxesCount(h.getTeeBoxes() != null ? h.getTeeBoxes().size() : 0);
        return r;
    }
}
