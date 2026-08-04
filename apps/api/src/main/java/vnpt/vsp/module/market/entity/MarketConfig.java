package vnpt.vsp.module.market.entity;

import jakarta.persistence.*;
import java.util.UUID;

/**
 * Market-specific configuration that overrides Vietnam defaults.
 *
 * Story 12.4 — Slice 1: JPA Entities
 */
@Entity
@Table(name = "market_config")
public class MarketConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "config_id")
    private UUID configId;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "market_id", nullable = false, unique = true)
    private Market market;

    @Column(name = "fork_gps_behavior")
    private Boolean forkGpsBehavior = false;

    @Column(name = "fork_score_behavior")
    private Boolean forkScoreBehavior = false;

    @Column(name = "redistribution_requires_license")
    private Boolean redistributionRequiresLicense;

    // JPA-required no-arg constructor
    protected MarketConfig() {}

    public MarketConfig(Market market) {
        this.market = market;
    }

    // Getters
    public UUID getConfigId() { return configId; }
    public Market getMarket() { return market; }
    public Boolean getForkGpsBehavior() { return forkGpsBehavior; }
    public Boolean getForkScoreBehavior() { return forkScoreBehavior; }
    public Boolean getRedistributionRequiresLicense() { return redistributionRequiresLicense; }

    // Setters
    public void setMarket(Market market) { this.market = market; }
    public void setForkGpsBehavior(Boolean forkGpsBehavior) { this.forkGpsBehavior = forkGpsBehavior; }
    public void setForkScoreBehavior(Boolean forkScoreBehavior) { this.forkScoreBehavior = forkScoreBehavior; }
    public void setRedistributionRequiresLicense(Boolean redistributionRequiresLicense) { this.redistributionRequiresLicense = redistributionRequiresLicense; }
}
