package vnpt.vsp.module.profile;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.profile.dto.GolferProfileResponse;
import vnpt.vsp.module.profile.dto.UpdateGolferProfileRequest;
import vnpt.vsp.module.profile.entity.GolferProfile;
import vnpt.vsp.module.profile.repository.GolferProfileRepository;

import java.math.BigDecimal;

import static net.logstash.logback.marker.Markers.append;

/**
 * Implementation of {@link ProfileService}.
 * Per Story 2.3 AC-1: returns all profile fields.
 * Per Story 2.3 AC-2: canonical meters values are stored; unit field is display preference only.
 */
@Service
public class ProfileServiceImpl implements ProfileService {

    private static final Logger log = LoggerFactory.getLogger(ProfileServiceImpl.class);

    private final GolferProfileRepository profileRepository;
    private final AuditService auditService;

    public ProfileServiceImpl(GolferProfileRepository profileRepository, AuditService auditService) {
        this.profileRepository = profileRepository;
        this.auditService = auditService;
    }

    @Override
    @Transactional
    public GolferProfileResponse getProfile(Long golferAccountId) {
        log.debug("Getting profile for golferAccountId={}", golferAccountId);
        GolferProfile profile = profileRepository.findByGolferAccountId(golferAccountId)
                .orElseGet(() -> createDefaultProfile(golferAccountId));
        return GolferProfileResponse.fromEntity(profile);
    }

    @Override
    @Transactional
    public GolferProfileResponse updateProfile(Long golferAccountId, UpdateGolferProfileRequest request) {
        log.debug("Updating profile for golferAccountId={}", golferAccountId);

        GolferProfile profile = profileRepository.findByGolferAccountId(golferAccountId)
                .orElseGet(() -> createDefaultProfile(golferAccountId));

        String beforeJson = serializeToJson(profile);

        applyUpdates(profile, request);

        GolferProfile saved = profileRepository.save(profile);

        String afterJson = serializeToJson(saved);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.PROFILE_UPDATE,
                "GolferProfile",
                String.valueOf(saved.getId()),
                beforeJson,
                afterJson,
                null
        );

        log.info(append("action", "PROFILE_UPDATE"), "Golfer profile updated: golferAccountId={}, profileId={}",
                golferAccountId, saved.getId());

        return GolferProfileResponse.fromEntity(saved);
    }

    /**
     * Creates a default profile with sensible defaults:
     * unit=METERS, hand=RIGHT, skill=INTERMEDIATE.
     * Per Story 2.3 plan: lazy creation on first access.
     */
    private GolferProfile createDefaultProfile(Long golferAccountId) {
        log.info("Auto-creating default profile for golferAccountId={}", golferAccountId);
        GolferProfile profile = new GolferProfile();
        profile.setGolferAccountId(golferAccountId);
        profile.setDistanceUnit(GolferProfile.DistanceUnit.METERS);
        profile.setDominantHand(GolferProfile.DominantHand.RIGHT);
        profile.setSkillLevel(GolferProfile.SkillLevel.INTERMEDIATE);
        return profileRepository.save(profile);
    }

    private void applyUpdates(GolferProfile profile, UpdateGolferProfileRequest request) {
        if (request.getHandicap() != null) {
            profile.setHandicap(BigDecimal.valueOf(request.getHandicap()));
        }
        if (request.getHomeClub() != null) {
            profile.setHomeClub(request.getHomeClub());
        }
        if (request.getDistanceUnit() != null) {
            profile.setDistanceUnit(GolferProfile.DistanceUnit.valueOf(request.getDistanceUnit()));
        }
        if (request.getDominantHand() != null) {
            profile.setDominantHand(GolferProfile.DominantHand.valueOf(request.getDominantHand()));
        }
        if (request.getSkillLevel() != null) {
            profile.setSkillLevel(GolferProfile.SkillLevel.valueOf(request.getSkillLevel()));
        }
        if (request.getTargetScore() != null) {
            profile.setTargetScore(request.getTargetScore());
        }
        if (request.getDriverDistance() != null) {
            profile.setDriverDistance(request.getDriverDistance());
        }
        if (request.getSwingSpeed() != null) {
            profile.setSwingSpeed(request.getSwingSpeed());
        }
        if (request.getGender() != null) {
            profile.setGender(request.getGender() != null ? GolferProfile.Gender.valueOf(request.getGender()) : null);
        }
        if (request.getBirthYear() != null) {
            profile.setBirthYear(request.getBirthYear());
        }
        if (request.getCountry() != null) {
            profile.setCountry(request.getCountry());
        }
        if (request.getImageUrl() != null) {
            profile.setImageUrl(request.getImageUrl());
        }
    }

    private String serializeToJson(GolferProfile profile) {
        // Uses the same format as GolferProfileResponse for audit consistency
        return "{\"id\":" + profile.getId() +
                ",\"golferAccountId\":" + profile.getGolferAccountId() +
                ",\"handicap\":" + profile.getHandicap() +
                ",\"homeClub\":\"" + nullSafe(profile.getHomeClub()) + "\"" +
                ",\"distanceUnit\":\"" + (profile.getDistanceUnit() != null ? profile.getDistanceUnit().name() : "") + "\"" +
                ",\"dominantHand\":\"" + (profile.getDominantHand() != null ? profile.getDominantHand().name() : "") + "\"" +
                ",\"skillLevel\":\"" + (profile.getSkillLevel() != null ? profile.getSkillLevel().name() : "") + "\"" +
                ",\"targetScore\":" + profile.getTargetScore() +
                ",\"driverDistance\":" + profile.getDriverDistance() +
                ",\"swingSpeed\":" + profile.getSwingSpeed() +
                "}";
    }

    private String nullSafe(String value) {
        return value == null ? "" : value.replace("\"", "\\\"");
    }
}
