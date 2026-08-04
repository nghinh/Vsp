package vnpt.vsp.module.profile.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.profile.entity.GolferProfile;

import java.util.Optional;

/**
 * Repository for {@link GolferProfile} entity.
 */
@Repository
public interface GolferProfileRepository extends JpaRepository<GolferProfile, Long> {

    /**
     * Find a golfer's profile by their account ID.
     */
    Optional<GolferProfile> findByGolferAccountId(Long golferAccountId);
}
