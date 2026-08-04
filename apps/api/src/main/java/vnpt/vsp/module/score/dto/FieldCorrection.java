package vnpt.vsp.module.score.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Single field correction as part of a ScoreCorrectionRequest.
 */
public class FieldCorrection {

    @NotBlank(message = "field is required")
    private String field;

    @NotNull(message = "holeNumber is required")
    private Integer holeNumber;

    @NotBlank(message = "oldValue is required")
    private String oldValue;

    @NotBlank(message = "newValue is required")
    private String newValue;

    public FieldCorrection() {}

    public FieldCorrection(String field, Integer holeNumber, String oldValue, String newValue) {
        this.field = field;
        this.holeNumber = holeNumber;
        this.oldValue = oldValue;
        this.newValue = newValue;
    }

    public String getField() { return field; }
    public void setField(String field) { this.field = field; }
    public Integer getHoleNumber() { return holeNumber; }
    public void setHoleNumber(Integer holeNumber) { this.holeNumber = holeNumber; }
    public String getOldValue() { return oldValue; }
    public void setOldValue(String oldValue) { this.oldValue = oldValue; }
    public String getNewValue() { return newValue; }
    public void setNewValue(String newValue) { this.newValue = newValue; }
}
