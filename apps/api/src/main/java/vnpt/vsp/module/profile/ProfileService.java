package vnpt.vsp.module.profile;

import vnpt.vsp.module.profile.dto.GolferProfileResponse;
import vnpt.vsp.module.profile.dto.UpdateGolferProfileRequest;

/**
 * Profile module public service interface.
 * Exposes golfer profile and preference operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 */
public interface ProfileService {

    /**
     * Get the authenticated golfer's profile, auto-creating a default profile if none exists.
     * Per Story 2.3 AC-1: returns all profile fields.
     * Per Story 2.3 AC-2: returns canonical values (stored in meters) and display-unit preference.
     *
     * @param golferAccountId the authenticated golfer's account ID (from security principal)
     * @return the golfer's profile
     */
    GolferProfileResponse getProfile(Long golferAccountId);

    /**
     * Update the authenticated golfer's profile.
     * Per Story 2.3 AC-1: all golf preference fields are updatable.
     * Per Story 2.3 AC-2: canonical meters values are preserved; only display-unit preference changes.
     *
     * @param golferAccountId the authenticated golfer's account ID (from security principal)
     * @param request         the update request with fields to change
     * @return the updated profile
     */
    GolferProfileResponse updateProfile(Long golferAccountId, UpdateGolferProfileRequest request);
}
