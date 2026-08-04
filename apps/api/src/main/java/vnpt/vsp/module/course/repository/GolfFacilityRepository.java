package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.GolfFacility;

import java.util.List;

@Repository
public interface GolfFacilityRepository extends JpaRepository<GolfFacility, Long> {

    List<GolfFacility> findByNameContainingIgnoreCase(String name);

    java.util.Optional<GolfFacility> findByName(String name);

    @Query("SELECT COUNT(c) FROM Course c WHERE c.facility.id = :facilityId")
    long countByCoursesFacilityId(@Param("facilityId") Long facilityId);

    @Query("SELECT COUNT(c) FROM Course c WHERE c.facility.id = :facilityId")
    long countCoursesByFacilityId(@Param("facilityId") Long facilityId);

    /**
     * Extract longitude from POINT geometry column using PostGIS ST_X.
     * Returns null if location is null.
     */
    @Query(value = "SELECT ST_X(f.location::geometry) FROM golf_facilities f WHERE f.id = :facilityId", nativeQuery = true)
    Double findLongitudeByFacilityId(@Param("facilityId") Long facilityId);

    /**
     * Extract latitude from POINT geometry column using PostGIS ST_Y.
     * Returns null if location is null.
     */
    @Query(value = "SELECT ST_Y(f.location::geometry) FROM golf_facilities f WHERE f.id = :facilityId", nativeQuery = true)
    Double findLatitudeByFacilityId(@Param("facilityId") Long facilityId);
}
