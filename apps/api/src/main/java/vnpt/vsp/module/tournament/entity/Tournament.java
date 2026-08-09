package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Tournament entity — the main tournament aggregate root.
 * Per Story 12.1 AC: supports required formats, registration/import, flights,
 * tee times, starting tees, score confirmation, tie-break, and result publication.
 *
 * Tournament owns TournamentPolicy; individual rounds inherit it.
 */
@Entity
@Table(name = "tournaments")
public class Tournament {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "name", nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "format", nullable = false)
    private TournamentFormat format;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private TournamentStatus status = TournamentStatus.DRAFT;

    @Column(name = "course_id", nullable = false)
    private Long courseId;

    @Column(name = "start_date", nullable = false)
    private Instant startDate;

    @Column(name = "end_date", nullable = false)
    private Instant endDate;

        /**
     * This outing's rules as JSON — divisions, handicap cap, judging floor,
     * countback windows, daily-CAP scale, technical prizes.
     *
     * Per event, because they change per event: the club's own sheets already
     * disagree about where nhóm A ends, and the previous outing ran a different
     * number of flights. Null until an organiser configures them.
     */
    @Column(name = "outing_rules", columnDefinition = "jsonb")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.JSON)
    private String outingRules;

@Column(name = "tournament_policy_id")
    private UUID tournamentPolicyId;

    @Column(name = "registration_deadline")
    private Instant registrationDeadline;

    @Column(name = "max_players")
    private Integer maxPlayers;

    @Column(name = "description", length = 2000)
    private String description;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "created_by", nullable = false)
    private Long createdBy;

    @Version
    @Column(name = "version", nullable = false)
    private int version = 1;

    @OneToMany(mappedBy = "tournament", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<TournamentPlayer> players = new ArrayList<>();

    @OneToMany(mappedBy = "tournament", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Flight> flights = new ArrayList<>();

    @OneToMany(mappedBy = "tournament", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<TeeTime> teeTimes = new ArrayList<>();

    @OneToMany(mappedBy = "tournament", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<TieBreakRule> tieBreakRules = new ArrayList<>();

    @OneToMany(mappedBy = "tournament", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<TournamentResult> results = new ArrayList<>();

    /**
     * Leaderboard version — incremented on each score update.
     * Mobile clients can detect stale leaderboard by comparing version.
     */
    @Column(name = "leaderboard_version", nullable = false)
    private long leaderboardVersion = 0L;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
    }

    // ─── Status transitions ───────────────────────────────────────────────────

    public boolean canOpenRegistration() {
        return status == TournamentStatus.DRAFT;
    }

    public boolean canStart() {
        return status == TournamentStatus.REGISTRATION_OPEN && !players.isEmpty();
    }

    public boolean canComplete() {
        return status == TournamentStatus.IN_PROGRESS;
    }

    public boolean isModifiable() {
        return status == TournamentStatus.DRAFT || status == TournamentStatus.REGISTRATION_OPEN;
    }

    // ─── Getters / Setters ───────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public TournamentFormat getFormat() { return format; }
    public void setFormat(TournamentFormat format) { this.format = format; }

    public TournamentStatus getStatus() { return status; }
    public void setStatus(TournamentStatus status) { this.status = status; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Instant getStartDate() { return startDate; }
    public void setStartDate(Instant startDate) { this.startDate = startDate; }

    public Instant getEndDate() { return endDate; }
    public void setEndDate(Instant endDate) { this.endDate = endDate; }

    public UUID getTournamentPolicyId() { return tournamentPolicyId; }
    public void setTournamentPolicyId(UUID tournamentPolicyId) { this.tournamentPolicyId = tournamentPolicyId; }

    public Instant getRegistrationDeadline() { return registrationDeadline; }
    public void setRegistrationDeadline(Instant registrationDeadline) { this.registrationDeadline = registrationDeadline; }

    public Integer getMaxPlayers() { return maxPlayers; }
    public void setMaxPlayers(Integer maxPlayers) { this.maxPlayers = maxPlayers; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Instant getCreatedAt() { return createdAt; }
    public Long getCreatedBy() { return createdBy; }
    public void setCreatedBy(Long createdBy) { this.createdBy = createdBy; }

    public int getVersion() { return version; }
    public void setVersion(int version) { this.version = version; }

    public List<TournamentPlayer> getPlayers() { return players; }
    public void setPlayers(List<TournamentPlayer> players) { this.players = players; }

    public List<Flight> getFlights() { return flights; }
    public void setFlights(List<Flight> flights) { this.flights = flights; }

    public List<TeeTime> getTeeTimes() { return teeTimes; }
    public void setTeeTimes(List<TeeTime> teeTimes) { this.teeTimes = teeTimes; }

    public List<TieBreakRule> getTieBreakRules() { return tieBreakRules; }
    public void setTieBreakRules(List<TieBreakRule> tieBreakRules) { this.tieBreakRules = tieBreakRules; }

    public List<TournamentResult> getResults() { return results; }
    public void setResults(List<TournamentResult> results) { this.results = results; }

    public long getLeaderboardVersion() { return leaderboardVersion; }
    public void setLeaderboardVersion(long leaderboardVersion) { this.leaderboardVersion = leaderboardVersion; }

    public void incrementLeaderboardVersion() {
        this.leaderboardVersion++;
    }

    public String getOutingRules() { return outingRules; }
    public void setOutingRules(String outingRules) { this.outingRules = outingRules; }
}
