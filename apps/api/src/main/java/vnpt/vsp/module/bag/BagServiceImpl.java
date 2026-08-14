package vnpt.vsp.module.bag;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.bag.dto.*;
import vnpt.vsp.module.bag.entity.Club;
import vnpt.vsp.module.bag.entity.GolfBag;
import vnpt.vsp.module.bag.repository.ClubRepository;
import vnpt.vsp.module.bag.repository.GolfBagRepository;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.stream.Collectors;

import static net.logstash.logback.marker.Markers.append;

/**
 * Implementation of {@link BagService}.
 * Per Story 2.4 AC-1: CRUD for bags and clubs with all specified fields.
 * Per Story 2.4 AC-2: setActiveBag() deactivates all other bags before activating target.
 * Per Story 2.4 AC-3: hasMinimumClubData() checks for at least one club with carryDistance.
 */
@Service
@vnpt.vsp.module.bag.BagModule
public class BagServiceImpl implements BagService {

    private static final Logger log = LoggerFactory.getLogger(BagServiceImpl.class);

    private final GolfBagRepository bagRepository;
    private final ClubRepository clubRepository;
    private final AuditService auditService;

    public BagServiceImpl(GolfBagRepository bagRepository, ClubRepository clubRepository, AuditService auditService) {
        this.bagRepository = bagRepository;
        this.clubRepository = clubRepository;
        this.auditService = auditService;
    }

    // ─── Bag operations ──────────────────────────────────────────────────────

    @Override
    @Transactional
    public List<GolfBagResponse> getBags(Long golferAccountId) {
        log.debug("Getting bags for golferAccountId={}", golferAccountId);
        List<GolfBag> bags = bagRepository.findByGolferAccountId(golferAccountId);
        if (bags.isEmpty()) {
            // Auto-create default bag on first access
            GolfBag defaultBag = createDefaultBag(golferAccountId);
            return List.of(GolfBagResponse.fromEntity(defaultBag));
        }
        return bags.stream()
                .map(GolfBagResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public GolfBagResponse createBag(Long golferAccountId, CreateGolfBagRequest request) {
        log.debug("Creating bag for golferAccountId={}, name={}", golferAccountId, request.getName());
        GolfBag bag = new GolfBag();
        bag.setGolferAccountId(golferAccountId);
        bag.setName(request.getName().trim());
        bag.setIsActive(false);
        GolfBag saved = bagRepository.save(bag);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.BAG_CREATE,
                "GolfBag",
                String.valueOf(saved.getId()),
                null,
                serializeBagToJson(saved),
                null
        );

        log.info(append("action", "BAG_CREATE"), "Bag created: golferAccountId={}, bagId={}",
                golferAccountId, saved.getId());

        return GolfBagResponse.fromEntity(saved);
    }

    @Override
    @Transactional
    public GolfBagResponse updateBag(Long golferAccountId, Long bagId, UpdateGolfBagRequest request) {
        log.debug("Updating bag golferAccountId={}, bagId={}", golferAccountId, bagId);
        GolfBag bag = bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        String beforeJson = serializeBagToJson(bag);

        if (request.getName() != null) {
            bag.setName(request.getName().trim());
        }
        if (Boolean.TRUE.equals(request.getIsActive())) {
            // Activate this bag (deactivates all others)
            setActiveBagInternal(golferAccountId, bag);
        }

        GolfBag saved = bagRepository.save(bag);

        String afterJson = serializeBagToJson(saved);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.BAG_UPDATE,
                "GolfBag",
                String.valueOf(saved.getId()),
                beforeJson,
                afterJson,
                null
        );

        log.info(append("action", "BAG_UPDATE"), "Bag updated: golferAccountId={}, bagId={}",
                golferAccountId, saved.getId());

        return GolfBagResponse.fromEntity(saved);
    }

    @Override
    @Transactional
    public void deleteBag(Long golferAccountId, Long bagId) {
        log.debug("Deleting bag golferAccountId={}, bagId={}", golferAccountId, bagId);
        GolfBag bag = bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        long totalBags = bagRepository.countByGolferAccountId(golferAccountId);
        if (totalBags <= 1) {
            throw new VspApiException(VspErrorCode.BAG_002);
        }

        String beforeJson = serializeBagToJson(bag);

        bagRepository.delete(bag);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.BAG_DELETE,
                "GolfBag",
                String.valueOf(bagId),
                beforeJson,
                null,
                null
        );

