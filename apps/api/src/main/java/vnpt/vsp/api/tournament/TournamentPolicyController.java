package vnpt.vsp.api.tournament;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.tournament.TournamentPolicyService;
import vnpt.vsp.module.tournament.dto.TournamentPolicyCreateRequest;
import vnpt.vsp.module.tournament.dto.TournamentPolicyResponse;
import vnpt.vsp.module.tournament.dto.TournamentPolicyUpdateRequest;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * REST controller for tournament policy endpoints.
 *
 * Per PRD §8.12: "Tournament Mode may lock after round start."
 * Per Architecture §14 QG-8: "Basic Tournament Mode restrictions are
 * represented in config and UI."
 *
 * Endpoints:
 * - POST   /tournament-policies           — create policy
 * - GET    /tournament-policies/{id}       — get policy
 * - PATCH  /tournament-policies/{id}        — update policy (locked if no director role)
 * - POST   /tournament-policies/{id}/lock   — lock policy
 * - GET    /tournament-policies/{id}/changes — get change audit trail
 */
@RestController
@RequestMapping("/tournament-policies")
public class TournamentPolicyController {

    private static final Logger log = LoggerFactory.getLogger(TournamentPolicyController.class);

    private final TournamentPolicyService policyService;
    private final RoleService roleService;

    public TournamentPolicyController(TournamentPolicyService policyService, RoleService roleService) {
        this.policyService = policyService;
        this.roleService = roleService;
    }

    /**
     * Create a new tournament policy.
     *
     * @param authentication the authenticated account
     * @param request        the creation request
     * @return 201 with the created policy
     */
    @PostMapping
    public ResponseEntity<TournamentPolicyResponse> createPolicy(
            Authentication authentication,
            @Valid @RequestBody TournamentPolicyCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("POST /tournament-policies - accountId={}, name={}", accountId, request.getName());

        TournamentPolicyResponse response = policyService.createPolicy(request, accountId);

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Get a tournament policy by ID.
     *
     * @param policyId the policy UUID
     * @return 200 with the policy
     */
    @GetMapping("/{policyId}")
    public ResponseEntity<TournamentPolicyResponse> getPolicy(@PathVariable UUID policyId) {
        log.info("GET /tournament-policies/{}", policyId);

        TournamentPolicyResponse response = policyService.getPolicy(policyId);
        return ResponseEntity.ok(response);
    }

    /**
     * Update a tournament policy's feature flags.
     *
     * If the policy is locked and the caller does not have the TournamentDirector role,
     * returns 403 with code TOURNAMENT_002.
     *
     * @param authentication the authenticated account
     * @param policyId      the policy UUID
     * @param request       the update request
     * @return 200 with the updated policy
     */
    @PatchMapping("/{policyId}")
    public ResponseEntity<TournamentPolicyResponse> updatePolicy(
            Authentication authentication,
            @PathVariable UUID policyId,
            @RequestBody TournamentPolicyUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        boolean hasDirectorRole = roleService.hasRole(accountId, RoleName.TOURNAMENT_DIRECTOR);

        log.info("PATCH /tournament-policies/{} - accountId={}, director={}", policyId, accountId, hasDirectorRole);

        TournamentPolicyResponse response = policyService.updatePolicy(
                policyId, request, hasDirectorRole, accountId);

        return ResponseEntity.ok(response);
    }

    /**
     * Lock a tournament policy.
     *
     * Called by the backend when a tournament round starts.
     * Idempotent: locking an already-locked policy returns 200 OK.
     *
     * @param authentication the authenticated account
     * @param policyId      the policy UUID
     * @return 200 OK
     */
    @PostMapping("/{policyId}/lock")
    public ResponseEntity<Void> lockPolicy(
            Authentication authentication,
            @PathVariable UUID policyId) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("POST /tournament-policies/{}/lock - accountId={}", policyId, accountId);

        policyService.lockPolicy(policyId, accountId);

        return ResponseEntity.ok().build();
    }

    /**
     * Get the change audit trail for a policy.
     *
     * @param policyId the policy UUID
     * @return 200 with list of change records (newest first)
     */
    @GetMapping("/{policyId}/changes")
    public ResponseEntity<List<?>> getPolicyChanges(@PathVariable UUID policyId) {
        log.info("GET /tournament-policies/{}/changes", policyId);

        List<?> changes = policyService.getPolicyChanges(policyId);
        return ResponseEntity.ok(changes);
    }
}
