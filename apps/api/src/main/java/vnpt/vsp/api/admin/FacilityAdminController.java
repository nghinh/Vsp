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
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.role.RoleService;

import java.util.List;
import java.util.stream.Collectors;

/**
 * REST controller for facility admin endpoints.
 * Per Story 8.1 AC-1: requires COURSE_ADMIN or SUPER_ADMIN role.
 *
 * Endpoints:
 * - POST   /admin/facilities               — create facility
 * - GET    /admin/facilities               — list all facilities
 * - GET    /admin/facilities/{id}          — get facility
 * - PUT    /admin/facilities/{id}          — update facility
 * - DELETE /admin/facilities/{id}          — delete facility (SUPER_ADMIN only)
 */
@RestController
@RequestMapping("/admin/facilities")
public class FacilityAdminController {

    private static final Logger log = LoggerFactory.getLogger(FacilityAdminController.class);

    private final CourseAdminService courseService;
    private final RoleService roleService;

    public FacilityAdminController(CourseAdminService courseService, RoleService roleService) {
        this.courseService = courseService;
        this.roleService = roleService;
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<FacilityResponse> createFacility(
            Authentication authentication,
            @Valid @RequestBody FacilityCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /admin/facilities - accountId={}, name={}", accountId, request.getName());

        GolfFacility facility = new GolfFacility();
        facility.setName(request.getName());
        facility.setAddress(request.getAddress());
        facility.setPhone(request.getPhone());
        facility.setWebsite(request.getWebsite());
        facility.setLocation(request.getLocation());

        GolfFacility saved = courseService.createFacility(facility);
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(saved));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<FacilityResponse>> listFacilities(Authentication authentication) {
        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/facilities - accountId={}", accountId);

        List<FacilityResponse> facilities = courseService.listFacilities().stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(facilities);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<FacilityResponse> getFacility(
            Authentication authentication,
            @PathVariable Long id) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/facilities/{} - accountId={}", id, accountId);

        GolfFacility facility = courseService.getFacility(id);
        return ResponseEntity.ok(toResponse(facility));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<FacilityResponse> updateFacility(
            Authentication authentication,
            @PathVariable Long id,
            @Valid @RequestBody FacilityUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("PUT /admin/facilities/{} - accountId={}", id, accountId);

        GolfFacility update = new GolfFacility();
        update.setName(request.getName());
        update.setAddress(request.getAddress());
        update.setPhone(request.getPhone());
        update.setWebsite(request.getWebsite());
        update.setLocation(request.getLocation());

        GolfFacility updated = courseService.updateFacility(id, update);
        return ResponseEntity.ok(toResponse(updated));
    }

    /**
     * Not implemented. When it is: delete children explicitly rather than
     * relying on ON DELETE CASCADE. The migrations declare cascades, but the
     * dev database is built by Hibernate rather than Flyway and has none — so
     * cascade behaviour differs between the environment you test in and the
     * one that ships. See CourseAdminController#deleteCourse for the detail.
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<Void> deleteFacility(
            Authentication authentication,
            @PathVariable Long id) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("DELETE /admin/facilities/{} - accountId={}", id, accountId);

        // Delegate to service layer — repository delete is not exposed;
        // reuse update with a soft-delete or throw unsupported
        throw new VspApiException(VspErrorCode.INTERNAL_004, "Delete not implemented for facilities");
    }

    private void requireAdminRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005, "COURSE_ADMIN or SUPER_ADMIN role required");
        }
    }

    private FacilityResponse toResponse(GolfFacility f) {
        FacilityResponse r = new FacilityResponse();
        r.setId(f.getId());
        r.setName(f.getName());
        r.setAddress(f.getAddress());
        r.setPhone(f.getPhone());
        r.setWebsite(f.getWebsite());
        r.setLocation(f.getLocation());
        if (f.getDataQuality() != null) {
            r.setDataQuality(new DataQualityDto(
                    f.getDataQuality().getAccuracyClass() != null
                            ? f.getDataQuality().getAccuracyClass().name() : null,
                    f.getDataQuality().getVerificationStatus() != null
                            ? f.getDataQuality().getVerificationStatus().name() : null
            ));
        }
        r.setCreatedAt(f.getMetadata() != null ? f.getMetadata().getCreatedAt() : null);
        r.setUpdatedAt(f.getMetadata() != null ? f.getMetadata().getUpdatedAt() : null);
        return r;
    }
}
