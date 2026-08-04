package vnpt.vsp.module.bag.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Request DTO for creating a new golf bag.
 */
public class CreateGolfBagRequest {

    @NotBlank(message = "Bag name is required")
    @Size(max = 255, message = "Bag name must be at most 255 characters")
    private String name;

    public CreateGolfBagRequest() {}

    public CreateGolfBagRequest(String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }
}
