package vnpt.vsp.module.profile;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.profile.dto.GolferProfileResponse;
import vnpt.vsp.module.profile.dto.UpdateGolferProfileRequest;
import vnpt.vsp.module.profile.entity.GolferProfile;
import vnpt.vsp.module.profile.repository.GolferProfileRepository;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link ProfileServiceImpl}.
 * Tests: get (auto-create), update, field validation, audit, canonical meters storage.
 * Per Story 2.3 AC-1: all profile fields supported.
 * Per Story 2.3 AC-2: canonical meters — unit changes do not corrupt canonical values.
 */
@ExtendWith(MockitoExtension.class)
class ProfileServiceImplTest {

    @Mock
    private GolferProfileRepository profileRepository;

    @Mock
    private AuditService auditService;

    private ProfileServiceImpl profileService;

    @BeforeEach
    void setUp() {
        profileService = new ProfileServiceImpl(profileRepository, auditService);
    }

    // ─── Get Profile Tests ───────────────────────────────────────────────────────

    @Test
    void getProfile_returnsExistingProfile_whenProfileExists() {
        // Given
        Long accountId = 42L;
        GolferProfile existing = createProfile(accountId, BigDecimal.valueOf(10.5),
                "METERS", "RIGHT", "INTERMEDIATE", 220);
        when(profileRepository.findByGolferAccountId(accountId)).thenReturn(Optional.of(existing));

        // When
        GolferProfileResponse response = profileService.getProfile(accountId);

        // Then
        assertNotNull(response);
        assertEquals(42L, response.getGolferAccountId());
        assertEquals(10.5, response.getHandicap());
        assertEquals("METERS", response.getDistanceUnit());
        assertEquals("RIGHT", response.getDominantHand());
        assertEquals("INTERMEDIATE", response.getSkillLevel());
        assertEquals(220, response.getDriverDistance());
        verify(profileRepository, never()).save(any());
    }

    @Test
    void getProfile_createsDefaultProfile_whenNoProfileExists() {
        // Given
        Long accountId = 99L;
        when(profileRepository.findByGolferAccountId(accountId)).thenReturn(Optional.empty());
        when(profileRepository.save(any(GolferProfile.class))).thenAnswer(invocation -> {
            GolferProfile p = invocation.getArgument(0);
            p.setId(7L);
            p.setCreatedAt(Instant.now());
            p.setUpdatedAt(Instant.now());
            return p;
        });

        // When
        GolferProfileResponse response = profileService.getProfile(accountId);

        // Then
        assertNotNull(response);
        assertEquals(99L, response.getGolferAccountId());
        assertEquals("METERS", response.getDistanceUnit());
        assertEquals("RIGHT", response.getDominantHand());
        assertEquals("INTERMEDIATE", response.getSkillLevel());
        verify(profileRepository).save(any(GolferProfile.class));
    }

    // ─── Update Profile Tests ───────────────────────────────────────────────────

    @Test
    void updateProfile_setsAllFields() {
        // Given
        Long accountId = 1L;
        GolferProfile existing = createProfile(accountId, null, "METERS", "RIGHT", "BEGINNER", null);
        when(profileRepository.findByGolferAccountId(accountId)).thenReturn(Optional.of(existing));
        when(profileRepository.save(any(GolferProfile.class))).thenAnswer(invocation -> {
            GolferProfile p = invocation.getArgument(0);
            p.setUpdatedAt(Instant.now());
            return p;
        });

        UpdateGolferProfileRequest request = new UpdateGolferProfileRequest();
        request.setHandicap(8.5);
        request.setHomeClub("Saigon Golf Club");
        request.setDistanceUnit("YARDS");
        request.setDominantHand("LEFT");
        request.setSkillLevel("ADVANCED");
        request.setTargetScore(85);
        request.setDriverDistance(235); // meters — canonical
        request.setSwingSpeed(105);
        request.setGender("MALE");
        request.setBirthYear(1980);
        request.setCountry("Vietnam");
        request.setImageUrl("https://cdn.vsp.example.com/p/1/avatar.jpg");

        // When
        GolferProfileResponse response = profileService.updateProfile(accountId, request);

        // Then
        assertNotNull(response);
        assertEquals(8.5, response.getHandicap());
        assertEquals("Saigon Golf Club", response.getHomeClub());
        assertEquals("YARDS", response.getDistanceUnit());
        assertEquals("LEFT", response.getDominantHand());
        assertEquals("ADVANCED", response.getSkillLevel());
        assertEquals(85, response.getTargetScore());
        assertEquals(235, response.getDriverDistance()); // AC-2: canonical meters preserved
        assertEquals(105, response.getSwingSpeed());
        assertEquals("MALE", response.getGender());
        assertEquals(1980, response.getBirthYear());
        assertEquals("Vietnam", response.getCountry());
        assertEquals("https://cdn.vsp.example.com/p/1/avatar.jpg", response.getImageUrl());
    }

