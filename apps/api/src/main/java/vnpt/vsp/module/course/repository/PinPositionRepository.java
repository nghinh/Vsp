package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.PinPosition;

import java.time.LocalDate;
import java.util.List;

@Repository("coursePinPositionRepository")
public interface PinPositionRepository extends JpaRepository<PinPosition, Long> {
    List<PinPosition> findByHoleId(Long holeId);

    List<PinPosition> findByHoleIdAndExpiryDateIsNull(Long holeId);

    List<PinPosition> findByHoleIdAndEffectiveDateLessThanEqualAndExpiryDateIsNull(Long holeId, LocalDate date);
}
