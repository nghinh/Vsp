package vnpt.vsp.module.course.dto;

/**
 * Single field-level validation error for pre-publish validation.
 * Per Story 8.3 AC-1.
 */
public class ValidationError {

    private String entity;
    private Long entityId;
    private String field;
    private String code;
    private String message;

    public ValidationError() {}

    public ValidationError(String entity, Long entityId, String field, String code, String message) {
        this.entity = entity;
        this.entityId = entityId;
        this.field = field;
        this.code = code;
        this.message = message;
    }

    public String getEntity() { return entity; }
    public void setEntity(String entity) { this.entity = entity; }
    public Long getEntityId() { return entityId; }
    public void setEntityId(Long entityId) { this.entityId = entityId; }
    public String getField() { return field; }
    public void setField(String field) { this.field = field; }
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
