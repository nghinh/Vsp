package vnpt.vsp.module.tournament;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.tournament.dto.OutingResultsResponse;
import vnpt.vsp.module.tournament.dto.OutingRosterEntryRequest;
import vnpt.vsp.module.tournament.dto.ScoreEntryRequest;
import vnpt.vsp.module.tournament.dto.TechnicalEntryRequest;
import vnpt.vsp.module.tournament.dto.TechnicalEntryResponse;
import vnpt.vsp.module.tournament.dto.TournamentPlayerResponse;
import vnpt.vsp.module.tournament.entity.Flight;
import vnpt.vsp.module.tournament.entity.StartingTee;
import vnpt.vsp.module.tournament.entity.TechnicalEntry;
import vnpt.vsp.module.tournament.entity.Tournament;
import vnpt.vsp.module.tournament.entity.TournamentPlayer;
import vnpt.vsp.module.tournament.entity.TournamentResult;
import vnpt.vsp.module.tournament.repository.FlightRepository;
import vnpt.vsp.module.tournament.repository.TechnicalEntryRepository;
import vnpt.vsp.module.tournament.repository.TournamentPlayerRepository;
import vnpt.vsp.module.tournament.repository.TournamentRepository;
import vnpt.vsp.module.tournament.repository.TournamentResultRepository;
import vnpt.vsp.module.tournament.scoring.OutingRules;
import vnpt.vsp.module.tournament.scoring.OutingScoring;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Running a club outing.
 *
 * The rules themselves live in {@link OutingScoring}; this is the part that
 * reads and writes rows. It is deliberately thin — the arithmetic that decides
 * who gets a trophy is tested without a database, and what is left here is
 * matching a pasted roster to existing players and turning the computed table
 * into records.
 */
@Service
public class OutingServiceImpl implements OutingService {

    private static final Logger log = LoggerFactory.getLogger(OutingServiceImpl.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final TournamentRepository tournamentRepository;
    private final TournamentPlayerRepository playerRepository;
    private final FlightRepository flightRepository;
    private final TechnicalEntryRepository technicalRepository;
    private final TournamentResultRepository resultRepository;
    private final AuditService auditService;

    public OutingServiceImpl(
            TournamentRepository tournamentRepository,
            TournamentPlayerRepository playerRepository,
            FlightRepository flightRepository,
            TechnicalEntryRepository technicalRepository,
            TournamentResultRepository resultRepository,
            AuditService auditService) {
        this.tournamentRepository = tournamentRepository;
        this.playerRepository = playerRepository;
        this.flightRepository = flightRepository;
        this.technicalRepository = technicalRepository;
        this.resultRepository = resultRepository;
        this.auditService = auditService;
    }

    // ─── Rules ──────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public OutingRules getRules(UUID tournamentId) {
        return rulesOf(tournament(tournamentId));
    }

    @Override
    @Transactional
    public OutingRules saveRules(UUID tournamentId, OutingRules rules, Long actorId) {
        Tournament t = tournament(tournamentId);
        // Constructing it validates it — a countback window longer than the
        // round, or a technical prize on a hole the course does not have,
        // fails here rather than at prize-giving.
        OutingRules validated = new OutingRules(
                rules.holePars(), rules.divisions(), rules.handicapCap(), rules.judgingFloor(),
                rules.countbackWindows(), rules.dailyCapBands(), rules.technicalPrizes(),
                rules.onePrizePerPlayer());

        t.setOutingRules(write(validated));
        tournamentRepository.save(t);

        auditService.log(AuditAction.TOURNAMENT_POLICY_CHANGE, "Tournament", tournamentId.toString(),
                null, t.getOutingRules(), metadata(actorId, "outing rules saved"));

        // Divisions may have moved. A player left sitting in a band that no
        // longer exists would vanish from the board without a word.
        replaceDivisions(t, validated);
        return validated;
    }

    private OutingRules rulesOf(Tournament t) {
        if (t.getOutingRules() == null || t.getOutingRules().isBlank()) {
            return OutingRules.vnptItSpringOuting2026();
        }
        try {
            return MAPPER.readValue(t.getOutingRules(), OutingRules.class);
        } catch (Exception e) {
            throw new VspApiException(VspErrorCode.TOURNAMENT_014,
                    "Outing rules for this tournament could not be read: " + e.getMessage());
        }
    }

