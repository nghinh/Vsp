package vnpt.vsp.module.operations;

import vnpt.vsp.module.operations.dto.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Operations module public service interface.
 * Exposes course operations portal backend operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 *
 * Per Story 8.5:
 * - AC-1: place/schedule pins with effective + expiration times
 * - AC-2: update green speed (stimpmeter), firmness, moisture, course status
 * - AC-3: effective and expiration times are required where applicable
 * - AC-4: mobile sync reflects newly published operational data (via package rebuild)
 */
public interface OperationsService {

    // ─── Pin Position CRUD ───────────────────────────────────────────────────────

    /**
     * Create a new pin position for a hole.
     *
     * @param courseId     the course ID
     * @param holeNumber   the hole number
     * @param position     WKT geometry string (SRID 4326 POINT)
     * @param effectiveFrom when this pin becomes active (required)
     * @param expiresAt    when this pin expires (required for pins per AC-3)
     * @param publishedBy  user who scheduled this pin
     * @param confidence   confidence score 0.0-1.0 (optional)
     * @return the created pin position DTO
     */
    PinPositionDto createPinPosition(Long courseId, Integer holeNumber, String position,
                                     Instant effectiveFrom, Instant expiresAt,
                                     String publishedBy, BigDecimal confidence);

    /**
     * Update an existing pin position.
     *
     * @param pinId        the pin position ID
     * @param position     new WKT geometry string (SRID 4326 POINT), or null to keep current
     * @param effectiveFrom new effective time, or null to keep current
     * @param expiresAt    new expiration time, or null to keep current
     * @return the updated pin position DTO
     */
    PinPositionDto updatePinPosition(Long pinId, String position,
                                     Instant effectiveFrom, Instant expiresAt);

    /**
     * Get active pin positions for a specific hole as of a given instant.
     *
     * @param courseId   the course ID
     * @param holeNumber the hole number
     * @param asOfDate   the instant to query at (defaults to now if null)
     * @return list of active pin position DTOs
     */
    List<PinPositionDto> getPinPositions(Long courseId, Integer holeNumber, Instant asOfDate);

    /**
     * Get all active pin positions for a course (all holes) as of a given instant.
     *
     * @param courseId the course ID
     * @param asOfDate the instant to query at (defaults to now if null)
     * @return list of active pin position DTOs for all holes
     */
    List<PinPositionDto> getAllPinPositions(Long courseId, Instant asOfDate);

    // ─── Green Condition CRUD ───────────────────────────────────────────────────

    /**
     * Create a new green condition reading for a hole.
     *
     * @param courseId       the course ID
     * @param holeNumber     the hole number
     * @param stimpmeter     stimpmeter reading in feet (range 6-14 per AC-2)
     * @param firmness       green firmness level (SOFT/MEDIUM/FIRM/HARD)
     * @param moisture       green moisture level (DRY/NORMAL/WET/SATURATED)
     * @param effectiveFrom  when this condition becomes active (required)
     * @param expiresAt      when this condition expires (optional)
     * @param publishedBy    user who recorded this condition
     * @return the created green condition DTO
     */
    GreenConditionDto createGreenCondition(Long courseId, Integer holeNumber,
                                           BigDecimal stimpmeter,
                                           String firmness, String moisture,
                                           Instant effectiveFrom, Instant expiresAt,
                                           String publishedBy);

    /**
     * Update an existing green condition.
     *
     * @param conditionId the green condition ID
     * @param stimpmeter  new stimpmeter reading, or null to keep current
     * @param firmness    new firmness, or null to keep current
     * @param moisture    new moisture, or null to keep current
     * @param effectiveFrom new effective time, or null to keep current
     * @param expiresAt   new expiration time, or null to keep current
     * @return the updated green condition DTO
     */
    GreenConditionDto updateGreenCondition(Long conditionId, BigDecimal stimpmeter,
                                           String firmness, String moisture,
                                           Instant effectiveFrom, Instant expiresAt);

    /**
     * Get active green conditions for a specific hole as of a given instant.
     *
     * @param courseId   the course ID
     * @param holeNumber the hole number
     * @param asOfDate   the instant to query at (defaults to now if null)
     * @return list of active green condition DTOs
     */
    List<GreenConditionDto> getGreenConditions(Long courseId, Integer holeNumber, Instant asOfDate);

    /**
     * Get all active green conditions for a course (all holes) as of a given instant.
     *
     * @param courseId the course ID
     * @param asOfDate the instant to query at (defaults to now if null)
     * @return list of active green condition DTOs for all holes
     */
    List<GreenConditionDto> getAllGreenConditions(Long courseId, Instant asOfDate);

    // ─── Course Condition CRUD ──────────────────────────────────────────────────

    /**
     * Create a new course-level condition.
     *
     * @param courseId      the course ID
     * @param conditionType type of condition (GREEN_SPEED/FAIRWAY_FIRMNESS/etc.)
     * @param severity      severity level (LOW/MODERATE/HIGH/CRITICAL)
     * @param description   human-readable description
     * @param effectiveFrom when this condition becomes active (required)
     * @param expiresAt     when this condition expires (optional)
     * @param publishedBy   user who published this condition
     * @return the created course condition DTO
     */
    CourseConditionDto createCourseCondition(Long courseId, String conditionType,
                                             String severity, String description,
                                             Instant effectiveFrom, Instant expiresAt,
                                             String publishedBy);

    /**
     * Update an existing course condition.
     *
     * @param conditionId  the course condition ID
     * @param conditionType new type, or null to keep current
     * @param severity     new severity, or null to keep current
     * @param description  new description, or null to keep current
     * @param effectiveFrom new effective time, or null to keep current
     * @param expiresAt    new expiration time, or null to keep current
     * @return the updated course condition DTO
     */
    CourseConditionDto updateCourseCondition(Long conditionId, String conditionType,
                                             String severity, String description,
                                             Instant effectiveFrom, Instant expiresAt);

    /**
     * Get active course conditions for a course as of a given instant.
     *
     * @param courseId the course ID
     * @param asOfDate the instant to query at (defaults to now if null)
     * @return list of active course condition DTOs
     */
    List<CourseConditionDto> getCourseConditions(Long courseId, Instant asOfDate);

    // ─── Publish ───────────────────────────────────────────────────────────────

    /**
     * Trigger an async package rebuild for a course to publish operational data.
     * Per AC-4: mobile sync reflects newly published operational data.
     *
     * Idempotent: if a non-terminal build job already exists for this course,
     * returns that job ID without creating a duplicate.
     *
     * @param courseId    the course ID
     * @param triggeredBy username of the operator triggering the rebuild
     * @return the ID of the enqueued (or existing) build job
     */
    UUID publishOperationalData(Long courseId, String triggeredBy);
}
