package vnpt.vsp.module.correction.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * A club's printed card, as a golfer read it off the photograph.
 *
 * <p>Submitted whole. The alternative — a correction per hole — would be
 * eighteen queue items and eighteen decisions about one piece of evidence,
 * and a reviewer who approved half of them would leave the card inconsistent
 * with itself.
 */
public record ScorecardSubmissionRequest(

        /// What the club titles this card: "A + B", "King's Course".
        @NotNull @Size(max = 255) String name,

        /// The đường this card was printed for, in the order it lists them.
        @NotEmpty @Size(min = 1, max = 2) List<Long> segmentCourseIds,

        /// Every numbered line on the card.
        @NotEmpty @Size(min = 9, max = 18) List<HoleLine> holes,

        /// A photograph of the card. The reviewer decides on the evidence,
        /// not on the typing.
        String evidenceUrl,

        String note) {

    public record HoleLine(
            @NotNull @Min(1) @Max(18) Integer hole,
            @NotNull @Min(3) @Max(6) Integer par,
            @Min(1) @Max(18) Integer strokeIndex) {}
}
