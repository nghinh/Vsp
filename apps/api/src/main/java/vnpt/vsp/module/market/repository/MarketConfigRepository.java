package vnpt.vsp.module.market.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.market.entity.MarketConfig;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for MarketConfig entities.
 *
 * Story 12.4 — Slice 3: License Validation
 */
@Repository
public interface MarketConfigRepository extends JpaRepository<MarketConfig, UUID> {

    /**
     * Find market config by market code.
     */
    Optional<MarketConfig> findByMarketMarketId(String marketId);
}
