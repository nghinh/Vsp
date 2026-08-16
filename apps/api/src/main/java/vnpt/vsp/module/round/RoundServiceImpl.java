package vnpt.vsp.module.round;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.CourseService;
import vnpt.vsp.module.course.dto.PageResponse;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;
import vnpt.vsp.module.round.dto.RoundCompleteRequest;
import vnpt.vsp.module.round.dto.RoundCreateRequest;
import vnpt.vsp.module.round.dto.RoundResponse;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.entity.RoundSegment;
import vnpt.vsp.module.round.entity.Score;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.round.repository.RoundSegmentRepository;
import vnpt.vsp.module.round.repository.ScoreRepository;
import vnpt.vsp.module.tournament.TournamentPolicyService;
import vnpt.vsp.module.tournament.TournamentService;
import vnpt.vsp.module.tournament.dto.TournamentPolicyResponse;
import vnpt.vsp.module.tournament.entity.Tournament;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Implementation of RoundService.
 * Per Story 5.1 Slice D: round creation with validation, idempotency, and audit.
 */
@Service
public class RoundServiceImpl implements RoundService {

    private static final Logger log = LoggerFactory.getLogger(RoundServiceImpl.class);

    private final RoundRepository roundRepository;
    private final RoundSegmentRepository roundSegmentRepository;
    private final ScoreRepository scoreRepository;
    private final CourseService courseService;
    private final GolferAccountRepository golferAccountRepository;
    private final AuditService auditService;
    private final TournamentPolicyService tournamentPolicyService;
    private final TournamentService tournamentService;

    public RoundServiceImpl(
            RoundRepository roundRepository,
            RoundSegmentRepository roundSegmentRepository,
            ScoreRepository scoreRepository,
            CourseService courseService,
            GolferAccountRepository golferAccountRepository,
            AuditService auditService,
            TournamentPolicyService tournamentPolicyService,
            TournamentService tournamentService) {
        this.roundRepository = roundRepository;
        this.roundSegmentRepository = roundSegmentRepository;
        this.scoreRepository = scoreRepository;
        this.courseService = courseService;
        this.golferAccountRepository = golferAccountRepository;
        this.auditService = auditService;
        this.tournamentPolicyService = tournamentPolicyService;
        this.tournamentService = tournamentService;
    }

    /**
     * Record which đường the round is played on, in playing order.
     *
     * <p>A club with one eighteen sends nothing here and gets one segment, the
     * course it named — which is what every round in the database already has
     * after the V40 backfill, so scoring behaves identically. A club with
     * đường A, B and C sends the pairing the golfer picked, and that is the
     * only place the pairing is ever written down: the round's own
     * {@code courseId} can hold no more than the first of them.
     */
    private void saveSegments(Round round, List<Long> segmentCourseIds) {
        List<Long> courseIds = (segmentCourseIds == null || segmentCourseIds.isEmpty())
                ? (round.getCourseId() == null ? List.of() : List.of(round.getCourseId()))
                : segmentCourseIds;

        int position = 1;
        for (Long courseId : courseIds) {
            roundSegmentRepository.save(new RoundSegment(round.getId(), position++, courseId));
        }
    }

