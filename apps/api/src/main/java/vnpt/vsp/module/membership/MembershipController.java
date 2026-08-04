package vnpt.vsp.module.membership;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for membership endpoints.
 *
 * All endpoints return 405 Not Implemented — this is a stub module.
 * Full implementation is out of scope for Story 12.2.
 */
@RestController
@RequestMapping("/membership")
public class MembershipController {

    private final MembershipService membershipService;

    public MembershipController(MembershipService membershipService) {
        this.membershipService = membershipService;
    }

    /**
     * Get a membership by ID.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/memberships/{membershipId}")
    public ResponseEntity<MembershipService.Membership> getMembership(@PathVariable String membershipId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Get memberships for the current user.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/users/me/memberships")
    public ResponseEntity<List<MembershipService.Membership>> getMyMemberships() {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Get available membership plans.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/plans")
    public ResponseEntity<List<MembershipService.MembershipPlan>> getAvailablePlans() {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Get a membership plan by ID.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/plans/{planId}")
    public ResponseEntity<MembershipService.MembershipPlan> getPlan(@PathVariable String planId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Check entitlement for the current user.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/users/me/entitlements/{entitlement}")
    public ResponseEntity<Boolean> checkEntitlement(
            @PathVariable String entitlement,
            @RequestParam(required = false) String courseId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }
}