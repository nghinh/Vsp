package vnpt.vsp.module.membership;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * REST controller for membership endpoints.
 *
 * <p>Per Story 12.2. Membership is a customer-operations boundary module with no
 * coupling to the round/score modules. "me" endpoints resolve the current user from
 * the authenticated principal.
 */
@RestController
@RequestMapping("/membership")
public class MembershipController {

    private final MembershipService membershipService;

    public MembershipController(MembershipService membershipService) {
        this.membershipService = membershipService;
    }

    /** Get a membership by ID. */
    @GetMapping("/memberships/{membershipId}")
    public ResponseEntity<MembershipService.Membership> getMembership(@PathVariable String membershipId) {
        return membershipService.getMembership(membershipId)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /** Get memberships for the current user. */
    @GetMapping("/users/me/memberships")
    public ResponseEntity<List<MembershipService.Membership>> getMyMemberships(Authentication authentication) {
        return ResponseEntity.ok(membershipService.getMembershipsForUser(currentUserId(authentication)));
    }

    /** Get available membership plans. */
    @GetMapping("/plans")
    public ResponseEntity<List<MembershipService.MembershipPlan>> getAvailablePlans() {
        return ResponseEntity.ok(membershipService.getAvailablePlans());
    }

    /** Get a membership plan by ID. */
    @GetMapping("/plans/{planId}")
    public ResponseEntity<MembershipService.MembershipPlan> getPlan(@PathVariable String planId) {
        return membershipService.getPlan(planId)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /** Check entitlement for the current user. */
    @GetMapping("/users/me/entitlements/{entitlement}")
    public ResponseEntity<Map<String, Object>> checkEntitlement(
            Authentication authentication,
            @PathVariable String entitlement,
            @RequestParam(required = false) String courseId) {
        boolean granted = membershipService.hasEntitlement(currentUserId(authentication), courseId, entitlement);
        return ResponseEntity.ok(Map.of(
                "entitlement", entitlement,
                "courseId", courseId != null ? courseId : "",
                "granted", granted));
    }

    private String currentUserId(Authentication authentication) {
        return String.valueOf(authentication.getPrincipal());
    }
}
