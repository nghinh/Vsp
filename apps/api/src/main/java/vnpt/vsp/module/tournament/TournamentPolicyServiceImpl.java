package vnpt.vsp.module.tournament;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.tournament.dto.TournamentPolicyCreateRequest;
import vnpt.vsp.module.tournament.dto.TournamentPolicyResponse;
import vnpt.vsp.module.tournament.dto.TournamentPolicyUpdateRequest;
import vnpt.vsp.module.tournament.entity.TournamentPolicy;
import vnpt.vsp.module.tournament.entity.TournamentPolicyChange;
import vnpt.vsp.module.tournament.repository.TournamentPolicyChangeRepository;
import vnpt.vsp.module.tournament.repository.TournamentPolicyRepository;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Implementation of TournamentPolicyService.
 *
 * Per PRD §8.12: "Tournament Mode may lock after round start."
 */
@Service
public class TournamentPolicyServiceImpl implements TournamentPolicyService {

    private static final Logger log = LoggerFactory.getLogger(TournamentPolicyServiceImpl.class);

    private final TournamentPolicyRepository policyRepository;
    private final TournamentPolicyChangeRepository changeRepository;
    private final AuditService auditService;
    private final RoundRepository roundRepository;

    public TournamentPolicyServiceImpl(
            TournamentPolicyRepository policyRepository,
            TournamentPolicyChangeRepository changeRepository,
            AuditService auditService,
            RoundRepository roundRepository) {
        this.policyRepository = policyRepository;
        this.changeRepository = changeRepository;
        this.auditService = auditService;
        this.roundRepository = roundRepository;
    }

    @Override
    @Transactional
    public TournamentPolicyResponse createPolicy(TournamentPolicyCreateRequest request, Long createdBy) {
        log.info("Creating tournament policy '{}' for account {}", request.getName(), createdBy);

        TournamentPolicy policy = new TournamentPolicy();
        policy.setName(request.getName());
        policy.setCreatedBy(createdBy);

        if (request.getWindAdjustmentEnabled() != null) policy.setWindAdjustment(request.getWindAdjustmentEnabled());
        if (request.getPlaysLikeEnabled() != null) policy.setPlaysLike(request.getPlaysLikeEnabled());
        if (request.getElevationEnabled() != null) policy.setElevation(request.getElevationEnabled());
        if (request.getClubRecommendationEnabled() != null) policy.setClubRecommendation(request.getClubRecommendationEnabled());
        if (request.getContoursEnabled() != null) policy.setContours(request.getContoursEnabled());
        if (request.getPuttingHelpEnabled() != null) policy.setPuttingHelp(request.getPuttingHelpEnabled());
        if (request.getAiFeaturesEnabled() != null) policy.setAiFeatures(request.getAiFeaturesEnabled());

        TournamentPolicy saved = policyRepository.save(policy);

        // Emit creation audit record (no beforeJson)
        emitAuditChange(saved.getId(), createdBy, null, toMap(saved), "Policy created");

        log.debug("Created tournament policy with id {}", saved.getId());
        return TournamentPolicyResponse.fromEntity(saved);
    }

