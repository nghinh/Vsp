package vnpt.vsp.module.bag.dto;

import jakarta.validation.constraints.Size;

/**
 * Request DTO for updating a golf bag.
 * Per Story 2.4 AC-2: isActive flag can be set to promote a bag as active.
 */
public class UpdateGolfBagRequest {

    @Size(max = 255, message = "Bag name must be at most 255 characters")
    private String name;

    private Boolean isActive;

    public UpdateGolfBagRequest() {}

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }
}
