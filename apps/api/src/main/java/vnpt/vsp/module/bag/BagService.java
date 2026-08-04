package vnpt.vsp.module.bag;

import vnpt.vsp.module.bag.dto.*;

/**
 * Service interface for golf bag and club management.
 * Per Story 2.4 AC-1: CRUD for bags and clubs with all specified fields.
 * Per Story 2.4 AC-2: exactly one bag active at a time.
 * Per Story 2.4 AC-3: minimum data threshold check for recommendations.
 */
public interface BagService {

    // ─── Bag operations ──────────────────────────────────────────────────────

    /**
     * Get all bags for a golfer.
     * Auto-creates a default bag if none exist (lazy creation on first access).
     */
    java.util.List<GolfBagResponse> getBags(Long golferAccountId);

    /**
     * Create a new golf bag.
     */
    GolfBagResponse createBag(Long golferAccountId, CreateGolfBagRequest request);

    /**
     * Update an existing golf bag.
     */
    GolfBagResponse updateBag(Long golferAccountId, Long bagId, UpdateGolfBagRequest request);

    /**
     * Delete a golf bag. Fails if it is the last bag.
     */
    void deleteBag(Long golferAccountId, Long bagId);

    /**
     * Set a bag as the active bag (deactivates all others for this golfer).
     * Per Story 2.4 AC-2: transactional enforcement that exactly one bag is active.
     */
    GolfBagResponse setActiveBag(Long golferAccountId, Long bagId);

    /**
     * Get the currently active bag for a golfer.
     */
    GolfBagResponse getActiveBag(Long golferAccountId);

    // ─── Club operations ─────────────────────────────────────────────────────

    /**
     * Get all clubs in a bag.
     */
    java.util.List<ClubResponse> getClubs(Long golferAccountId, Long bagId);

    /**
     * Add a club to a bag.
     */
    ClubResponse createClub(Long golferAccountId, Long bagId, CreateClubRequest request);

    /**
     * Update an existing club.
     */
    ClubResponse updateClub(Long golferAccountId, Long bagId, Long clubId, UpdateClubRequest request);

    /**
     * Delete a club.
     */
    void deleteClub(Long golferAccountId, Long bagId, Long clubId);

    // ─── AC-3 threshold ─────────────────────────────────────────────────────

    /**
     * Check if a bag has the minimum data to enable recommendations.
     * Per Story 2.4 AC-3: at least one club with non-null carryDistance.
     */
    boolean hasMinimumClubData(Long golferAccountId, Long bagId);
}
