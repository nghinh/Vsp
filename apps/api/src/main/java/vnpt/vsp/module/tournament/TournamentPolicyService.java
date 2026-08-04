package vnpt.vsp.module.tournament;

import vnpt.vsp.module.tournament.dto.TournamentPolicyCreateRequest;
import vnpt.vsp.module.tournament.dto.TournamentPolicyResponse;
import vnpt.vsp.module.tournament.dto.TournamentPolicyUpdateRequest;

import java.util.List;
import java.util.UUID;

/**
 * Public service interface for TournamentPolicy operations.
 *
 * Per PRD §8.12: "Tournament Mode may lock after round start."
 */
public interface TournamentPolicyService {

    /**
     * Creates a new tournament policy.
     *
     * @param request the creation request
     * @param createdBy the account ID of the actor creating the policy
     * @return the created policy response
     */
    TournamentPolicyResponse createPolicy(TournamentPolicyCreateRequest request, Long createdBy);

    /**
     * Returns a policy by ID.
     *
     * @param policyId the policy UUID
     * @return the policy response
     * @throws vnpt.vsp.api.error.VspApiException with code TOURNAMENT_001 if not found
     */
    TournamentPolicyResponse getPolicy(UUID policyId);

    /**
     * Updates a tournament policy's feature flags.
     *
     * @param policyId the policy UUID
     * @param request the update request
     * @param actorHasDirectorRole whether the caller has TournamentDirector role
     * @param changedBy the account ID of the actor making the change
     * @return the updated policy response
     * @throws vnpt.vsp.api.error.VspApiException with code TOURNAMENT_002 if locked and caller lacks director role
     */
    TournamentPolicyResponse updatePolicy(UUID policyId, TournamentPolicyUpdateRequest request, boolean actorHasDirectorRole, Long changedBy);

    /**
     * Locks a tournament policy (called when a tournament round starts).
     *
     * @param policyId the policy UUID
     * @param lockedBy the account ID of the actor (typically 'system')
     * @throws vnpt.vsp.api.error.VspApiException with code TOURNAMENT_001 if policy not found
     */
    void lockPolicy(UUID policyId, Long lockedBy);

    /**
     * Returns the change history for a policy.
     *
     * @param policyId the policy UUID
     * @return list of policy change records (newest first)
     */
    List<?> getPolicyChanges(UUID policyId);

    /**
     * Checks if a feature is enabled for a given policy.
     *
     * @param policyId the policy UUID (nullable)
     * @param flagName the feature flag name (e.g. "windAdjustmentEnabled")
     * @return true if enabled or policy is null; false if explicitly disabled
     */
    boolean isFeatureEnabled(UUID policyId, String flagName);
}
