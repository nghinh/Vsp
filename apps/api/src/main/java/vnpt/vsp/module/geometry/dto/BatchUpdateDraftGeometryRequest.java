package vnpt.vsp.module.geometry.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * Request DTO for batch updating draft geometry features.
 * Per Story 8.2 Slice 6.
 */
public class BatchUpdateDraftGeometryRequest {

    /**
     * List of features to create, update, or delete.
     */
    @NotNull(message = "Features list is required")
    @Valid
    private List<DraftFeatureOperation> features;

    public List<DraftFeatureOperation> getFeatures() {
        return features;
    }

    public void setFeatures(List<DraftFeatureOperation> features) {
        this.features = features;
    }

    /**
     * Represents a single operation within a batch update.
     */
    public static class DraftFeatureOperation {

        public enum OperationType {
            CREATE, UPDATE, DELETE
        }

        @NotNull(message = "Operation type is required")
        private OperationType operation;

        /**
         * For UPDATE and DELETE: the server-assigned feature UUID.
         * For CREATE: optional client-assigned UUID (server may generate one).
         */
        private String featureUuid;

        /**
         * For CREATE: the feature creation data.
         */
        private DraftFeatureCreateRequest create;

        /**
         * For UPDATE: the feature update data.
         */
        private DraftFeatureUpdateRequest update;

        // ─── Getters and Setters ────────────────────────────────────────────

        public OperationType getOperation() {
            return operation;
        }

        public void setOperation(OperationType operation) {
            this.operation = operation;
        }

        public String getFeatureUuid() {
            return featureUuid;
        }

        public void setFeatureUuid(String featureUuid) {
            this.featureUuid = featureUuid;
        }

        public DraftFeatureCreateRequest getCreate() {
            return create;
        }

        public void setCreate(DraftFeatureCreateRequest create) {
            this.create = create;
        }

        public DraftFeatureUpdateRequest getUpdate() {
            return update;
        }

        public void setUpdate(DraftFeatureUpdateRequest update) {
            this.update = update;
        }
    }
}
