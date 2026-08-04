package vnpt.vsp.module.geometry.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.geometry.LayerType;
import vnpt.vsp.module.geometry.entity.DraftGeometryFeature;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface GeometryRepository extends JpaRepository<DraftGeometryFeature, Long> {

    /**
     * Find all draft features for a course.
     */
    List<DraftGeometryFeature> findByCourseId(Long courseId);

    /**
     * Find all draft features for a course, filtered by layer type.
     */
    List<DraftGeometryFeature> findByCourseIdAndLayerType(Long courseId, LayerType layerType);

    /**
     * Find a feature by its UUID.
     */
    Optional<DraftGeometryFeature> findByFeatureUuid(UUID featureUuid);

    /**
     * Find all invalid features for a course.
     */
    List<DraftGeometryFeature> findByCourseIdAndValidFalse(Long courseId);

    /**
     * Find all invalid features for a course, filtered by layer type.
     */
    List<DraftGeometryFeature> findByCourseIdAndLayerTypeAndValidFalse(Long courseId, LayerType layerType);

    /**
     * Check if a feature with the given external ID already exists for a course and layer.
     */
    boolean existsByCourseIdAndLayerTypeAndExternalFeatureId(
            Long courseId, LayerType layerType, String externalFeatureId);

    /**
     * Find a feature by course, layer type, and external feature ID.
     */
    Optional<DraftGeometryFeature> findByCourseIdAndLayerTypeAndExternalFeatureId(
            Long courseId, LayerType layerType, String externalFeatureId);

    /**
     * Count features by course and validity status.
     */
    @Query("SELECT COUNT(f) FROM DraftGeometryFeature f WHERE f.course.id = :courseId AND f.valid = :valid")
    long countByCourseIdAndValid(@Param("courseId") Long courseId, @Param("valid") boolean valid);

    /**
     * Delete all features for a course.
     */
    void deleteByCourseId(Long courseId);
}
