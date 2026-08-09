package vnpt.vsp.module.tournament.dto;

import vnpt.vsp.module.tournament.entity.TechnicalEntry;

import java.util.UUID;

/** A measurement already on record, so the board can be reopened and corrected. */
public record TechnicalEntryResponse(
        UUID tournamentPlayerId,
        String prizeCode,
        int holeNumber,
        double measurement) {

    public static TechnicalEntryResponse fromEntity(TechnicalEntry e) {
        return new TechnicalEntryResponse(
                e.getPlayer().getId(),
                e.getPrizeCode(),
                e.getHoleNumber(),
                e.getMeasurement().doubleValue());
    }
}
