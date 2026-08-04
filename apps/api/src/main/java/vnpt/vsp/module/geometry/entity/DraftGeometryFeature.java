package vnpt.vsp.module.geometry.entity;

import jakarta.persistence.*;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.geometry.GeometryModule;
import vnpt.vsp.module.geometry.LayerType;

import java.time.Instant;
import java.util.UUID;

/**
 * Draft geometry feature entity for the course map editor.
 * Per Story 8.2 Slice 6: CRUD endpoints for draft geometry management.
 * Per Story 3.1 AC-1/AC-2: SRID 4326, ST_IsValid, GIST indexes.
 *
 * <p>Stores draft (unpublished) geometry features per course per layer.
 * Geometry is stored as GeoJSON text and validated on create/update.</p>
 */
@Entity
@Table(name = "draft_geometry_features",
        indexes = {
                @Index(name = "idx_draft_geometry_course_id", columnList = "course_id"),
                @Index(name = "idx_draft_geometry_layer_type", columnList = "layer_type"),
                @Index(name = "idx_draft_geometry_hole_id", columnList = "hole_id")
        },
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_draft_geometry_course_layer_hole_feature",
                        columnNames = {"course_id", "layer_type", "hole_id", "external_feature_id"})
        })
@GeometryModule
public class DraftGeometryFeature {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * UUID assigned by the editor client for optimistic locking and idempotency.
     * The client generates this; it is not auto-generated so that the client
     * can create features in a single request without first consulting the server.
     */
    @Column(name = "feature_uuid", nullable = false, unique = true)
    private UUID featureUuid;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    /**
     * The hole this feature belongs to (nullable for course-level features like cart paths).
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hole_id")
    private vnpt.vsp.module.course.entity.Hole hole;

    /**
     * The layer type determines which geometry table this feature maps to on publish.
     * Stored as String for portability; validated against LayerType enum.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "layer_type", nullable = false, length = 50)
    private LayerType layerType;

    /**
     * GeoJSON geometry string (RFC 7946). Must be valid SRID 4326.
     * Stored as text so Hibernate can pass it directly to PostGIS ST_GeomFromGeoJSON.
     */
    @Column(name = "geometry", nullable = false, columnDefinition = "text")
    private String geometry;

    /**
     * Whether this geometry has been validated and is currently valid.
     * Updated on every create/update operation.
     */
    @Column(name = "is_valid", nullable = false)
    private boolean valid = true;

    /**
     * Human-readable validation message when is_valid is false.
     */
    @Column(name = "validity_message", columnDefinition = "text")
    private String validityMessage;

    /**
     * External feature ID for duplicate detection.
     * For features imported from GeoJSON, this is the feature's ID.
     * For editor-created features, this is the client's local ID.
     */
    @Column(name = "external_feature_id", length = 255)
    private String externalFeatureId;

    /**
     * Optional feature name (e.g., "Bunker 3", "Water Hole 14").
     */
    @Column(name = "feature_name", length = 255)
    private String featureName;

    @Embedded
    @AttributeOverrides({
            @AttributeOverride(name = "createdAt", column = @Column(name = "created_at", insertable = false, updatable = false)),
            @AttributeOverride(name = "updatedAt", column = @Column(name = "updated_at", insertable = false, updatable = false))
    })
    private DataQualityMetadata metadata = new DataQualityMetadata();

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
        // Initialize metadata timestamps directly (DataQualityMetadata is in a different package)
        if (metadata.getCreatedAt() == null) {
            metadata.setCreatedAt(createdAt);
            metadata.setUpdatedAt(updatedAt);
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
        metadata.setUpdatedAt(updatedAt);
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public UUID getFeatureUuid() {
        return featureUuid;
    }

    public void setFeatureUuid(UUID featureUuid) {
        this.featureUuid = featureUuid;
    }

    public Course getCourse() {
        return course;
    }

    public void setCourse(Course course) {
        this.course = course;
    }

    public vnpt.vsp.module.course.entity.Hole getHole() {
        return hole;
    }

    public void setHole(vnpt.vsp.module.course.entity.Hole hole) {
        this.hole = hole;
    }

    public LayerType getLayerType() {
        return layerType;
    }

    public void setLayerType(LayerType layerType) {
        this.layerType = layerType;
    }

    public String getGeometry() {
        return geometry;
    }

    public void setGeometry(String geometry) {
        this.geometry = geometry;
    }

    public boolean isValid() {
        return valid;
    }

    public void setValid(boolean valid) {
        this.valid = valid;
    }

    public String getValidityMessage() {
        return validityMessage;
    }

    public void setValidityMessage(String validityMessage) {
        this.validityMessage = validityMessage;
    }

    public String getExternalFeatureId() {
        return externalFeatureId;
    }

    public void setExternalFeatureId(String externalFeatureId) {
        this.externalFeatureId = externalFeatureId;
    }

    public String getFeatureName() {
        return featureName;
    }

    public void setFeatureName(String featureName) {
        this.featureName = featureName;
    }

    public DataQualityMetadata getMetadata() {
        return metadata;
    }

    public void setMetadata(DataQualityMetadata metadata) {
        this.metadata = metadata;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