    private String write(OutingRules rules) {
        try {
            return MAPPER.writeValueAsString(rules);
        } catch (Exception e) {
            throw new VspApiException(VspErrorCode.VALIDATION_001, "rules",
                    Map.of("reason", "rules could not be serialised: " + e.getMessage()));
        }
    }

    /** Re-derive every player's division from the current rules. */
    private void replaceDivisions(Tournament t, OutingRules rules) {
        List<TournamentPlayer> players = playerRepository.findByTournamentId(t.getId());
        for (TournamentPlayer p : players) {
            if (p.getHandicap() == null) continue;
            int playing = rules.playingHandicap(p.getHandicap());
            p.setPlayingHandicap(playing);
            OutingRules.Division d = rules.divisionFor(playing);
            p.setDivisionCode(d == null ? null : d.code());
        }
        playerRepository.saveAll(players);
    }

    // ─── Roster ─────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public List<TournamentPlayerResponse> importRoster(
            UUID tournamentId, List<OutingRosterEntryRequest> entries, Long actorId) {

        Tournament t = tournament(tournamentId);
        OutingRules rules = rulesOf(t);

        List<TournamentPlayer> existing = playerRepository.findByTournamentId(tournamentId);
        // Match on VGA code first, then on name. Re-pasting a corrected sheet
        // is the normal way this is used, and a match that fails silently
        // creates a duplicate player holding none of the scores already typed.
        Map<String, TournamentPlayer> byVga = index(existing, p -> normalise(p.getVgaCode()));
        Map<String, TournamentPlayer> byName = index(existing, p -> normalise(p.getDisplayName()));

        Map<Integer, Flight> flights = flightRepository.findByTournamentId(tournamentId).stream()
                .collect(Collectors.toMap(Flight::getFlightNumber, Function.identity(), (a, b) -> a));

        List<TournamentPlayer> kept = new ArrayList<>();
        for (OutingRosterEntryRequest e : entries) {
            if (e.displayName() == null || e.displayName().isBlank()) {
                throw new VspApiException(VspErrorCode.VALIDATION_001, "displayName",
                        Map.of("reason", "every roster line needs a name"));
            }

            TournamentPlayer p = Optional
                    .ofNullable(byVga.get(normalise(e.vgaCode())))
                    .orElseGet(() -> byName.get(normalise(e.displayName())));
            if (p == null) {
                p = new TournamentPlayer();
                p.setTournament(t);
            }

            p.setDisplayName(e.displayName().trim());
            p.setVgaCode(blankToNull(e.vgaCode()));
            p.setPlayerId(e.playerId());
            p.setHandicap(e.handicap());

            if (e.handicap() != null) {
                int playing = rules.playingHandicap(e.handicap());
                p.setPlayingHandicap(playing);
                // An explicit division on the sheet wins: the organisers place
                // players by hand often enough that overriding them would be
                // wrong, and their sheet is the record of record.
                OutingRules.Division derived = rules.divisionFor(playing);
                p.setDivisionCode(blankToNull(e.divisionCode()) != null
                        ? e.divisionCode().trim().toUpperCase()
                        : (derived == null ? null : derived.code()));
            } else {
                p.setDivisionCode(blankToNull(e.divisionCode()));
            }

            if (e.flightNumber() != null) {
                p.setFlight(flights.computeIfAbsent(e.flightNumber(), n -> {
                    Flight f = new Flight();
                    f.setTournament(t);
                    f.setFlightNumber(n);
                    // A shotgun sends flight n out from hole n, which is what
                    // the club's sheet shows ("Start Hố 1" against FLY 1). An
                    // organiser can move it; leaving it null was not an option,
                    // because starting_tee is NOT NULL and has to come from
                    // somewhere honest.
                    int hole = n <= rules.holeCount() ? n : 1;
                    f.setStartingHole(hole);
                    f.setStartingTee(hole <= rules.holeCount() / 2
                            ? StartingTee.FRONT
                            : StartingTee.BACK);
                    return flightRepository.save(f);
                }));
            }

            kept.add(playerRepository.save(p));
        }

        // Anyone not on the pasted sheet is off the roster. Their scores go
        // with them, which is why this is worth an audit line.
        List<TournamentPlayer> dropped = existing.stream()
                .filter(p -> kept.stream().noneMatch(k -> k.getId().equals(p.getId())))
                .toList();
        if (!dropped.isEmpty()) {
            playerRepository.deleteAll(dropped);
            log.info("Roster import dropped {} player(s) not on the new sheet: tournamentId={}",
                    dropped.size(), tournamentId);
        }

        auditService.log(AuditAction.TOURNAMENT_POLICY_CHANGE, "Tournament", tournamentId.toString(),
                null, "{\"imported\":" + kept.size() + ",\"dropped\":" + dropped.size() + "}",
                metadata(actorId, "outing roster imported"));

        return roster(tournamentId);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TournamentPlayerResponse> roster(UUID tournamentId) {
        tournament(tournamentId);
        return playerRepository.findByTournamentId(tournamentId).stream()
                .sorted(Comparator
                        .comparing((TournamentPlayer p) ->
                                p.getFlight() == null ? Integer.MAX_VALUE : p.getFlight().getFlightNumber())
                        .thenComparing(p -> Objects.toString(p.getDisplayName(), "")))
                .map(TournamentPlayerResponse::fromEntity)
                .toList();
    }

    // ─── Scores ─────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public List<TournamentPlayerResponse> saveScores(
            UUID tournamentId, List<ScoreEntryRequest> entries, Long actorId) {

        Tournament t = tournament(tournamentId);
        OutingRules rules = rulesOf(t);
        Instant now = Instant.now();

        List<TournamentPlayerResponse> saved = new ArrayList<>();
        for (ScoreEntryRequest e : entries) {
            TournamentPlayer p = playerRepository.findById(e.getTournamentPlayerId())
                    .filter(x -> x.getTournament().getId().equals(tournamentId))
                    .orElseThrow(() -> new VspApiException(VspErrorCode.TOURNAMENT_014,
                            "No such player in this tournament: " + e.getTournamentPlayerId()));

            // Only what the client actually sent. Both score screens post to
            // this endpoint and each writes a different subset; applying every
            // field regardless meant one erased the other's work.
            if (e.hasHoleScores() && e.getHoleScores() != null) {
                p.setHoleScores(normaliseHoles(e.getHoleScores(), rules.holeCount()));
            }
            if (e.hasGrossTotal()) p.setGrossTotal(e.getGrossTotal());
            if (e.hasBirdieCount()) p.setBirdieCount(e.getBirdieCount());
            if (e.hasEagleCount()) p.setEagleCount(e.getEagleCount());
            p.setScoresEnteredAt(now);
            p.setScoresEnteredBy(actorId);

            saved.add(TournamentPlayerResponse.fromEntity(playerRepository.save(p)));
        }

        // Bumping the version is what wakes the leaderboard stream, so the
        // club house screen updates as each flight is keyed in.
        t.setLeaderboardVersion(t.getLeaderboardVersion() + 1);
        tournamentRepository.save(t);

        return saved;
    }

    /**
     * Pad or trim to the round's length, and treat null as not-entered.
     *
     * A short array from a client that thinks the course is nine holes would
     * otherwise index out of bounds inside the scoring, at the worst moment.
     */
    private Integer[] normaliseHoles(Integer[] holes, int holeCount) {
        Integer[] out = new Integer[holeCount];
        for (int i = 0; i < holeCount; i++) {
            Integer v = i < holes.length ? holes[i] : null;
            out[i] = (v == null || v < 0) ? 0 : v;
        }
        return out;
    }

    @Override
    @Transactional(readOnly = true)
    public List<TechnicalEntryResponse> technicalEntries(UUID tournamentId) {
        tournament(tournamentId);
        return technicalRepository.findByTournamentId(tournamentId).stream()
                .map(TechnicalEntryResponse::fromEntity)
                .toList();
    }

    @Override
    @Transactional
    public void saveTechnicalEntries(
            UUID tournamentId, List<TechnicalEntryRequest> entries, Long actorId) {

        Tournament t = tournament(tournamentId);
        OutingRules rules = rulesOf(t);

        for (TechnicalEntryRequest e : entries) {
            boolean known = rules.technicalPrizes().stream()
                    .anyMatch(spec -> spec.code().equalsIgnoreCase(e.prizeCode())
                            && spec.holes().contains(e.holeNumber()));
            if (!known) {
                throw new VspApiException(VspErrorCode.VALIDATION_001, "prizeCode",
                        Map.of("reason", e.prizeCode() + " is not played for on hole " + e.holeNumber()));
            }

            TournamentPlayer p = playerRepository.findById(e.tournamentPlayerId())
                    .filter(x -> x.getTournament().getId().equals(tournamentId))
                    .orElseThrow(() -> new VspApiException(VspErrorCode.TOURNAMENT_014,
                            "No such player in this tournament: " + e.tournamentPlayerId()));

            TechnicalEntry entry = technicalRepository
                    .findByTournamentIdAndPrizeCodeAndHoleNumberAndPlayerId(
                            tournamentId, e.prizeCode(), e.holeNumber(), p.getId())
                    .orElseGet(TechnicalEntry::new);

            entry.setTournament(t);
            entry.setPlayer(p);
            entry.setPrizeCode(e.prizeCode().toUpperCase());
            entry.setHoleNumber(e.holeNumber());
            entry.setMeasurement(e.measurement());
            entry.setRecordedBy(actorId);
            technicalRepository.save(entry);
        }
    }

    // ─── Results ────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public OutingResultsResponse results(UUID tournamentId) {
        // The stored publish time, not null: this endpoint recomputes the table
        // from the current scores, but whether a table has already been read
        // out is a fact about the event, and passing null here told the screen
        // "never published" even straight after publishing.
        Instant publishedAt = resultRepository.findByTournamentIdOrderByRank(tournamentId).stream()
                .map(TournamentResult::getPublishedAt)
                .filter(java.util.Objects::nonNull)
                .max(Instant::compareTo)
                .orElse(null);

        return computeResults(tournament(tournamentId), publishedAt);
    }

    @Override
    @Transactional
    public OutingResultsResponse publish(UUID tournamentId, Long actorId) {
        Tournament t = tournament(tournamentId);
        Instant now = Instant.now();
        OutingResultsResponse computed = computeResults(t, now);

        // Replace rather than merge: a republish after a corrected scorecard
        // must not leave the previous ranking's rows behind.
        resultRepository.deleteAll(resultRepository.findByTournamentIdOrderByRank(tournamentId));

        Map<UUID, TournamentPlayer> players = playerRepository.findByTournamentId(tournamentId).stream()
                .collect(Collectors.toMap(TournamentPlayer::getId, Function.identity()));

        List<TournamentResult> rows = new ArrayList<>();
        computed.divisions().forEach((division, entries) -> {
            for (OutingResultsResponse.Entry e : entries) {
                if (e.gross() == null) continue;   // still out; nothing to freeze

                TournamentResult r = new TournamentResult();
                r.setTournament(t);
                r.setTournamentPlayer(players.get(e.tournamentPlayerId()));
                r.setPlayerId(players.get(e.tournamentPlayerId()).getPlayerId());
                r.setDivisionCode(division);
                r.setRank(e.rank());
                r.setPrizeTitle(e.prizeTitle());
                r.setPlayingHandicap(e.playingHandicap());
                r.setScore(e.gross());
                r.setNetScore(e.net());
                r.setJudgingScore(e.judgingScore());
                r.setDailyCapAdjustment(e.dailyCapAdjustment());
                r.setBirdieCount(e.birdies());
                r.setEagleCount(e.eagles());
                r.setTiedUnresolved(e.tiedAndUnresolved());
                r.setPublishedAt(now);
                rows.add(r);
            }
        });
        resultRepository.saveAll(rows);

        auditService.log(AuditAction.TOURNAMENT_POLICY_CHANGE, "Tournament", tournamentId.toString(),
                null, "{\"published\":" + rows.size() + "}", metadata(actorId, "outing results published"));

        log.info("Published outing results: tournamentId={}, rows={}", tournamentId, rows.size());
        return computed;
    }

    private OutingResultsResponse computeResults(Tournament t, Instant publishedAt) {
        OutingRules rules = rulesOf(t);
        OutingScoring scoring = new OutingScoring(rules);

        List<TournamentPlayer> players = playerRepository.findByTournamentId(t.getId());
        Map<String, TournamentPlayer> byRef = players.stream()
                .collect(Collectors.toMap(p -> p.getId().toString(), Function.identity()));

        List<OutingScoring.Card> cards = players.stream()
                .map(p -> new OutingScoring.Card(
                        p.getId().toString(),
                        p.getDisplayName(),
                        p.getDivisionCode(),
                        p.getPlayingHandicap() == null ? 0 : p.getPlayingHandicap(),
                        p.getGrossTotal(),
                        toPrimitive(p.getHoleScores(), rules.holeCount()),
                        p.getBirdieCount(),
                        p.getEagleCount()))
                .toList();

        List<OutingScoring.TechnicalEntry> technical = technicalRepository
                .findByTournamentId(t.getId()).stream()
                .map(e -> new OutingScoring.TechnicalEntry(
                        e.getPlayer().getId().toString(),
                        e.getHoleNumber(),
                        e.getMeasurement().doubleValue()))
                .toList();

        OutingScoring.Results computed = scoring.compute(cards, technical);

        Map<String, List<OutingResultsResponse.Entry>> divisions = new LinkedHashMap<>();
        computed.byDivision().forEach((code, ranked) -> divisions.put(code, ranked.stream()
                .map(r -> {
                    TournamentPlayer p = byRef.get(r.card().playerRef());
                    return new OutingResultsResponse.Entry(
                            p.getId(),
                            p.getDisplayName(),
                            p.getVgaCode(),
                            p.getFlight() == null ? null : p.getFlight().getFlightNumber(),
                            r.card().playingHandicap(),
                            r.gross(), r.net(), r.judgingScore(), r.rank(), r.prizeTitle(),
                            r.countbackAvailable(), r.tiedAndUnresolved(),
                            r.dailyCapAdjustment(), r.birdies(), r.eagles());
                })
                .toList()));

        List<OutingResultsResponse.TechnicalAwardResponse> awards = computed.technicalAwards().stream()
                .map(a -> {
                    TournamentPlayer p = byRef.get(a.playerRef());
                    return new OutingResultsResponse.TechnicalAwardResponse(
                            a.prizeCode(), a.prizeLabel(), a.holeNumber(),
                            p.getId(), p.getDisplayName(), a.measurement(), a.unit());
                })
                .toList();

        // Anyone whose handicap falls outside every configured band. Without
        // this they are simply absent from the board and nobody finds out
        // until they ask why they were not called up.
        List<String> unplaced = players.stream()
                .filter(p -> rules.division(Objects.toString(p.getDivisionCode(), "")) == null)
                .map(p -> p.getDisplayName()
                        + (p.getPlayingHandicap() == null ? " (chưa có HDC)" : " (HDC " + p.getPlayingHandicap() + ")"))
                .toList();

        long entered = players.stream()
                .filter(p -> p.getGrossTotal() != null || anyHole(p.getHoleScores()))
                .count();

        return new OutingResultsResponse(
                t.getId(), Instant.now(), publishedAt,
                players.size(), (int) entered, divisions, awards, unplaced);
    }

    // ─── Helpers ────────────────────────────────────────────────────────────

    private static int[] toPrimitive(Integer[] holes, int holeCount) {
        if (holes == null) return null;
        int[] out = new int[holeCount];
        for (int i = 0; i < holeCount; i++) {
            Integer v = i < holes.length ? holes[i] : null;
            out[i] = v == null ? 0 : v;
        }
        return out;
    }

    private static boolean anyHole(Integer[] holes) {
        if (holes == null) return false;
        for (Integer h : holes) {
            if (h != null && h > 0) return true;
        }
        return false;
    }

    private static Map<String, TournamentPlayer> index(
            List<TournamentPlayer> players, Function<TournamentPlayer, String> key) {
        Map<String, TournamentPlayer> map = new LinkedHashMap<>();
        for (TournamentPlayer p : players) {
            String k = key.apply(p);
            if (k != null) map.putIfAbsent(k, p);
        }
        return map;
    }

    /** Case- and space-insensitive, so "Hồ Trọng Đạt " re-matches itself. */
    private static String normalise(String s) {
        if (s == null) return null;
        String trimmed = s.trim().replaceAll("\\s+", " ");
        return trimmed.isEmpty() ? null : trimmed.toLowerCase();
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private Tournament tournament(UUID id) {
        return tournamentRepository.findById(id)
                .orElseThrow(() -> new VspApiException(VspErrorCode.TOURNAMENT_001));
    }

    private String metadata(Long actorId, String note) {
        return "{\"actorId\":" + actorId + ",\"note\":\"" + note + "\"}";
    }
}
