package vnpt.vsp.module.bag;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.bag.dto.*;

import java.net.URI;
import java.util.List;

/**
 * REST controller for golf bag and club endpoints.
 * Per Story 2.4 AC-1: CRUD for bags and clubs with all specified fields.
 * Per Story 2.4 AC-2: setActiveBag() ensures exactly one bag is active.
 * Per Story 2.4 AC-3: hasMinimumClubData() exposed for recommendation enablement.
 */
@RestController
@RequestMapping("/bags")
@vnpt.vsp.module.bag.BagModule
public class BagController {

    private final BagService bagService;

    public BagController(BagService bagService) {
        this.bagService = bagService;
    }

    // ─── Bag endpoints ────────────────────────────────────────────────────────

    /**
     * List all bags for the authenticated golfer.
     * Auto-creates a default bag on first access.
     */
    @GetMapping
    public ResponseEntity<List<GolfBagResponse>> listBags(Authentication authentication) {
        Long accountId = (Long) authentication.getPrincipal();
        List<GolfBagResponse> bags = bagService.getBags(accountId);
        return ResponseEntity.ok(bags);
    }

    /**
     * Create a new golf bag.
     */
    @PostMapping
    public ResponseEntity<GolfBagResponse> createBag(
            Authentication authentication,
            @Valid @RequestBody CreateGolfBagRequest request) {
        Long accountId = (Long) authentication.getPrincipal();
        GolfBagResponse bag = bagService.createBag(accountId, request);
        return ResponseEntity
                .created(URI.create("/bags/" + bag.getId()))
                .body(bag);
    }

    /**
     * Get a specific bag by ID.
     */
    @GetMapping("/{bagId}")
    public ResponseEntity<GolfBagResponse> getBag(
            Authentication authentication,
            @PathVariable Long bagId) {
        Long accountId = (Long) authentication.getPrincipal();
        GolfBagResponse bag = bagService.getBags(accountId).stream()
                .filter(b -> b.getId().equals(bagId))
                .findFirst()
                .orElseThrow(() -> new vnpt.vsp.api.error.VspApiException(vnpt.vsp.api.error.VspErrorCode.BAG_001));
        return ResponseEntity.ok(bag);
    }

    /**
     * Update a bag (partial update).
     */
    @PutMapping("/{bagId}")
    public ResponseEntity<GolfBagResponse> updateBag(
            Authentication authentication,
            @PathVariable Long bagId,
            @Valid @RequestBody UpdateGolfBagRequest request) {
        Long accountId = (Long) authentication.getPrincipal();
        GolfBagResponse bag = bagService.updateBag(accountId, bagId, request);
        return ResponseEntity.ok(bag);
    }

    /**
     * Delete a bag. Fails if it is the last remaining bag.
     */
    @DeleteMapping("/{bagId}")
    public ResponseEntity<Void> deleteBag(
            Authentication authentication,
            @PathVariable Long bagId) {
        Long accountId = (Long) authentication.getPrincipal();
        bagService.deleteBag(accountId, bagId);
        return ResponseEntity.noContent().build();
    }

    /**
     * Set a bag as the active bag (deactivates all others).
     * Per Story 2.4 AC-2: exactly one bag active at a time.
     */
    @PostMapping("/{bagId}/activate")
    public ResponseEntity<GolfBagResponse> activateBag(
            Authentication authentication,
            @PathVariable Long bagId) {
        Long accountId = (Long) authentication.getPrincipal();
        GolfBagResponse bag = bagService.setActiveBag(accountId, bagId);
        return ResponseEntity.ok(bag);
    }

    // ─── Club endpoints ──────────────────────────────────────────────────────

    /**
     * List all clubs in a bag.
     */
    @GetMapping("/{bagId}/clubs")
    public ResponseEntity<List<ClubResponse>> listClubs(
            Authentication authentication,
            @PathVariable Long bagId) {
        Long accountId = (Long) authentication.getPrincipal();
        List<ClubResponse> clubs = bagService.getClubs(accountId, bagId);
        return ResponseEntity.ok(clubs);
    }

    /**
     * Add a club to a bag.
     */
    @PostMapping("/{bagId}/clubs")
    public ResponseEntity<ClubResponse> createClub(
            Authentication authentication,
            @PathVariable Long bagId,
            @Valid @RequestBody CreateClubRequest request) {
        Long accountId = (Long) authentication.getPrincipal();
        ClubResponse club = bagService.createClub(accountId, bagId, request);
        return ResponseEntity
                .created(URI.create("/bags/" + bagId + "/clubs/" + club.getId()))
                .body(club);
    }

    /**
     * Update a club (partial update).
     */
    @PutMapping("/{bagId}/clubs/{clubId}")
    public ResponseEntity<ClubResponse> updateClub(
            Authentication authentication,
            @PathVariable Long bagId,
            @PathVariable Long clubId,
            @Valid @RequestBody UpdateClubRequest request) {
        Long accountId = (Long) authentication.getPrincipal();
        ClubResponse club = bagService.updateClub(accountId, bagId, clubId, request);
        return ResponseEntity.ok(club);
    }

    /**
     * Delete a club.
     */
    @DeleteMapping("/{bagId}/clubs/{clubId}")
    public ResponseEntity<Void> deleteClub(
            Authentication authentication,
            @PathVariable Long bagId,
            @PathVariable Long clubId) {
        Long accountId = (Long) authentication.getPrincipal();
        bagService.deleteClub(accountId, bagId, clubId);
        return ResponseEntity.noContent().build();
    }
}