    @Override
    @Transactional
    public RoundResponse createRound(Long accountId, RoundCreateRequest request) {
        log.info("Creating round for account {} with courseId {}", accountId, request.getCourseId());

        // Validate course exists
        Course course;
        try {
            course = courseService.getCourse(request.getCourseId());
        } catch (Exception e) {
            throw new VspApiException(VspErrorCode.COURSE_001, "courseId");
        }

        List<Long> playerIds = request.getPlayerIds();
        if (playerIds == null || playerIds.isEmpty()) {
            // Default to the creating golfer
            playerIds = List.of(accountId);
        }

        // Validate all player IDs exist
        for (Long playerId : playerIds) {
            if (!golferAccountRepository.existsById(playerId)) {
                throw new VspApiException(VspErrorCode.AUTH_010, "playerIds");
            }
        }

        // Determine start time
        Instant startedAt = request.getStartTime() != null ? request.getStartTime() : Instant.now();

        // Per Story 12.1 Slice F: tournamentId auto-populates tournamentPolicyId from tournament
        UUID tournamentPolicyId = request.getTournamentPolicyId();
        UUID tournamentId = request.getTournamentId();
        Integer tournamentPolicyVersion = null;

        if (tournamentId != null && tournamentPolicyId == null) {
            // Auto-populate tournamentPolicyId from tournament
            Tournament tournament = tournamentService.getTournamentEntity(tournamentId);
            if (tournament != null) {
                tournamentPolicyId = tournament.getTournamentPolicyId();
                log.debug("Auto-assigned tournamentPolicyId {} from tournament {}", tournamentPolicyId, tournamentId);
            }
        }

        // Validate tournamentPolicyId exists if provided
        if (tournamentPolicyId != null) {
            try {
                TournamentPolicyResponse policy = tournamentPolicyService.getPolicy(tournamentPolicyId);
                tournamentPolicyVersion = policy.getVersion();
            } catch (Exception e) {
                throw new VspApiException(VspErrorCode.TOURNAMENT_001, "tournamentPolicyId");
            }
        }

        // Create the round entity
        Round round = new Round();
        round.setCourseId(request.getCourseId());
        round.setGolferAccountId(accountId);
        round.setStatus(Round.RoundStatus.IN_PROGRESS);
        round.setStartedAt(startedAt);
        round.setTournamentPolicyId(tournamentPolicyId);
        round.setTournamentId(tournamentId);
        round.setTournamentPolicyVersion(tournamentPolicyVersion);

        // What kind of round, and whether it counts. An older client sends
        // neither and gets what it always got: a casual round that counts.
        Round.RoundFormat format = parseFormat(request.getFormat(), tournamentId, tournamentPolicyId);
        round.setFormat(format);
        round.setCountsTowardHandicap(request.getCountsTowardHandicap() != null
                ? request.getCountsTowardHandicap()
                : format.countsByDefault());

        Round savedRound = roundRepository.save(round);
        log.debug("Round created with id {} (format {}, counts toward handicap: {})",
                savedRound.getId(), savedRound.getFormat(), savedRound.isCountsTowardHandicap());

        saveSegments(savedRound, request.getSegmentCourseIds());

        // Auto-lock tournament policy when round starts (idempotent — no-op if already locked)
        if (tournamentPolicyId != null) {
            tournamentPolicyService.lockPolicy(tournamentPolicyId, 0L); // 0 = system
            log.debug("Auto-locked tournament policy {} for round {}", tournamentPolicyId, savedRound.getId());
        }

        // Create score records for each player
        List<Score> scores = new ArrayList<>();
        for (Long playerId : playerIds) {
            Score score = new Score();
            score.setRoundId(savedRound.getId());
            score.setGolferAccountId(playerId);
            scores.add(score);
        }
        scoreRepository.saveAll(scores);
        log.debug("Created {} score records for round {}", scores.size(), savedRound.getId());

        // Audit log
        auditService.log(
                AuditAction.ROUND_CREATE,
                "Round",
                savedRound.getId().toString(),
                null,
                toJson(savedRound, course.getName(), playerIds),
                buildMetadata(request, accountId)
        );

        return toResponse(savedRound, course.getName());
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<RoundResponse> listRounds(Long accountId, int page, int size) {
        log.info("Listing rounds for account {} (page={}, size={})", accountId, page, size);

        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100));
        Page<Round> roundPage =
                roundRepository.findByGolferAccountIdAndDeletedAtIsNullOrderByStartedAtDesc(accountId, pageable);

        // Resolve course names once per distinct course to avoid repeated lookups.
        Map<Long, String> courseNames = new HashMap<>();
        List<RoundResponse> content = new ArrayList<>();
        for (Round round : roundPage.getContent()) {
            String courseName = null;
            Long courseId = round.getCourseId();
            if (courseId != null) {
                courseName = courseNames.computeIfAbsent(courseId, this::resolveCourseName);
            }
            content.add(toResponse(round, courseName));
        }

