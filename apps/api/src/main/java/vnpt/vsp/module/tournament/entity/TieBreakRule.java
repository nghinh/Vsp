package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import java.util.UUID;

/**
 * TieBreakRule entity — ordered tie-break procedure for a tournament.
 * Per Story 12.1: scorecard playoff, exact handicap, lowest round, most birdies, draw.
 */
@Entity
@Table(name = "tie_break_rules")
public class TieBreakRule {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    @Column(name = "rule_order", nullable = false)
    private int order;

    @Enumerated(EnumType.STRING)
    @Column(name = "rule_type", nullable = false)
    private TieBreakRuleType ruleType;

    public TieBreakRule() {}

    public TieBreakRule(Tournament tournament, int order, TieBreakRuleType ruleType) {
        this.tournament = tournament;
        this.order = order;
        this.ruleType = ruleType;
    }

    // ─── Getters / Setters ───────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public Tournament getTournament() { return tournament; }
    public void setTournament(Tournament tournament) { this.tournament = tournament; }

    public int getOrder() { return order; }
    public void setOrder(int order) { this.order = order; }

    public TieBreakRuleType getRuleType() { return ruleType; }
    public void setRuleType(TieBreakRuleType ruleType) { this.ruleType = ruleType; }
}
