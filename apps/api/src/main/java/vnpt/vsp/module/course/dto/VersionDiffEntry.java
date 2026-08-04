package vnpt.vsp.module.course.dto;

/**
 * A single change between two course data versions.
 * Per Story 8.3 AC-2.
 */
public class VersionDiffEntry {

    public enum ChangeType {
        ADDED, REMOVED, CHANGED
    }

    private String entity;
    private Long entityId;
    private String field;
    private ChangeType changeType;
    private String oldValue;
    private String newValue;

    public VersionDiffEntry() {}

    public VersionDiffEntry(String entity, Long entityId, String field,
                           ChangeType changeType, String oldValue, String newValue) {
        this.entity = entity;
        this.entityId = entityId;
        this.field = field;
        this.changeType = changeType;
        this.oldValue = oldValue;
        this.newValue = newValue;
    }

    public String getEntity() { return entity; }
    public void setEntity(String entity) { this.entity = entity; }
    public Long getEntityId() { return entityId; }
    public void setEntityId(Long entityId) { this.entityId = entityId; }
    public String getField() { return field; }
    public void setField(String field) { this.field = field; }
    public ChangeType getChangeType() { return changeType; }
    public void setChangeType(ChangeType changeType) { this.changeType = changeType; }
    public String getOldValue() { return oldValue; }
    public void setOldValue(String oldValue) { this.oldValue = oldValue; }
    public String getNewValue() { return newValue; }
    public void setNewValue(String newValue) { this.newValue = newValue; }
}