        return new PageResponse<>(content, roundPage.getNumber(), roundPage.getSize(),
                roundPage.getTotalElements(), roundPage.getTotalPages());
    }

    /**
     * What to call a round: the club, then the đường.
     *
     * <p>This returned the course's own name, so a golfer's history read
     * "Đường B, Đường B, Đường A" — six rounds at three clubs, none of them
     * named. Nobody remembers a round by which nine they played; they
     * remember where they were.
     *
     * <p>"Long Biên Golf Course — Đường B" where the đường adds something,
     * and just the club where the course carries the club's own name.
     */
    private String resolveCourseName(Long courseId) {
        try {
            Course course = courseService.getCourse(courseId);
            if (course == null) {
                return null;
            }
            String courseName = course.getName();
            String club = course.getFacility() != null
                    ? course.getFacility().getName() : null;
            if (club == null || club.isBlank()) {
                return courseName;
            }
            if (courseName == null || courseName.isBlank()
                    || courseName.equals(club)
                    || courseName.startsWith(club)) {
                return club;
            }
            return club + " — " + courseName;
        } catch (Exception e) {
            log.debug("Could not resolve course name for courseId {}: {}", courseId, e.getMessage());
            return null;
        }
    }

    @Override
    @Transactional
    public RoundResponse completeRound(Long accountId, UUID roundId, RoundCompleteRequest request) {
        log.info("Completing round {} for account {}", roundId, accountId);

        Round round = roundRepository.findById(roundId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROUND_001, "roundId"));

        // Validate ownership
        if (!round.getGolferAccountId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "roundId");
        }

        // Idempotent: already completed → return as-is
        if (round.getStatus() == Round.RoundStatus.COMPLETED) {
            log.debug("Round {} already completed — returning idempotent success", roundId);
            String courseName = round.getCourseId() != null
                    ? resolveCourseName(round.getCourseId())
                    : null;
            return toResponse(round, courseName);
        }

        // Validate status allows completion
        if (round.getStatus() != Round.RoundStatus.IN_PROGRESS) {
            throw new VspApiException(VspErrorCode.ROUND_005, "roundId");
        }

        // Set completion timestamp and status
        if (round.getEndedAt() == null) {
            round.setEndedAt(Instant.now());
        }
        round.setStatus(Round.RoundStatus.COMPLETED);
        roundRepository.save(round);
        log.debug("Round {} marked COMPLETED", roundId);

        // Audit log
        String courseName = round.getCourseId() != null
                ? resolveCourseName(round.getCourseId())
                : null;
        auditService.log(
                AuditAction.ROUND_COMPLETE,
                "Round",
                roundId.toString(),
                null,
                toJson(round, courseName, null),
                buildCompletionMetadata(accountId)
        );

        return toResponse(round, courseName);
    }

    @Override
    @Transactional
    public RoundResponse abandonRound(Long accountId, UUID roundId) {
        log.info("Abandoning round {} for account {}", roundId, accountId);

        Round round = roundRepository.findById(roundId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROUND_001, "roundId"));

        // Validate ownership
        if (!round.getGolferAccountId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "roundId");
        }

        // Idempotent: already abandoned → return as-is
        if (round.getStatus() == Round.RoundStatus.ABANDONED) {
            log.debug("Round {} already abandoned — returning idempotent success", roundId);
            String courseName = round.getCourseId() != null
                    ? resolveCourseName(round.getCourseId())
                    : null;
            return toResponse(round, courseName);
        }

        // A completed round cannot be abandoned. ROUND_003 ("Round already
        // completed") names what actually happened; ROUND_006 reads "Round
        // cannot be completed in current status", which is about the wrong verb
        // for a client that asked to abandon.
        if (round.getStatus() == Round.RoundStatus.COMPLETED) {
            throw new VspApiException(VspErrorCode.ROUND_003, "roundId");
        }

        if (round.getEndedAt() == null) {
            round.setEndedAt(Instant.now());
        }
        round.setStatus(Round.RoundStatus.ABANDONED);
        roundRepository.save(round);
        log.debug("Round {} marked ABANDONED", roundId);

        String courseName = round.getCourseId() != null
                ? resolveCourseName(round.getCourseId())
                : null;
        auditService.log(
                AuditAction.ROUND_ABANDON,
                "Round",
                roundId.toString(),
                null,
                toJson(round, courseName, null),
                buildCompletionMetadata(accountId)
        );

        return toResponse(round, courseName);
    }

    @Override
    public TournamentPolicyResponse getRoundTournamentPolicy(UUID roundId, Long accountId) {
        log.info("getRoundTournamentPolicy roundId={} accountId={}", roundId, accountId);

        Round round = roundRepository.findById(roundId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ROUND_001, "roundId"));

        if (!round.getGolferAccountId().equals(accountId)) {
            throw new VspApiException(VspErrorCode.AUTH_010, "roundId");
        }

        UUID policyId = round.getTournamentPolicyId();
        if (policyId == null) {
            throw new VspApiException(VspErrorCode.TOURNAMENT_001, "roundId");
        }

        return tournamentPolicyService.getPolicy(policyId);
    }

    // ─── Helpers ───────────────────────────────────────────────────────────

    private RoundResponse toResponse(Round round, String courseName) {
        RoundResponse response = new RoundResponse();
        response.setId(round.getId());
        response.setCourseId(round.getCourseId());
        response.setBackNineCourseId(secondSegmentOf(round));
        response.setCourseName(courseName);
        response.setStatus(round.getStatus());
        response.setStartedAt(round.getStartedAt());
        response.setEndedAt(round.getEndedAt());
        response.setCreatedAt(round.getCreatedAt());
        response.setTournamentPolicyId(round.getTournamentPolicyId());
        response.setTournamentId(round.getTournamentId());
        response.setTournamentPolicyVersion(round.getTournamentPolicyVersion());
        return response;
    }

    /**
     * The second đường of a paired round, or null.
     *
     * Read from the segments rather than from {@code rounds.back_nine_course_id},
     * because the segments are where a pairing is actually written down —
     * saveSegments above says so, and the column is a legacy of the shape that
     * preceded them. Reading the column instead returns null for every round
     * ever created through this service, which is how the app came to believe
     * that a round on Đường A + B had no second nine: correct field name,
     * empty source.
     */
    private Long secondSegmentOf(Round round) {
        if (round.getBackNineCourseId() != null) {
            return round.getBackNineCourseId();
        }
        var segments = roundSegmentRepository
                .findByIdRoundIdOrderByIdPositionAsc(round.getId());
        return segments.size() > 1 ? segments.get(1).getCourseId() : null;
    }

    private String toJson(Round round, String courseName, List<Long> playerIds) {
        return String.format(
                "{\"id\":\"%s\",\"courseName\":\"%s\",\"playerIds\":%s,\"status\":\"%s\",\"startedAt\":\"%s\"}",
                round.getId(), courseName, playerIds, round.getStatus(), round.getStartedAt()
        );
    }

    private String buildMetadata(RoundCreateRequest request, Long accountId) {
        StringBuilder sb = new StringBuilder("{");
        sb.append("\"accountId\":").append(accountId);
        if (request.getPackageId() != null) {
            sb.append(",\"packageId\":\"").append(request.getPackageId()).append("\"");
        }
        if (request.getCartRequested() != null && request.getCartRequested()) {
            sb.append(",\"cartRequested\":true");
        }
        sb.append("}");
        return sb.toString();
    }

    private String buildCompletionMetadata(Long accountId) {
        return "{\"accountId\":" + accountId + "}";
    }

    /**
     * The round's kind, from what the client said and what it asked for.
     *
     * <p>An unrecognised or absent value is casual — the shape every client
     * built before this field sent, and the safest reading of silence. A
     * round attached to a tournament is a tournament round whatever the
     * client called it: the policy is already locked to it.
     */
    private Round.RoundFormat parseFormat(String requested, UUID tournamentId, UUID policyId) {
        if (tournamentId != null || policyId != null) {
            return Round.RoundFormat.TOURNAMENT;
        }
        if (requested == null) {
            return Round.RoundFormat.CASUAL;
        }
        try {
            return Round.RoundFormat.valueOf(requested.trim().toUpperCase(java.util.Locale.ROOT));
        } catch (IllegalArgumentException e) {
            log.warn("Unknown round format '{}' — recording it as CASUAL", requested);
            return Round.RoundFormat.CASUAL;
        }
    }

}
