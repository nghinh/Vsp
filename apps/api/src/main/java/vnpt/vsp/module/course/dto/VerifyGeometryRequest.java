package vnpt.vsp.module.course.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * The holes a reviewer confirms, and why.
 *
 * <p>Holes are listed explicitly rather than implied by the course. Verifying
 * a whole course from one button would make VERIFIED mean "somebody pressed a
 * button"; listing the holes makes it mean "somebody looked at these".</p>
 *
 * @param holeNumbers holes the reviewer confirms
 * @param note        why — carried into the audit record
 */
public record VerifyGeometryRequest(
        @NotEmpty(message = "holeNumbers must not be empty")
        List<Integer> holeNumbers,

        @NotBlank(message = "note is required")
        @Size(min = 10, message = "note must be at least 10 characters")
        String note
) {}
