package vnpt.vsp.module.market;

import vnpt.vsp.module.market.entity.*;
import vnpt.vsp.module.market.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.Optional;

/**
 * Service for resolving market configurations and validating license redistribution.
 *
 * Story 12.4 — Slice 3: License Validation
 */
@Service
public class MarketConfigService {

    private final MarketRepository marketRepository;
    private final MarketConfigRepository marketConfigRepository;
    private final DataLicenseRepository dataLicenseRepository;

    @Autowired
    public MarketConfigService(
            MarketRepository marketRepository,
            MarketConfigRepository marketConfigRepository,
            DataLicenseRepository dataLicenseRepository) {
        this.marketRepository = marketRepository;
        this.marketConfigRepository = marketConfigRepository;
        this.dataLicenseRepository = dataLicenseRepository;
    }

    /**
     * Result of license redistribution validation.
     */
    public static class LicenseValidationResult {
        private final boolean valid;
        private final java.util.List<LicenseValidationError> errors;

        public LicenseValidationResult(boolean valid, java.util.List<LicenseValidationError> errors) {
            this.valid = valid;
            this.errors = errors;
        }

        public static LicenseValidationResult success() {
            return new LicenseValidationResult(true, java.util.Collections.emptyList());
        }

        public static LicenseValidationResult failure(java.util.List<LicenseValidationError> errors) {
            return new LicenseValidationResult(false, errors);
        }

        public boolean isValid() { return valid; }
        public java.util.List<LicenseValidationError> getErrors() { return errors; }
    }

    /**
     * Single license validation error.
     */
    public static class LicenseValidationError {
        private final String licenseId;
        private final String spdxId;
        private final String code;
        private final String message;
        private final String targetMarket;

        public LicenseValidationError(String licenseId, String spdxId, String code, String message, String targetMarket) {
            this.licenseId = licenseId;
            this.spdxId = spdxId;
            this.code = code;
            this.message = message;
            this.targetMarket = targetMarket;
        }

        public String getLicenseId() { return licenseId; }
        public String getSpdxId() { return spdxId; }
        public String getCode() { return code; }
        public String getMessage() { return message; }
        public String getTargetMarket() { return targetMarket; }
    }

    /**
     * Resolved market config combining market-specific overrides with Vietnam defaults.
     */
    public static class ResolvedMarketConfig {
        private final String marketId;
        private final String locale;
        private final String language;
        private final String units;
        private final String timezone;
        private final String currency;
        private final String dateFormat;
        private final String rulesUrl;
        private final java.util.List<String> enabledProviderIds;
        private final java.util.List<String> requiredLicenseIds;
        private final int retentionPolicyDays;
        private final boolean forkGpsBehavior;
        private final boolean forkScoreBehavior;
        private final boolean redistributionRequiresLicense;

        public ResolvedMarketConfig(
                String marketId, String locale, String language, String units,
                String timezone, String currency, String dateFormat, String rulesUrl,
                java.util.List<String> enabledProviderIds, java.util.List<String> requiredLicenseIds,
                int retentionPolicyDays, boolean forkGpsBehavior, boolean forkScoreBehavior,
                boolean redistributionRequiresLicense) {
            this.marketId = marketId;
            this.locale = locale;
            this.language = language;
            this.units = units;
            this.timezone = timezone;
            this.currency = currency;
            this.dateFormat = dateFormat;
            this.rulesUrl = rulesUrl;
            this.enabledProviderIds = enabledProviderIds;
            this.requiredLicenseIds = requiredLicenseIds;
            this.retentionPolicyDays = retentionPolicyDays;
            this.forkGpsBehavior = forkGpsBehavior;
            this.forkScoreBehavior = forkScoreBehavior;
            this.redistributionRequiresLicense = redistributionRequiresLicense;
        }

        public String getMarketId() { return marketId; }
        public String getLocale() { return locale; }
        public String getLanguage() { return language; }
        public String getUnits() { return units; }
        public String getTimezone() { return timezone; }
        public String getCurrency() { return currency; }
        public String getDateFormat() { return dateFormat; }
        public String getRulesUrl() { return rulesUrl; }
        public java.util.List<String> getEnabledProviderIds() { return enabledProviderIds; }
        public java.util.List<String> getRequiredLicenseIds() { return requiredLicenseIds; }
        public int getRetentionPolicyDays() { return retentionPolicyDays; }
        public boolean isForkGpsBehavior() { return forkGpsBehavior; }
        public boolean isForkScoreBehavior() { return forkScoreBehavior; }
        public boolean isRedistributionRequiresLicense() { return redistributionRequiresLicense; }
    }

