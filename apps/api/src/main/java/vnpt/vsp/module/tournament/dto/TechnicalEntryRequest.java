package vnpt.vsp.module.tournament.dto;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * A measurement off the on-course board.
 *
 * "BTC sẽ có bảng ghi thành tích trên sân" — nearest-to-pin and longest-drive
 * are written down by the players as they pass, so these arrive independently
 * of the scorecards and often earlier.
 */
public record TechnicalEntryRequest(
        UUID tournamentPlayerId,
        String prizeCode,
        Integer holeNumber,
        BigDecimal measurement) {
}
