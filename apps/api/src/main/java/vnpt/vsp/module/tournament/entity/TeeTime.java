package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * TeeTime entity — tee time slot for a flight.
 * Per Story 12.1: tee time with course/tee assignment for starting tee management.
 */
@Entity
@Table(name = "tee_times")
public class TeeTime {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    @Column(name = "tee_time", nullable = false)
    private Instant teeTime;

    @Column(name = "course_id", nullable = false)
    private Long courseId;

    @Column(name = "starting_tee_box_id")
    private Long startingTeeBoxId;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "flight_id")
    private Flight flight;

    // ─── Getters / Setters ───────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public Tournament getTournament() { return tournament; }
    public void setTournament(Tournament tournament) { this.tournament = tournament; }

    public Instant getTeeTime() { return teeTime; }
    public void setTeeTime(Instant teeTime) { this.teeTime = teeTime; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Long getStartingTeeBoxId() { return startingTeeBoxId; }
    public void setStartingTeeBoxId(Long startingTeeBoxId) { this.startingTeeBoxId = startingTeeBoxId; }

    public Flight getFlight() { return flight; }
    public void setFlight(Flight flight) { this.flight = flight; }
}
