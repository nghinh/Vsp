package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * TournamentPlayer entity — registered player in a tournament.
 * Per Story 12.1: registered, confirmed, withdrawn, disqualified statuses.
 */
@Entity
@Table(name = "tournament_players")
public class TournamentPlayer {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    @Column(name = "player_id", nullable = false)
    private Long playerId;

    @Column(name = "handicap")
    private Double handicap;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "flight_id")
    private Flight flight;

    @Column(name = "registration_time", nullable = false)
    private Instant registrationTime;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private TournamentPlayerStatus status = TournamentPlayerStatus.REGISTERED;

    @PrePersist
    protected void onCreate() {
        if (registrationTime == null) {
            registrationTime = Instant.now();
        }
    }

    // ─── Getters / Setters ───────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public Tournament getTournament() { return tournament; }
    public void setTournament(Tournament tournament) { this.tournament = tournament; }

    public Long getPlayerId() { return playerId; }
    public void setPlayerId(Long playerId) { this.playerId = playerId; }

    public Double getHandicap() { return handicap; }
    public void setHandicap(Double handicap) { this.handicap = handicap; }

    public Flight getFlight() { return flight; }
    public void setFlight(Flight flight) { this.flight = flight; }

    public Instant getRegistrationTime() { return registrationTime; }
    public void setRegistrationTime(Instant registrationTime) { this.registrationTime = registrationTime; }

    public TournamentPlayerStatus getStatus() { return status; }
    public void setStatus(TournamentPlayerStatus status) { this.status = status; }
}