    @Override
    public TournamentPolicyResponse getPolicy(UUID policyId) {
        TournamentPolicy policy = policyRepository.findById(policyId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.TOURNAMENT_001, "policyId"));
        return TournamentPolicyResponse.fromEntity(policy);
    }

    @Override
    @Transactional
    public TournamentPolicyResponse updatePolicy(
            UUID policyId,
            TournamentPolicyUpdateRequest request,
            boolean actorHasDirectorRole,
            Long changedBy) {

        TournamentPolicy policy = policyRepository.findById(policyId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.TOURNAMENT_001, "policyId"));

        // Check lock status
        if (policy.isLocked() && !actorHasDirectorRole) {
            throw new VspApiException(
                    VspErrorCode.TOURNAMENT_002,
                    "Policy is locked and cannot be modified without Tournament Director role"
            );
        }

        // Capture before state
        Map<String, Object> beforeMap = toMap(policy);

        // Apply feature flag changes
        Map<String, Boolean> changes = request.getFeatureChanges();
        for (Map.Entry<String, Boolean> entry : changes.entrySet()) {
            String flag = entry.getKey();
            boolean value = entry.getValue();
            // Use the entity's setter
            switch (flag) {
                case "windAdjustmentEnabled" -> policy.setWindAdjustment(value);
                case "playsLikeEnabled" -> policy.setPlaysLike(value);
                case "elevationEnabled" -> policy.setElevation(value);
                case "clubRecommendationEnabled" -> policy.setClubRecommendation(value);
                case "contoursEnabled" -> policy.setContours(value);
                case "puttingHelpEnabled" -> policy.setPuttingHelp(value);
                case "aiFeaturesEnabled" -> policy.setAiFeatures(value);
            }
        }

        if (request.getName() != null) {
            policy.setName(request.getName());
        }

        TournamentPolicy saved = policyRepository.save(policy);

        // Emit audit record
        String reason = request.getReason() != null ? request.getReason() : "Policy updated";
        emitAuditChange(saved.getId(), changedBy, beforeMap, toMap(saved), reason);

        // Per Story 12.1 Slice F: propagate version bump to all active tournament rounds
        propagateVersionBumpToRounds(saved.getId(), saved.getVersion());

        log.debug("Updated tournament policy {}", saved.getId());
        return TournamentPolicyResponse.fromEntity(saved);
    }

    @Override
    @Transactional
    public void lockPolicy(UUID policyId, Long lockedBy) {
        TournamentPolicy policy = policyRepository.findById(policyId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.TOURNAMENT_001, "policyId"));

        // Idempotent — no-op if already locked
        if (policy.isLocked()) {
            log.debug("Policy {} already locked — no-op", policyId);
            return;
        }

        Map<String, Object> beforeMap = toMap(policy);

        policy.lock();
        TournamentPolicy saved = policyRepository.save(policy);

        // Emit lock audit record
        emitAuditChange(saved.getId(), lockedBy, beforeMap, toMap(saved), "Round started — policy locked");

        log.info("Tournament policy {} locked", saved.getId());
    }

    @Override
    public List<?> getPolicyChanges(UUID policyId) {
        return changeRepository.findByPolicyIdOrderByChangedAtDesc(policyId);
    }

    @Override
    public boolean isFeatureEnabled(UUID policyId, String flagName) {
        if (policyId == null) return true; // No policy = no restrictions
        return policyRepository.findById(policyId)
                .map(p -> p.isFeatureEnabled(flagName))
                .orElse(true); // Policy not found = fail open
    }

    // ─── Policy Propagation ─────────────────────────────────────────────────

    /**
     * Propagates a tournament policy version bump to all active tournament rounds
     * that are using this policy.
     * Per Story 12.1 Slice F: when tournament policy is updated, all active
     * tournament rounds using this policy get their tournamentPolicyVersion updated
     * so mobile clients can detect the change and prompt the user to sync.
     */
    private void propagateVersionBumpToRounds(UUID policyId, int newVersion) {
        List<Round> activeRounds = roundRepository
                .findByTournamentPolicyIdAndStatusAndDeletedAtIsNull(policyId, Round.RoundStatus.IN_PROGRESS);

        if (activeRounds.isEmpty()) {
            log.debug("No active tournament rounds to propagate policy version bump for policy {}", policyId);
            return;
        }

        for (Round round : activeRounds) {
            round.setTournamentPolicyVersion(newVersion);
        }
        roundRepository.saveAll(activeRounds);

        log.info("Propagated tournament policy version bump (v{}) to {} active round(s) for policy {}",
                newVersion, activeRounds.size(), policyId);
    }

    // ─── Helpers ───────────────────────────────────────────────────────────

    private void emitAuditChange(UUID policyId, Long changedBy, Map<String, Object> beforeJson, Map<String, Object> afterJson, String reason) {
        TournamentPolicyChange change = new TournamentPolicyChange();
        change.setPolicyId(policyId);
        change.setChangedBy(changedBy);
        change.setBeforeJson(beforeJson);
        change.setAfterJson(afterJson);
        change.setReason(reason);
        changeRepository.save(change);

        auditService.log(
                AuditAction.TOURNAMENT_POLICY_CHANGE,
                "TournamentPolicy",
                policyId.toString(),
                beforeJson != null ? toJson(beforeJson) : null,
                toJson(afterJson),
                reason != null ? "{\"reason\":\"" + reason + "\"}" : "{}"
        );
    }

    private Map<String, Object> toMap(TournamentPolicy p) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", p.getId());
        map.put("name", p.getName());
        map.put("windAdjustmentEnabled", p.isWindAdjustment());
        map.put("playsLikeEnabled", p.isPlaysLike());
        map.put("elevationEnabled", p.isElevation());
        map.put("clubRecommendationEnabled", p.isClubRecommendation());
        map.put("contoursEnabled", p.isContours());
        map.put("puttingHelpEnabled", p.isPuttingHelp());
        map.put("aiFeaturesEnabled", p.isAiFeatures());
        map.put("isLocked", p.isLocked());
        map.put("createdAt", p.getCreatedAt() != null ? p.getCreatedAt().toString() : null);
        map.put("createdBy", p.getCreatedBy());
        map.put("version", p.getVersion());
        return map;
    }

    private String toJson(Map<String, Object> map) {
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> e : map.entrySet()) {
            if (!first) sb.append(",");
            first = false;
            sb.append("\"").append(e.getKey()).append("\":");
            Object v = e.getValue();
            if (v == null) {
                sb.append("null");
            } else if (v instanceof Boolean || v instanceof Number) {
                sb.append(v);
            } else {
                sb.append("\"").append(v.toString().replace("\"", "\\\"")).append("\"");
            }
        }
        sb.append("}");
        return sb.toString();
    }
}
