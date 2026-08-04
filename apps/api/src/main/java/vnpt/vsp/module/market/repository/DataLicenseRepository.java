package vnpt.vsp.module.market.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.market.entity.DataLicense;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for DataLicense entities.
 *
 * Story 12.4 — Slice 3: License Validation
 */
@Repository("marketDataLicenseRepository")
public interface DataLicenseRepository extends JpaRepository<DataLicense, UUID> {

    /**
     * Find a license by its SPDX ID.
     */
    Optional<DataLicense> findBySpdxId(String spdxId);

    /**
     * Find all licenses that permit redistribution in a given market.
     */
    List<DataLicense> findByRedistributionMarketsContaining(String marketCode);

    /**
     * Find all currently valid (not expired) licenses.
     */
    List<DataLicense> findAllByExpiresAtIsNullOrExpiresAtAfter(java.time.Instant now);
}
