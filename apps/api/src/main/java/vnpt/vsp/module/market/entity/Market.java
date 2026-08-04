package vnpt.vsp.module.market.entity;

import jakarta.persistence.*;
import java.util.UUID;

/**
 * Market entity representing a supported geographic market.
 *
 * Story 12.4 — Slice 1: JPA Entities
 */
@Entity
@Table(name = "market")
public class Market {

    @Id
    @Column(name = "market_id", length = 2)
    private String marketId;

    @Column(nullable = false)
    private String name;

    @Column(name = "currency_code", length = 3)
    private String currencyCode;

    @Column(name = "date_format", length = 50)
    private String dateFormat;

    @Column(name = "measurement_unit", length = 20)
    private String measurementUnit;

    @Column(length = 50)
    private String timezone;

    @Column(name = "default_language", length = 10)
    private String defaultLanguage;

    @Column(nullable = false)
    private boolean active = true;

    // JPA-required no-arg constructor
    protected Market() {}

    public Market(String marketId, String name) {
        this.marketId = marketId;
        this.name = name;
    }

    // Getters
    public String getMarketId() { return marketId; }
    public String getName() { return name; }
    public String getCurrencyCode() { return currencyCode; }
    public String getDateFormat() { return dateFormat; }
    public String getMeasurementUnit() { return measurementUnit; }
    public String getTimezone() { return timezone; }
    public String getDefaultLanguage() { return defaultLanguage; }
    public boolean isActive() { return active; }

    // Setters
    public void setMarketId(String marketId) { this.marketId = marketId; }
    public void setName(String name) { this.name = name; }
    public void setCurrencyCode(String currencyCode) { this.currencyCode = currencyCode; }
    public void setDateFormat(String dateFormat) { this.dateFormat = dateFormat; }
    public void setMeasurementUnit(String measurementUnit) { this.measurementUnit = measurementUnit; }
    public void setTimezone(String timezone) { this.timezone = timezone; }
    public void setDefaultLanguage(String defaultLanguage) { this.defaultLanguage = defaultLanguage; }
    public void setActive(boolean active) { this.active = active; }
}
