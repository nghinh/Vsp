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
import vnpt.vsp.module.course.entity.TeeSet;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.role.RoleService;

import java.util.List;
import java.util.stream.Collectors;

/**
 * REST controller for tee set admin endpoints.
 * Per Story 8.1 AC-1: requires COURSE_ADMIN or SUPER_ADMIN role.
 *
 * Endpoints:
 * - POST   /admin/courses/{courseId}/tee-sets       — create tee set
 * - GET    /admin/courses/{courseId}/tee-sets       — list tee sets
 * - GET    /admin/tee-sets/{teeSetId}              — get tee set
 * - PUT    /admin/tee-sets/{teeSetId}              — update tee set
 * - DELETE /admin/tee-sets/{teeSetId}              — delete tee set
 */
@RestController
@RequestMapping("/admin")
public class TeeSetAdminController {

    private static final Logger log = LoggerFactory.getLogger(TeeSetAdminController.class);

    private final CourseAdminService courseService;
    private final RoleService roleService;

    public TeeSetAdminController(CourseAdminService courseService, RoleService roleService) {
        this.courseService = courseService;
        this.roleService = roleService;
    }

    @PostMapping("/courses/{courseId}/tee-sets")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<TeeSetResponse> createTeeSet(
            Authentication authentication,
            @PathVariable Long courseId,
            @Valid @RequestBody TeeSetCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /admin/courses/{}/tee-sets - accountId={}, name={}", courseId, accountId, request.getName());

        TeeSet teeSet = new TeeSet();
        teeSet.setName(request.getName());
        teeSet.setTotalPar(request.getTotalPar());

        TeeSet saved = courseService.createTeeSet(courseId, teeSet);
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(saved));
    }

    @GetMapping("/courses/{courseId}/tee-sets")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<List<TeeSetResponse>> listTeeSets(
            Authentication authentication,
            @PathVariable Long courseId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/courses/{}/tee-sets - accountId={}", courseId, accountId);

        List<TeeSetResponse> teeSets = courseService.getTeeSetsByCourse(courseId).stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(teeSets);
    }

    @GetMapping("/tee-sets/{teeSetId}")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<TeeSetResponse> getTeeSet(
            Authentication authentication,
            @PathVariable Long teeSetId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/tee-sets/{} - accountId={}", teeSetId, accountId);

        TeeSet teeSet = courseService.getTeeSet(teeSetId);
        return ResponseEntity.ok(toResponse(teeSet));
    }

    @PutMapping("/tee-sets/{teeSetId}")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<TeeSetResponse> updateTeeSet(
            Authentication authentication,
            @PathVariable Long teeSetId,
            @Valid @RequestBody TeeSetUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("PUT /admin/tee-sets/{} - accountId={}", teeSetId, accountId);

        TeeSet update = new TeeSet();
        update.setName(request.getName());
        update.setTotalPar(request.getTotalPar());

        TeeSet updated = courseService.updateTeeSet(teeSetId, update);
        return ResponseEntity.ok(toResponse(updated));
    }

    @DeleteMapping("/tee-sets/{teeSetId}")
    @PreAuthorize("hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<Void> deleteTeeSet(
            Authentication authentication,
            @PathVariable Long teeSetId) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("DELETE /admin/tee-sets/{} - accountId={}", teeSetId, accountId);

        throw new VspApiException(VspErrorCode.INTERNAL_004, "Delete not implemented for tee sets");
    }

    private void requireAdminRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005, "COURSE_ADMIN or SUPER_ADMIN role required");
        }
    }

    private TeeSetResponse toResponse(TeeSet ts) {
        TeeSetResponse r = new TeeSetResponse();
        r.setId(ts.getId());
        r.setCourseId(ts.getCourse() != null ? ts.getCourse().getId() : null);
        r.setName(ts.getName());
        r.setTotalPar(ts.getTotalPar());
        if (ts.getDataQuality() != null) {
            r.setDataQuality(new DataQualityDto(
                    ts.getDataQuality().getAccuracyClass() != null
                            ? ts.getDataQuality().getAccuracyClass().name() : null,
                    ts.getDataQuality().getVerificationStatus() != null
                            ? ts.getDataQuality().getVerificationStatus().name() : null
            ));
        }
        r.setCreatedAt(ts.getCreatedAt());
        r.setUpdatedAt(ts.getUpdatedAt());
        return r;
    }
}
