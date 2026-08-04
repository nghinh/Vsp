package vnpt.vsp.module.profile;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.profile.dto.GolferProfileResponse;
import vnpt.vsp.module.profile.dto.UpdateGolferProfileRequest;

/**
 * REST controller for golfer profile endpoints.
 * Per PRD Section 11.2: /profiles/* endpoints required.
 * Per Story 2.3 AC-1: supports all golf preference fields.
 * Per Story 2.3 AC-2: canonical meters storage — unit changes do not corrupt canonical values.
 */
@RestController
@RequestMapping("/profiles")
public class ProfileController {

    private final ProfileService profileService;

    public ProfileController(ProfileService profileService) {
        this.profileService = profileService;
    }

    /**
     * Get the authenticated golfer's profile.
     * Auto-creates a default profile if none exists (lazy creation on first access).
     * Per Story 2.3 AC-1: returns all profile fields.
     * Per Story 2.3 AC-2: returns canonical values (meters) and display-unit preference.
     */
    @GetMapping("/me")
    public ResponseEntity<GolferProfileResponse> getMyProfile(Authentication authentication) {
        Long accountId = (Long) authentication.getPrincipal();
        GolferProfileResponse response = profileService.getProfile(accountId);
        return ResponseEntity.ok(response);
    }

    /**
     * Update the authenticated golfer's profile.
     * Per Story 2.3 AC-1: all golf preference fields are updatable (partial update supported).
     * Per Story 2.3 AC-2: canonical meters values are preserved; only display-unit field changes.
     */
    @PutMapping("/me")
    public ResponseEntity<GolferProfileResponse> updateMyProfile(
            Authentication authentication,
            @Valid @RequestBody UpdateGolferProfileRequest request) {
        Long accountId = (Long) authentication.getPrincipal();
        GolferProfileResponse response = profileService.updateProfile(accountId, request);
        return ResponseEntity.ok(response);
    }
}
