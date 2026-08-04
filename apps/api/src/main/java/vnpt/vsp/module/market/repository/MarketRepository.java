package vnpt.vsp.module.market.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.market.entity.Market;
import java.util.List;
import java.util.Optional;

/**
 * Repository for Market entities.
 *
 * Story 12.4 — Slice 1: JPA Entities
 */
@Repository
public interface MarketRepository extends JpaRepository<Market, String> {

    /**
     * Find an active market by its code.
     */
    Optional<Market> findByMarketIdAndActiveTrue(String marketId);

    /**
     * Find a market by its code (regardless of active status).
     */
    Optional<Market> findByMarketId(String marketId);

    /**
     * Find all active markets.
     */
    List<Market> findByActiveTrue();

    /**
     * Find all inactive markets.
     */
    List<Market> findByActiveFalse();
}
