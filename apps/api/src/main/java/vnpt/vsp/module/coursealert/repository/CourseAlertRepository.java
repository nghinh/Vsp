package vnpt.vsp.module.coursealert.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.coursealert.entity.AlertType;
import vnpt.vsp.module.coursealert.entity.CourseAlert;
import vnpt.vsp.module.coursealert.entity.DeliveryStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * JPA repository for {@link CourseAlert} persistence and queries.
 */
@Repository
public interface CourseAlertRepository extends JpaRepository<CourseAlert, Long> {

    /**
     * Find alerts for a facility filtered by type effective before a given time.
     * Per Slice 1 spec: supports facility-level alert queries.
     */
    List<CourseAlert> findByFacilityIdAndAlertTypeAndEffectiveAtBefore(
            UUID facilityId, AlertType alertType, OffsetDateTime effectiveAt);

    /**
     * Find active (non-expired, effective) alerts for a target scope.
     * Active = effectiveAt <= now AND (expiresAt IS NULL OR expiresAt > now) AND deliveryStatus != EXPIRED.
     * Per Story 8.6 AC-3.
     */
    @Query("SELECT a FROM CourseAlert a WHERE " +
           "a.effectiveAt <= :now AND (a.expiresAt IS NULL OR a.expiresAt > :now) " +
           "AND a.deliveryStatus != vnpt.vsp.module.coursealert.entity.DeliveryStatus.EXPIRED " +
           "ORDER BY a.priority DESC, a.effectiveAt DESC")
    List<CourseAlert> findActiveAlerts(@Param("now") OffsetDateTime now);

    /**
     * Find active alerts for a specific course.
     */
    @Query("SELECT a FROM CourseAlert a WHERE " +
           "a.courseId = :courseId AND a.effectiveAt <= :now " +
           "AND (a.expiresAt IS NULL OR a.expiresAt > :now) " +
           "AND a.deliveryStatus != vnpt.vsp.module.coursealert.entity.DeliveryStatus.EXPIRED " +
           "ORDER BY a.priority DESC, a.effectiveAt DESC")
    List<CourseAlert> findActiveAlertsByCourseId(@Param("courseId") UUID courseId,
                                                 @Param("now") OffsetDateTime now);

    /**
     * Find active alerts for a specific hole.
     */
    @Query("SELECT a FROM CourseAlert a WHERE " +
           "a.holeId = :holeId AND a.effectiveAt <= :now " +
           "AND (a.expiresAt IS NULL OR a.expiresAt > :now) " +
           "AND a.deliveryStatus != vnpt.vsp.module.coursealert.entity.DeliveryStatus.EXPIRED " +
           "ORDER BY a.priority DESC, a.effectiveAt DESC")
    List<CourseAlert> findActiveAlertsByHoleId(@Param("holeId") UUID holeId,
                                               @Param("now") OffsetDateTime now);

    /**
     * Find alerts awaiting acknowledgment.
     * Per Story 8.6 AC-3: acknowledgment tracking.
     */
    @Query("SELECT a FROM CourseAlert a WHERE " +
           "a.acknowledgmentRequired = true AND a.acknowledgedAt IS NULL " +
           "AND a.effectiveAt <= :now AND (a.expiresAt IS NULL OR a.expiresAt > :now) " +
           "ORDER BY a.priority DESC, a.effectiveAt DESC")
    List<CourseAlert> findAcknowledgmentPending(@Param("now") OffsetDateTime now);

    /**
     * Find all alerts by courseId (not restricted to active window).
     */
    List<CourseAlert> findByCourseIdOrderByEffectiveAtDesc(UUID courseId);

    /**
     * Find alerts by delivery status.
     */
    List<CourseAlert> findByDeliveryStatus(DeliveryStatus deliveryStatus);
}
