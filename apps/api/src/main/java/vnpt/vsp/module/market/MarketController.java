package vnpt.vsp.module.market;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.market.entity.*;
import vnpt.vsp.module.market.repository.*;
import java.util.List;
import java.util.stream.Collectors;

/**
 * REST controller for market endpoints.
 *
 * Exposes:
 * - GET /markets — list all markets
 * - GET /markets/{marketId} — get a market
 * - GET /markets/{marketId}/config — get resolved market config
 *
 * Story 12.4 — Slice 4: Market Config API
 */
@RestController
@RequestMapping("/markets")
public class MarketController {

    private final MarketRepository marketRepository;
    private final MarketConfigService marketConfigService;

    public MarketController(MarketRepository marketRepository, MarketConfigService marketConfigService) {
        this.marketRepository = marketRepository;
        this.marketConfigService = marketConfigService;
    }

    /**
     * List all markets, optionally filtered by active status.
     */
    @GetMapping
    public ResponseEntity<MarketListResponse> listMarkets(
            @RequestParam(required = false) Boolean active) {

        List<Market> markets;
        if (active != null) {
            markets = active
                ? marketRepository.findByActiveTrue()
                : marketRepository.findByActiveFalse();
        } else {
            markets = marketRepository.findAll();
        }

        return ResponseEntity.ok(new MarketListResponse(markets));
    }

    /**
     * Get a market by code.
     */
    @GetMapping("/{marketId}")
    public ResponseEntity<MarketResponse> getMarket(@PathVariable String marketId) {
        return marketRepository.findByMarketId(marketId)
                .map(m -> ResponseEntity.ok(new MarketResponse(m)))
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Get the fully resolved market config for a market.
     * Unset fields are filled with Vietnam defaults.
     */
    @GetMapping("/{marketId}/config")
    public ResponseEntity<MarketConfigService.ResolvedMarketConfig> getMarketConfig(
            @PathVariable String marketId) {
        try {
            MarketConfigService.ResolvedMarketConfig config = marketConfigService.getResolvedConfig(marketId);
            return ResponseEntity.ok(config);
        } catch (MarketConfigService.MarketNotFoundException e) {
            return ResponseEntity.notFound().build();
        }
    }

    // Response DTOs

    public static class MarketListResponse {
        private final List<MarketResponse> content;
        private final int page = 0;
        private final int size;
        private final long totalElements;
        private final int totalPages = 1;

        public MarketListResponse(List<Market> markets) {
            this.content = markets.stream().map(MarketResponse::new).collect(Collectors.toList());
            this.size = markets.size();
            this.totalElements = markets.size();
        }

        public List<MarketResponse> getContent() { return content; }
        public int getPage() { return page; }
        public int getSize() { return size; }
        public long getTotalElements() { return totalElements; }
        public int getTotalPages() { return totalPages; }
    }

    public static class MarketResponse {
        private final String marketId;
        private final String name;
        private final String currencyCode;
        private final String dateFormat;
        private final String measurementUnit;
        private final String timezone;
        private final String defaultLanguage;
        private final boolean active;

        public MarketResponse(Market market) {
            this.marketId = market.getMarketId();
            this.name = market.getName();
            this.currencyCode = market.getCurrencyCode();
            this.dateFormat = market.getDateFormat();
            this.measurementUnit = market.getMeasurementUnit();
            this.timezone = market.getTimezone();
            this.defaultLanguage = market.getDefaultLanguage();
            this.active = market.isActive();
        }

        public String getMarketId() { return marketId; }
        public String getName() { return name; }
        public String getCurrencyCode() { return currencyCode; }
        public String getDateFormat() { return dateFormat; }
        public String getMeasurementUnit() { return measurementUnit; }
        public String getTimezone() { return timezone; }
        public String getDefaultLanguage() { return defaultLanguage; }
        public boolean isActive() { return active; }
    }
}