    /**
     * Get the fully resolved market config for a market code.
     * Unset fields are filled with Vietnam defaults.
     */
    public ResolvedMarketConfig getResolvedConfig(String marketCode) {
        Market market = marketRepository.findByMarketId(marketCode)
                .orElseThrow(() -> new MarketNotFoundException(marketCode));

        Optional<MarketConfig> configOpt = marketConfigRepository.findByMarketMarketId(marketCode);

        // Use Market fields as overrides, fall back to Vietnam defaults
        String locale = market.getDefaultLanguage() != null
                ? market.getDefaultLanguage() + "-" + marketCode
                : VietnamDefaults.LOCALE;
        String language = market.getDefaultLanguage() != null
                ? market.getDefaultLanguage()
                : VietnamDefaults.LANGUAGE;
        String measurementUnit = market.getMeasurementUnit() != null
                ? market.getMeasurementUnit()
                : VietnamDefaults.MEASUREMENT_UNIT;
        String timezone = market.getTimezone() != null
                ? market.getTimezone()
                : VietnamDefaults.TIMEZONE;
        String currency = market.getCurrencyCode() != null
                ? market.getCurrencyCode()
                : VietnamDefaults.CURRENCY_CODE;
        String dateFormat = market.getDateFormat() != null
                ? market.getDateFormat()
                : VietnamDefaults.DATE_FORMAT;

        // MarketConfig behavior flags (from MarketConfig, not Market)
        boolean forkGpsBehavior = configOpt.flatMap(c -> Optional.ofNullable(c.getForkGpsBehavior())).orElse(VietnamDefaults.FORK_GPS_BEHAVIOR);
        boolean forkScoreBehavior = configOpt.flatMap(c -> Optional.ofNullable(c.getForkScoreBehavior())).orElse(VietnamDefaults.FORK_SCORE_BEHAVIOR);
        boolean redistributionRequiresLicense = configOpt.flatMap(c -> Optional.ofNullable(c.getRedistributionRequiresLicense())).orElse(VietnamDefaults.REDISTRIBUTION_REQUIRES_LICENSE);

        return new ResolvedMarketConfig(
                marketCode,
                locale,
                language,
                measurementUnit,
                timezone,
                currency,
                dateFormat,
                null, // rulesUrl - not available on Market entity in this design
                VietnamDefaults.ENABLED_PROVIDER_IDS,
                VietnamDefaults.REQUIRED_LICENSE_IDS,
                VietnamDefaults.RETENTION_POLICY_DAYS,
                forkGpsBehavior,
                forkScoreBehavior,
                redistributionRequiresLicense
        );
    }

    /**
     * Validate whether the given package licenses allow redistribution in the target market.
     * Throws VSPException with code VSP_LICENSE_001 if redistributionRequiresLicense is true
     * and no matching entry exists in any license's redistributionMarkets.
     */
    public LicenseValidationResult validateRedistribution(
            Market market,
            String targetMarketId,
            java.util.List<LicenseEntry> licenses) {

        ResolvedMarketConfig config = getResolvedConfig(targetMarketId);

        // If redistribution doesn't require license, it's always valid
        if (!config.isRedistributionRequiresLicense()) {
            return LicenseValidationResult.success();
        }

        java.util.List<LicenseValidationError> errors = new java.util.ArrayList<>();

        for (LicenseEntry entry : licenses) {
            Optional<DataLicense> licenseOpt = dataLicenseRepository.findBySpdxId(entry.spdxId);

            if (licenseOpt.isEmpty()) {
                errors.add(new LicenseValidationError(
                        null,
                        entry.spdxId,
                        "LICENSE_NOT_FOUND",
                        "License with SPDX ID '" + entry.spdxId + "' not found",
                        targetMarketId
                ));
                continue;
            }

            DataLicense license = licenseOpt.get();

            if (!license.isValid()) {
                errors.add(new LicenseValidationError(
                        license.getLicenseId().toString(),
                        entry.spdxId,
                        "LICENSE_EXPIRED",
                        "License '" + license.getName() + "' has expired",
                        targetMarketId
                ));
                continue;
            }

            if (!license.allowsRedistribution(targetMarketId)) {
                errors.add(new LicenseValidationError(
                        license.getLicenseId().toString(),
                        entry.spdxId,
                        "LICENSE_REDISTRIBUTION_NOT_ALLOWED",
                        "License '" + license.getName() + "' does not permit redistribution in market '" + targetMarketId + "'",
                        targetMarketId
                ));
            }
        }

        if (errors.isEmpty()) {
            return LicenseValidationResult.success();
        } else {
            return LicenseValidationResult.failure(errors);
        }
    }

    /**
     * License entry from a course package for validation.
     */
    public static class LicenseEntry {
        private final String spdxId;
        private final String licenseId;

        public LicenseEntry(String spdxId, String licenseId) {
            this.spdxId = spdxId;
            this.licenseId = licenseId;
        }

        public String getSpdxId() { return spdxId; }
        public String getLicenseId() { return licenseId; }
    }

    /**
     * Exception thrown when a market is not found.
     */
    public static class MarketNotFoundException extends RuntimeException {
        private final String marketId;

        public MarketNotFoundException(String marketId) {
            super("Market not found: " + marketId);
            this.marketId = marketId;
        }

        public String getMarketId() { return marketId; }
    }
}
