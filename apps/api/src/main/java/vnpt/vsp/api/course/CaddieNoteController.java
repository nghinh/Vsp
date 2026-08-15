package vnpt.vsp.api.course;

import jakarta.persistence.EntityManager;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * The golfer's own book of caddies, per club.
 *
 * <p>Vietnamese courses require a caddie and golfers ask for good ones back by
 * number at the desk — the photographed cards come in with caddie numbers
 * written in the corner. This is that memory, kept.
 *
 * <p>Private by construction: every query is scoped to the authenticated
 * account. It is a notebook, not a review site — a public one would invite
 * disputes over people whose livelihood is tips.
 */
@RestController
@Validated
public class CaddieNoteController {

    private final EntityManager em;

    public CaddieNoteController(EntityManager em) {
        this.em = em;
    }

    public record CaddieNote(
            String caddieNumber, String name, Integer rating, String note,
            Instant updatedAt) {}

    public record SaveCaddieRequest(
            @Size(max = 100) String name,
            @Min(1) @Max(5) Integer rating,
            @Size(max = 2000) String note) {}

    @GetMapping("/facilities/{facilityId}/caddies")
    @Transactional(readOnly = true)
    public List<CaddieNote> mine(Authentication auth, @PathVariable Long facilityId) {
        Long golferId = (Long) auth.getPrincipal();
        @SuppressWarnings("unchecked")
        List<Object[]> rows = em.createNativeQuery("""
                SELECT caddie_number, name, rating, note, updated_at
                FROM caddie_notes
                WHERE golfer_account_id = :golfer AND facility_id = :facility
                ORDER BY rating DESC NULLS LAST, updated_at DESC
                """)
                .setParameter("golfer", golferId)
                .setParameter("facility", facilityId)
                .getResultList();
        return rows.stream().map(r -> new CaddieNote(
                (String) r[0], (String) r[1],
                r[2] == null ? null : ((Number) r[2]).intValue(),
                (String) r[3],
                r[4] == null ? null : ((java.sql.Timestamp) r[4]).toInstant()))
                .toList();
    }

    /** Upsert: remembering the same caddie twice updates the memory. */
    @PutMapping("/facilities/{facilityId}/caddies/{caddieNumber}")
    @Transactional
    public ResponseEntity<Map<String, String>> save(
            Authentication auth,
            @PathVariable Long facilityId,
            @PathVariable @NotBlank @Size(max = 20) String caddieNumber,
            @Valid @RequestBody SaveCaddieRequest request) {
        Long golferId = (Long) auth.getPrincipal();
        em.createNativeQuery("""
                INSERT INTO caddie_notes
                    (golfer_account_id, facility_id, caddie_number, name, rating, note)
                VALUES (:golfer, :facility, :number, :name, :rating, :note)
                ON CONFLICT (golfer_account_id, facility_id, caddie_number)
                DO UPDATE SET name = EXCLUDED.name, rating = EXCLUDED.rating,
                              note = EXCLUDED.note, updated_at = now()
                """)
                .setParameter("golfer", golferId)
                .setParameter("facility", facilityId)
                .setParameter("number", caddieNumber)
                .setParameter("name", request.name())
                .setParameter("rating", request.rating())
                .setParameter("note", request.note())
                .executeUpdate();
        return ResponseEntity.ok(Map.of("caddieNumber", caddieNumber));
    }

    @DeleteMapping("/facilities/{facilityId}/caddies/{caddieNumber}")
    @Transactional
    public ResponseEntity<Void> forget(
            Authentication auth,
            @PathVariable Long facilityId,
            @PathVariable String caddieNumber) {
        Long golferId = (Long) auth.getPrincipal();
        em.createNativeQuery("""
                DELETE FROM caddie_notes
                WHERE golfer_account_id = :golfer AND facility_id = :facility
                  AND caddie_number = :number
                """)
                .setParameter("golfer", golferId)
                .setParameter("facility", facilityId)
                .setParameter("number", caddieNumber)
                .executeUpdate();
        return ResponseEntity.noContent().build();
    }
}
