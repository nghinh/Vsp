package vnpt.vsp.module.market;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.market.entity.*;
import vnpt.vsp.module.market.repository.*;
import java.util.List;
import java.util.stream.Collectors;

/**
 * REST controller for admin market management endpoints.
 *
 * Exposes:
 * - GET /admin/markets — list all markets
 * - PUT /admin/markets/{marketId} — create or update a market
 * - PUT /admin/markets/{marketId}/config — create or update market config
 *
 * Story 12.4 — Slice 4: Market Config API
 */
@RestController
@RequestMapping("/admin/markets")
public class AdminMarketController {

    private final MarketRepository marketRepository;
    private final MarketConfigRepository marketConfigRepository;
    private final MarketConfigService marketConfigService;

    public AdminMarketController(
            MarketRepository marketRepository,
            MarketConfigRepository marketConfigRepository,
            MarketConfigService marketConfigService) {
        this.marketRepository = marketRepository;
        this.marketConfigRepository = marketConfigRepository;
        this.marketConfigService = marketConfigService;
    }

    /**
     * List all markets.
     */
    @GetMapping
    public ResponseEntity<MarketController.MarketListResponse> listMarkets(
            @RequestParam(required = false) Boolean active) {

        List<Market> markets;
        if (active != null) {
            markets = active
                ? marketRepository.findByActiveTrue()
                : marketRepository.findByActiveFalse();
        } else {
            markets = marketRepository.findAll();
        }

        return ResponseEntity.ok(new MarketController.MarketListResponse(markets));
    }

    /**
     * Create or update a market.
     */
    @PutMapping("/{marketId}")
    public ResponseEntity<MarketController.MarketResponse> upsertMarket(
            @PathVariable String marketId,
            @RequestBody MarketRequest request) {

        Market market = marketRepository.findByMarketId(marketId)
                .orElseGet(() -> new Market(marketId, request.name));

        market.setName(request.name);
        market.setCurrencyCode(request.currencyCode);
        market.setDateFormat(request.dateFormat);
        market.setMeasurementUnit(request.measurementUnit);
        market.setTimezone(request.timezone);
        market.setDefaultLanguage(request.defaultLanguage);
        if (request.active != null) {
            market.setActive(request.active);
        }

        Market saved = marketRepository.save(market);
        return ResponseEntity.ok(new MarketController.MarketResponse(saved));
    }

    /**
     * Create or update market config.
     */
    @PutMapping("/{marketId}/config")
    public ResponseEntity<MarketConfig> upsertMarketConfig(
            @PathVariable String marketId,
            @RequestBody MarketConfigRequest request) {

        Market market = marketRepository.findByMarketId(marketId)
                .orElse(null);

        if (market == null) {
            return ResponseEntity.notFound().build();
        }

        MarketConfig config = marketConfigRepository.findByMarketMarketId(marketId)
                .orElseGet(() -> {
                    MarketConfig newConfig = new MarketConfig(market);
                    return newConfig;
                });

        if (request.forkGpsBehavior != null) {
            config.setForkGpsBehavior(request.forkGpsBehavior);
        }
        if (request.forkScoreBehavior != null) {
            config.setForkScoreBehavior(request.forkScoreBehavior);
        }
        if (request.redistributionRequiresLicense != null) {
            config.setRedistributionRequiresLicense(request.redistributionRequiresLicense);
        }

        MarketConfig saved = marketConfigRepository.save(config);
        return ResponseEntity.ok(saved);
    }

    // Request DTOs

    public static class MarketRequest {
        public String name;
        public String currencyCode;
        public String dateFormat;
        public String measurementUnit;
        public String timezone;
        public String defaultLanguage;
        public Boolean active;
    }

    public static class MarketConfigRequest {
        public Boolean forkGpsBehavior;
        public Boolean forkScoreBehavior;
        public Boolean redistributionRequiresLicense;
    }
}
