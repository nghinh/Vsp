package vnpt.vsp.module.market;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.market.entity.DataLicense;
import vnpt.vsp.module.market.repository.DataLicenseRepository;
import vnpt.vsp.module.market.repository.MarketRepository;
import java.util.List;
import java.util.stream.Collectors;

/**
 * REST controller for admin data license management endpoints.
 *
 * Exposes:
 * - GET /admin/licenses — list all licenses
 * - POST /admin/licenses — create a license
 * - POST /admin/licenses/validate-redistribution — validate redistribution
 *
 * Story 12.4 — Slice 4: Market Config API
 *
 * <p>Licensing terms decide what may be redistributed and to whom, so the whole
 * controller is SUPER_ADMIN. It carried no authorization check of any kind until
 * the {@code /admin/**} chain was repaired, which had been hiding that.</p>
 */
@RestController
@RequestMapping("/admin/licenses")
@PreAuthorize("hasRole('SUPER_ADMIN')")
public class DataLicenseController {

    private final DataLicenseRepository dataLicenseRepository;
    private final MarketRepository marketRepository;
    private final MarketConfigService marketConfigService;

    public DataLicenseController(
            DataLicenseRepository dataLicenseRepository,
            MarketRepository marketRepository,
            MarketConfigService marketConfigService) {
        this.dataLicenseRepository = dataLicenseRepository;
        this.marketRepository = marketRepository;
        this.marketConfigService = marketConfigService;
    }

    /**
     * List all data licenses.
     */
    @GetMapping
    public ResponseEntity<LicenseListResponse> listLicenses() {
        List<DataLicense> licenses = dataLicenseRepository.findAll();
        return ResponseEntity.ok(new LicenseListResponse(licenses));
    }

    /**
     * Create a new data license.
     */
    @PostMapping
    public ResponseEntity<DataLicenseResponse> createLicense(@RequestBody CreateLicenseRequest request) {
        DataLicense license = new DataLicense(request.name, request.spdxId);
        license.setLicensee(request.licensee);
        license.setRedistributionMarkets(request.redistributionMarkets);
        if (request.expiresAt != null) {
            license.setExpiresAt(java.time.Instant.parse(request.expiresAt));
        }

        DataLicense saved = dataLicenseRepository.save(license);
        return ResponseEntity.status(HttpStatus.CREATED).body(new DataLicenseResponse(saved));
    }

    /**
     * Validate license redistribution for a target market.
     */
    @PostMapping("/validate-redistribution")
    public ResponseEntity<MarketConfigService.LicenseValidationResult> validateRedistribution(
            @RequestBody ValidateRedistributionRequest request) {

        return marketRepository.findByMarketId(request.targetMarket)
                .map(market -> {
                    List<MarketConfigService.LicenseEntry> entries = request.licenses.stream()
                            .map(l -> new MarketConfigService.LicenseEntry(l.spdxId, l.licenseId))
                            .collect(Collectors.toList());

                    MarketConfigService.LicenseValidationResult result =
                            marketConfigService.validateRedistribution(market, request.targetMarket, entries);
                    return ResponseEntity.ok(result);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    // Request/Response DTOs

    public static class LicenseListResponse {
        public List<DataLicenseResponse> content;

        public LicenseListResponse(List<DataLicense> licenses) {
            this.content = licenses.stream().map(DataLicenseResponse::new).collect(Collectors.toList());
        }

        public List<DataLicenseResponse> getContent() { return content; }
    }

    public static class DataLicenseResponse {
        public String licenseId;
        public String name;
        public String spdxId;
        public String licensee;
        public List<String> redistributionMarkets;
        public String issuedAt;
        public String expiresAt;
        public boolean valid;

        public DataLicenseResponse(DataLicense license) {
            this.licenseId = license.getLicenseId().toString();
            this.name = license.getName();
            this.spdxId = license.getSpdxId();
            this.licensee = license.getLicensee();
            this.redistributionMarkets = license.getRedistributionMarkets();
            this.issuedAt = license.getIssuedAt() != null ? license.getIssuedAt().toString() : null;
            this.expiresAt = license.getExpiresAt() != null ? license.getExpiresAt().toString() : null;
            this.valid = license.isValid();
        }

        public String getLicenseId() { return licenseId; }
        public String getName() { return name; }
        public String getSpdxId() { return spdxId; }
        public String getLicensee() { return licensee; }
        public List<String> getRedistributionMarkets() { return redistributionMarkets; }
        public String getIssuedAt() { return issuedAt; }
        public String getExpiresAt() { return expiresAt; }
        public boolean isValid() { return valid; }
    }

    public static class CreateLicenseRequest {
        public String name;
        public String spdxId;
        public String licensee;
        public List<String> redistributionMarkets;
        public String expiresAt;
    }

    public static class ValidateRedistributionRequest {
        public String targetMarket;
        public List<LicenseSpdxEntry> licenses;

        public static class LicenseSpdxEntry {
            public String spdxId;
            public String licenseId;
        }
    }
}
