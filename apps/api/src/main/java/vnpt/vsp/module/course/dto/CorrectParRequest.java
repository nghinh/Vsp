package vnpt.vsp.module.course.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Par corrections a reviewer is making from the course's scorecard.
 *
 * <p>Separate from geometry verification on purpose. Coordinates are checked by
 * looking at a map; par is checked by reading a scorecard. Merging them would
 * let one click assert two different kinds of knowledge, and the audit trail
 * could no longer say which one the reviewer actually had.</p>
 *
 * @param holes the holes to correct and their par
 * @param note  where the reviewer got these — carried into the audit record
 */
public record CorrectParRequest(
        @NotEmpty(message = "holes must not be empty")
        @Valid
        List<HolePar> holes,

        @NotBlank(message = "note is required")
        @Size(min = 10, message = "note must be at least 10 characters")
        String note
) {

    /**
     * @param holeNumber hole on the card
     * @param par        3–6. Anything else is not a golf hole's par, and the
     *                   seed's zeros are what taught this codebase to check.
     */
    public record HolePar(
            @NotNull(message = "holeNumber is required")
            Integer holeNumber,

            @NotNull(message = "par is required")
            @Min(value = 3, message = "par must be between 3 and 6")
            @Max(value = 6, message = "par must be between 3 and 6")
            Integer par
    ) {}
}
