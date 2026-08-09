package vnpt.vsp.module.tournament.dto;

/**
 * One line of the flight sheet.
 *
 * Mirrors the columns the club already keeps — "Họ và tên", "Handicap xét
 * giải", "Nhóm", "Mã VGA", and the FLY the row sits under — so an organiser
 * can paste the sheet rather than retype it.
 *
 * {@code divisionCode} is optional: left out, the outing's configured division
 * boundaries decide it. Sent, it wins, because the sheet is the record and an
 * organiser sometimes places a player by hand.
 */
public record OutingRosterEntryRequest(
        String displayName,
        String vgaCode,
        Double handicap,
        String divisionCode,
        Integer flightNumber,
        /** Golfer account, when this player has one. */
        Long playerId) {
}