    @Test
    void updateProfile_partialUpdate_onlyUpdatesProvidedFields() {
        // Given
        Long accountId = 5L;
        GolferProfile existing = createProfile(accountId, BigDecimal.valueOf(15.0),
                "METERS", "RIGHT", "BEGINNER", 200);
        when(profileRepository.findByGolferAccountId(accountId)).thenReturn(Optional.of(existing));
        when(profileRepository.save(any(GolferProfile.class))).thenAnswer(invocation -> {
            GolferProfile p = invocation.getArgument(0);
            p.setUpdatedAt(Instant.now());
            return p;
        });

        // Only update distance unit and skill level — leave handicap and driverDistance unchanged
        UpdateGolferProfileRequest request = new UpdateGolferProfileRequest();
        request.setDistanceUnit("YARDS");
        request.setSkillLevel("PRO");

        // When
        GolferProfileResponse response = profileService.updateProfile(accountId, request);

        // Then
        assertEquals(15.0, response.getHandicap()); // unchanged
        assertEquals(200, response.getDriverDistance()); // unchanged — AC-2
        assertEquals("YARDS", response.getDistanceUnit()); // changed
        assertEquals("PRO", response.getSkillLevel()); // changed
    }

    @Test
    void updateProfile_preservesCanonicalDriverDistance_whenDistanceUnitChanges() {
        // Given
        Long accountId = 7L;
        // Stored canonical: 200 meters
        GolferProfile existing = createProfile(accountId, BigDecimal.valueOf(12.0),
                "METERS", "RIGHT", "INTERMEDIATE", 200);
        when(profileRepository.findByGolferAccountId(accountId)).thenReturn(Optional.of(existing));
        when(profileRepository.save(any(GolferProfile.class))).thenAnswer(invocation -> {
            GolferProfile p = invocation.getArgument(0);
            p.setUpdatedAt(Instant.now());
            return p;
        });

        // Change display unit to YARDS — driverDistance stays 200 (meters, canonical)
        UpdateGolferProfileRequest request = new UpdateGolferProfileRequest();
        request.setDistanceUnit("YARDS");
        // Do NOT send driverDistance — should remain unchanged at 200 meters

        // When
        GolferProfileResponse response = profileService.updateProfile(accountId, request);

        // Then — AC-2: canonical value (200 meters) must NOT be modified by unit change
        assertEquals(200, response.getDriverDistance()); // still 200 meters
        assertEquals("YARDS", response.getDistanceUnit()); // display preference changed
    }

    @Test
    void updateProfile_callsAuditService() {
        // Given
        Long accountId = 10L;
        GolferProfile existing = createProfile(accountId, BigDecimal.valueOf(5.0),
                "METERS", "RIGHT", "PRO", 250);
        when(profileRepository.findByGolferAccountId(accountId)).thenReturn(Optional.of(existing));
        when(profileRepository.save(any(GolferProfile.class))).thenAnswer(invocation -> {
            GolferProfile p = invocation.getArgument(0);
            p.setUpdatedAt(Instant.now());
            return p;
        });

        UpdateGolferProfileRequest request = new UpdateGolferProfileRequest();
        request.setHandicap(4.5);

        // When
        profileService.updateProfile(accountId, request);

        // Then
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.PROFILE_UPDATE),
                eq("GolferProfile"),
                anyString(),
                anyString(),
                anyString(),
                isNull()
        );
    }

    @Test
    void updateProfile_autoCreatesProfile_whenNoneExists() {
        // Given
        Long accountId = 88L;
        when(profileRepository.findByGolferAccountId(accountId)).thenReturn(Optional.empty());
        // Track distinct save results to distinguish auto-create from update
        when(profileRepository.save(any(GolferProfile.class))).thenAnswer(invocation -> {
            GolferProfile p = invocation.getArgument(0);
            if (p.getId() == null) {
                p.setId(3L);
                p.setCreatedAt(Instant.now());
                p.setUpdatedAt(Instant.now());
            } else {
                p.setUpdatedAt(Instant.now());
            }
            return p;
        });

        UpdateGolferProfileRequest request = new UpdateGolferProfileRequest();
        request.setHandicap(18.0);

        // When
        GolferProfileResponse response = profileService.updateProfile(accountId, request);

        // Then — should auto-create first (no handicap), then update (with handicap)
        assertNotNull(response);
        assertEquals(88L, response.getGolferAccountId());
        assertEquals(18.0, response.getHandicap());

        // Verify two saves occurred: first for auto-create, second for update
        verify(profileRepository, times(2)).save(any(GolferProfile.class));
    }

    // ─── Helper ─────────────────────────────────────────────────────────────────

    private GolferProfile createProfile(Long accountId, BigDecimal handicap,
                                        String distanceUnit, String dominantHand,
                                        String skillLevel, Integer driverDistance) {
        GolferProfile p = new GolferProfile();
        p.setId(1L);
        p.setGolferAccountId(accountId);
        p.setHandicap(handicap);
        p.setDistanceUnit(distanceUnit != null ? GolferProfile.DistanceUnit.valueOf(distanceUnit) : null);
        p.setDominantHand(dominantHand != null ? GolferProfile.DominantHand.valueOf(dominantHand) : null);
        p.setSkillLevel(skillLevel != null ? GolferProfile.SkillLevel.valueOf(skillLevel) : null);
        p.setDriverDistance(driverDistance);
        p.setCreatedAt(Instant.parse("2026-08-01T10:00:00Z"));
        p.setUpdatedAt(Instant.parse("2026-08-01T10:00:00Z"));
        return p;
    }
}
