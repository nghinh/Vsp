package vnpt.vsp.module.performance.dto;

import vnpt.vsp.module.performance.entity.ClubPerformance;
import vnpt.vsp.module.performance.entity.ClubPerformanceStats;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

/**
 * API response DTO for bag-level performance (all clubs).
 * Per Story 11.1 Slice 1: batch endpoint returns performance for all clubs in a bag.
 */
@vnpt.vsp.module.performance.PerformanceModule
public class BagPerformanceResponse {

    private Long bagId;
    private List<ClubPerformanceResponse> clubs;

    // ─── Factory Methods ─────────────────────────────────────────────────────

    public static BagPerformanceResponse fromEntities(Long bagId, List<ClubPerformance> entities) {
        BagPerformanceResponse response = new BagPerformanceResponse();
        response.bagId = bagId;
        response.clubs = entities.stream()
                .map(ClubPerformanceResponse::fromEntity)
                .collect(Collectors.toList());
        return response;
    }

    // ─── Getters and Setters ─────────────────────────────────────────────────

    public Long getBagId() { return bagId; }
    public void setBagId(Long bagId) { this.bagId = bagId; }

    public List<ClubPerformanceResponse> getClubs() { return clubs; }
    public void setClubs(List<ClubPerformanceResponse> clubs) { this.clubs = clubs; }
}
