package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Flight entity — group of players assigned to a tee time.
 * Per Story 12.1: groups of 2-4 players with starting tee management.
 */
@Entity
@Table(name = "flights")
public class Flight {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    @Column(name = "flight_number", nullable = false)
    private int flightNumber;

    @OneToMany(mappedBy = "flight", cascade = CascadeType.ALL)
    private List<TournamentPlayer> players = new ArrayList<>();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tee_time_id")
    private TeeTime teeTime;

    @Enumerated(EnumType.STRING)
    @Column(name = "starting_tee", nullable = false)
    private StartingTee startingTee;

    /**
     * The hole this flight tees off from in a shotgun start.
     *
     * The club's outings are shotguns — eleven flights away at 06h30 from
     * eleven tees — and {@link StartingTee}'s FRONT/BACK cannot say which. Null
     * for a conventional two-wave start, where the tee is the whole answer.
     */
    @Column(name = "starting_hole")
    private Integer startingHole;

    /**
     * Score confirmation fields — set when tournament director confirms flight scores.
     */
    @Column(name = "confirmed_at")
    private Instant confirmedAt;

    @Column(name = "confirmed_by")
    private Long confirmedBy;

    // ─── Getters / Setters ───────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public Tournament getTournament() { return tournament; }
    public void setTournament(Tournament tournament) { this.tournament = tournament; }

    public int getFlightNumber() { return flightNumber; }
    public void setFlightNumber(int flightNumber) { this.flightNumber = flightNumber; }

    public List<TournamentPlayer> getPlayers() { return players; }
    public void setPlayers(List<TournamentPlayer> players) { this.players = players; }

    public TeeTime getTeeTime() { return teeTime; }
    public void setTeeTime(TeeTime teeTime) { this.teeTime = teeTime; }

    public StartingTee getStartingTee() { return startingTee; }
    public void setStartingTee(StartingTee startingTee) { this.startingTee = startingTee; }

    public Instant getConfirmedAt() { return confirmedAt; }
    public void setConfirmedAt(Instant confirmedAt) { this.confirmedAt = confirmedAt; }

    public Long getConfirmedBy() { return confirmedBy; }
    public void setConfirmedBy(Long confirmedBy) { this.confirmedBy = confirmedBy; }

    public boolean isConfirmed() {
        return confirmedAt != null;
    }

    public Integer getStartingHole() { return startingHole; }
    public void setStartingHole(Integer startingHole) { this.startingHole = startingHole; }
}
