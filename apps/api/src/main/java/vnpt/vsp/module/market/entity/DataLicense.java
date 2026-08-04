package vnpt.vsp.module.market.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Data license record tracking redistribution permissions per market.
 *
 * Story 12.4 — Slice 1: JPA Entities
 */
@Entity(name = "MarketDataLicense")
@Table(name = "data_license")
public class DataLicense {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "license_id")
    private UUID licenseId;

    @Column(nullable = false)
    private String name;

    @Column(name = "spdx_id", length = 50)
    private String spdxId;

    @Column(name = "licensee")
    private String licensee;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
        name = "data_license_redistribution_market",
        joinColumns = @JoinColumn(name = "license_id")
    )
    @Column(name = "market_code", length = 2)
    private List<String> redistributionMarkets = new ArrayList<>();

    @Column(name = "issued_at")
    private Instant issuedAt;

    @Column(name = "expires_at")
    private Instant expiresAt;

    // JPA-required no-arg constructor
    protected DataLicense() {}

    public DataLicense(String name, String spdxId) {
        this.name = name;
        this.spdxId = spdxId;
        this.issuedAt = Instant.now();
    }

    /**
     * Returns true if this license is currently valid (not expired).
     */
    public boolean isValid() {
        if (expiresAt == null) return true;
        return Instant.now().isBefore(expiresAt);
    }

    /**
     * Returns true if redistribution is allowed in the given market.
     */
    public boolean allowsRedistribution(String marketCode) {
        return redistributionMarkets.contains(marketCode);
    }

    // Getters
    public UUID getLicenseId() { return licenseId; }
    public String getName() { return name; }
    public String getSpdxId() { return spdxId; }
    public String getLicensee() { return licensee; }
    public List<String> getRedistributionMarkets() { return redistributionMarkets; }
    public Instant getIssuedAt() { return issuedAt; }
    public Instant getExpiresAt() { return expiresAt; }

    // Setters
    public void setName(String name) { this.name = name; }
    public void setSpdxId(String spdxId) { this.spdxId = spdxId; }
    public void setLicensee(String licensee) { this.licensee = licensee; }
    public void setRedistributionMarkets(List<String> redistributionMarkets) { this.redistributionMarkets = redistributionMarkets; }
    public void setIssuedAt(Instant issuedAt) { this.issuedAt = issuedAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
}
