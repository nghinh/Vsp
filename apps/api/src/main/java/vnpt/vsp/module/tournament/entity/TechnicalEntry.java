package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * A nearest-to-pin or longest-drive measurement.
 *
 * "BTC sẽ có bảng ghi thành tích trên sân. TẤT CẢ CÁC FLY GHI THÀNH TÍCH VÀO
 * BẢNG THÀNH TÍCH ĐỂ BTC XÉT GIẢI" — players write these on a board by the tee
 * as they pass, so they arrive separately from the scorecards and usually
 * earlier. Which of them wins a prize is decided at the end, by the scoring
 * rules, not here: this table only records what was measured.
 */
@Entity
@Table(name = "tournament_technical_entries")
public class TechnicalEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "player_id", nullable = false)
    private TournamentPlayer player;

    /** Which technical prize, matching a code in the outing's rules. */
    @Column(name = "prize_code", nullable = false, length = 16)
    private String prizeCode;

    @Column(name = "hole_number", nullable = false)
    private Integer holeNumber;

    /**
     * The measured value, in the prize's own unit.
     *
     * Metres for a longest drive; for nearest-to-pin the rules allow "đo bằng
     * thước của sân ... trường hợp không có thước thì đo bằng gậy putter", so
     * the unit is whatever the rules say it is and comparisons only ever happen
     * within one hole.
     */
    @Column(name = "measurement", nullable = false, precision = 8, scale = 2)
    private BigDecimal measurement;

    @Column(name = "recorded_at", nullable = false)
    private Instant recordedAt;

    @Column(name = "recorded_by")
    private Long recordedBy;

    @PrePersist
    protected void onCreate() {
        if (recordedAt == null) recordedAt = Instant.now();
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public Tournament getTournament() { return tournament; }
    public void setTournament(Tournament tournament) { this.tournament = tournament; }

    public TournamentPlayer getPlayer() { return player; }
    public void setPlayer(TournamentPlayer player) { this.player = player; }

    public String getPrizeCode() { return prizeCode; }
    public void setPrizeCode(String prizeCode) { this.prizeCode = prizeCode; }

    public Integer getHoleNumber() { return holeNumber; }
    public void setHoleNumber(Integer holeNumber) { this.holeNumber = holeNumber; }

    public BigDecimal getMeasurement() { return measurement; }
    public void setMeasurement(BigDecimal measurement) { this.measurement = measurement; }

    public Instant getRecordedAt() { return recordedAt; }
    public void setRecordedAt(Instant recordedAt) { this.recordedAt = recordedAt; }

    public Long getRecordedBy() { return recordedBy; }
    public void setRecordedBy(Long recordedBy) { this.recordedBy = recordedBy; }
}
