package vnpt.vsp.module.correction.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
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

        /// The tee rows, when the card prints them and the golfer kept them.
        /// Optional: a card photographed with its rating table outside the
        /// frame is still a card worth having, and holding one back for the
        /// sake of the yardages would cost the pars and indexes too.
        @Size(max = 10) List<TeeLine> tees,

        /// A photograph of the card. The reviewer decides on the evidence,
        /// not on the typing.
        String evidenceUrl,

        String note) {

    public record HoleLine(
            @NotNull @Min(1) @Max(18) Integer hole,
            @NotNull @Min(3) @Max(6) Integer par,
            @Min(1) @Max(18) Integer strokeIndex,

            /// The ladies index row, where the card prints a second one. A
            /// hole's difficulty ranking changes with the distance played, so
            /// many Vietnamese cards rank the eighteen twice. Null means the
            /// card printed one row, not that women play the hole unranked.
            @Min(1) @Max(18) Integer strokeIndexLadies) {

        /// Cards read before the second index row was asked for.
        public HoleLine(Integer hole, Integer par, Integer strokeIndex) {
            this(hole, par, strokeIndex, null);
        }
    }

    /**
     * One tee row. The ranges are the database's, restated here so a bad
     * number is refused at the edge with the field named, rather than as a
     * constraint violation three layers in.
     */
    public record TeeLine(
            @NotNull @Size(min = 1, max = 60) String name,

            /// A rated course sits near its par; anything outside this is a
            /// slope read from the wrong column.
            @DecimalMin("60.0") @DecimalMax("80.0") BigDecimal courseRating,

            @Min(55) @Max(155) Integer slopeRating,

            /// Whose rating this row carries: MEN, LADIES or UNSPECIFIED.
            ///
            /// A course is rated separately for men and for women, and a card
            /// that prints ratings prints both — commonly as two rows against
            /// the same tee colour. Without this the second was dropped as a
            /// duplicate name, silently, along with its ratings.
            ///
            /// Null reads as UNSPECIFIED, which is what most cards are. It is
            /// not a synonym for men's.
            @Size(max = 16) String gender,

            /// What the card prints in this row's OUT, IN and TOTAL columns.
            ///
            /// Not stored — the yardages are the data, these are the club's own
            /// arithmetic for checking them against. They travel with the card
            /// so the reviewer sees the contradiction rather than a total the
            /// portal computed from the very numbers in question: a 3 misread
            /// as an 8 sums to a figure in perfect agreement with itself.
            ///
            /// A nine is 60-700 a hole, so 540 to 6,300; a card's total is two
            /// of those.
            @Min(540) @Max(6300) Integer yardsOut,
            @Min(540) @Max(6300) Integer yardsIn,
            @Min(1080) @Max(12600) Integer yardsTotal,

            @Size(max = 18) List<Yardage> yardages) {}

    public record Yardage(
            @NotNull @Min(1) @Max(18) Integer hole,
            @NotNull @Min(60) @Max(700) Integer yards) {}
}