        log.info(append("action", "BAG_DELETE"), "Bag deleted: golferAccountId={}, bagId={}",
                golferAccountId, bagId);
    }

    @Override
    @Transactional
    public GolfBagResponse setActiveBag(Long golferAccountId, Long bagId) {
        log.debug("Setting active bag golferAccountId={}, bagId={}", golferAccountId, bagId);
        GolfBag bag = bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        setActiveBagInternal(golferAccountId, bag);
        GolfBag saved = bagRepository.save(bag);

        log.info(append("action", "BAG_SET_ACTIVE"), "Bag set active: golferAccountId={}, bagId={}",
                golferAccountId, saved.getId());

        return GolfBagResponse.fromEntity(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public GolfBagResponse getActiveBag(Long golferAccountId) {
        log.debug("Getting active bag for golferAccountId={}", golferAccountId);
        GolfBag bag = bagRepository.findByGolferAccountIdAndIsActiveTrue(golferAccountId)
                .orElseGet(() -> {
                    // Auto-create default bag if none exists
                    return createDefaultBag(golferAccountId);
                });
        return GolfBagResponse.fromEntity(bag);
    }

    // ─── Club operations ─────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public List<ClubResponse> getClubs(Long golferAccountId, Long bagId) {
        log.debug("Getting clubs for golferAccountId={}, bagId={}", golferAccountId, bagId);
        // Verify bag ownership
        bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        return clubRepository.findByGolfBagId(bagId).stream()
                .map(ClubResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public ClubResponse createClub(Long golferAccountId, Long bagId, CreateClubRequest request) {
        log.debug("Creating club for golferAccountId={}, bagId={}", golferAccountId, bagId);
        GolfBag bag = bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        Club club = new Club();
        club.setGolfBag(bag);
        applyClubRequest(club, request);

        Club saved = clubRepository.save(club);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.CLUB_CREATE,
                "Club",
                String.valueOf(saved.getId()),
                null,
                serializeClubToJson(saved),
                null
        );

        log.info(append("action", "CLUB_CREATE"), "Club created: golferAccountId={}, bagId={}, clubId={}",
                golferAccountId, bagId, saved.getId());

        return ClubResponse.fromEntity(saved);
    }

    @Override
    @Transactional
    public ClubResponse updateClub(Long golferAccountId, Long bagId, Long clubId, UpdateClubRequest request) {
        log.debug("Updating club golferAccountId={}, bagId={}, clubId={}", golferAccountId, bagId, clubId);
        // Verify bag ownership
        bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        Club club = clubRepository.findByIdAndGolfBagId(clubId, bagId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.CLUB_001));

        String beforeJson = serializeClubToJson(club);

        applyClubUpdate(club, request);

        Club saved = clubRepository.save(club);

        String afterJson = serializeClubToJson(saved);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.CLUB_UPDATE,
                "Club",
                String.valueOf(saved.getId()),
                beforeJson,
                afterJson,
                null
        );

        log.info(append("action", "CLUB_UPDATE"), "Club updated: golferAccountId={}, bagId={}, clubId={}",
                golferAccountId, bagId, saved.getId());

        return ClubResponse.fromEntity(saved);
    }

    @Override
    @Transactional
    public void deleteClub(Long golferAccountId, Long bagId, Long clubId) {
        log.debug("Deleting club golferAccountId={}, bagId={}, clubId={}", golferAccountId, bagId, clubId);
        // Verify bag ownership
        bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        Club club = clubRepository.findByIdAndGolfBagId(clubId, bagId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.CLUB_001));

        String beforeJson = serializeClubToJson(club);

        clubRepository.delete(club);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.CLUB_DELETE,
                "Club",
                String.valueOf(clubId),
                beforeJson,
                null,
                null
        );

        log.info(append("action", "CLUB_DELETE"), "Club deleted: golferAccountId={}, bagId={}, clubId={}",
                golferAccountId, bagId, clubId);
    }

    // ─── AC-3 threshold ─────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public boolean hasMinimumClubData(Long golferAccountId, Long bagId) {
        // Verify bag ownership
        bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        // Threshold: at least one club with non-null carryDistance
        return clubRepository.countByGolfBagIdAndCarryDistanceIsNotNull(bagId) >= 1;
    }

    // ─── Private helpers ────────────────────────────────────────────────────

    /**
     * A new bag, with the standard fourteen already in it.
     *
     * <p>An empty bag produces no club advice at all, and asking a golfer to
     * type fourteen carry distances before the app is any use is a wall most
     * people do not climb. Starting from the standard set and correcting what
     * is wrong is a much shorter path.
     *
     * <p>Every seeded carry is flagged, and the flag is what makes this safe:
     * a 128 m from a table is indistinguishable from a 128 m off a range
     * without it, and the advice built on it would be advice for somebody
     * else's swing with nothing on screen to say so.
     */
    private GolfBag createDefaultBag(Long golferAccountId) {
        log.info("Auto-creating default bag for golferAccountId={}", golferAccountId);
        GolfBag bag = new GolfBag();
        bag.setGolferAccountId(golferAccountId);
        bag.setName("My Bag");
        bag.setIsActive(true);
        GolfBag saved = bagRepository.save(bag);

        for (StandardBag.Standard standard : StandardBag.clubs()) {
            Club club = new Club();
            club.setGolfBag(saved);
            club.setClubType(standard.type());
            club.setLoft(standard.loft());
            // A putter carries nothing, and giving it a distance would put it
            // in the running for an approach shot.
            if (standard.carryMeters() > 0) {
                club.setCarryDistance(standard.carryMeters());
                club.setCarryIsDefault(true);
            }
            clubRepository.save(club);
        }
        log.info("Seeded {} standard clubs into bag {} — all carries flagged as defaults",
                StandardBag.clubs().size(), saved.getId());
        return saved;
    }

    private void setActiveBagInternal(Long golferAccountId, GolfBag targetBag) {
        // Deactivate all other bags for this golfer
        bagRepository.deactivateAllForAccount(golferAccountId);
        // Activate the target bag
        targetBag.setIsActive(true);
    }

    private void applyClubRequest(Club club, CreateClubRequest request) {
        club.setClubType(Club.ClubType.valueOf(request.getClubType()));
        if (request.getLoft() != null) club.setLoft(request.getLoft());
        // A golfer typing a carry makes it theirs, whatever it was before. This
        // is the whole safety of seeding a standard set: the flag survives only
        // as long as nobody has looked at the number.
        if (request.getCarryDistance() != null) {
            club.setCarryDistance(request.getCarryDistance());
            club.setCarryIsDefault(false);
        }
        if (request.getTotalDistance() != null) club.setTotalDistance(request.getTotalDistance());
        if (request.getDispersion() != null) club.setDispersion(request.getDispersion());
        if (request.getShaft() != null) club.setShaft(request.getShaft());
        if (request.getUseDate() != null) {
            try {
                club.setUseDate(LocalDate.parse(request.getUseDate()));
            } catch (DateTimeParseException e) {
                throw new VspApiException(VspErrorCode.VALIDATION_001);
            }
        }
    }

    private void applyClubUpdate(Club club, UpdateClubRequest request) {
        if (request.getClubType() != null) club.setClubType(Club.ClubType.valueOf(request.getClubType()));
        if (request.getLoft() != null) club.setLoft(request.getLoft());
        // A golfer typing a carry makes it theirs, whatever it was before. This
        // is the whole safety of seeding a standard set: the flag survives only
        // as long as nobody has looked at the number.
        if (request.getCarryDistance() != null) {
            club.setCarryDistance(request.getCarryDistance());
            club.setCarryIsDefault(false);
        }
        if (request.getTotalDistance() != null) club.setTotalDistance(request.getTotalDistance());
        if (request.getDispersion() != null) club.setDispersion(request.getDispersion());
        if (request.getShaft() != null) club.setShaft(request.getShaft());
        if (request.getUseDate() != null) {
            try {
                club.setUseDate(LocalDate.parse(request.getUseDate()));
            } catch (DateTimeParseException e) {
                throw new VspApiException(VspErrorCode.VALIDATION_001);
            }
        }
    }

    private String serializeBagToJson(GolfBag bag) {
        return "{\"id\":" + bag.getId() +
                ",\"golferAccountId\":" + bag.getGolferAccountId() +
                ",\"name\":\"" + nullSafe(bag.getName()) + "\"" +
                ",\"isActive\":" + bag.getIsActive() +
                ",\"clubCount\":" + bag.getClubs().size() +
                "}";
    }

    private String serializeClubToJson(Club club) {
        return "{\"id\":" + club.getId() +
                ",\"golfBagId\":" + (club.getGolfBag() != null ? club.getGolfBag().getId() : "null") +
                ",\"clubType\":\"" + (club.getClubType() != null ? club.getClubType().name() : "") + "\"" +
                ",\"carryDistance\":" + club.getCarryDistance() +
                "}";
    }

    private String nullSafe(String value) {
        return value == null ? "" : value.replace("\"", "\\\"");
    }
}
