package vnpt.vsp.api.course;

import jakarta.persistence.EntityManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The stroke indexes of one course, as a flat map.
 *
 * <p>Exists for the games engine on the phone. Giving strokes in a match is
 * the entire reason a stroke index is printed on a card — handicap 20 gets a
 * second stroke on the two hardest holes, and the index is what ranks them —
 * and the engine needs all eighteen at once, offline-cacheable, without
 * dragging the whole scorecard DTO across for a lookup table.
 */
@RestController
public class StrokeIndexController {

    private final EntityManager em;

    public StrokeIndexController(EntityManager em) {
        this.em = em;
    }

    /**
     * hole number → stroke index, for the holes that have one.
     *
     * <p>An empty map is an answer, not an error: half the country's cards
     * publish no index row, and the engine falls back to gross games rather
     * than inventing an allocation.
     */
    @GetMapping("/courses/{courseId}/stroke-indexes")
    @Transactional(readOnly = true)
    public Map<Integer, Integer> strokeIndexes(@PathVariable Long courseId) {
        @SuppressWarnings("unchecked")
        List<Object[]> rows = em.createNativeQuery("""
                SELECT sh.hole_number, sh.stroke_index
                FROM scorecards s
                JOIN scorecard_segments g ON g.scorecard_id = s.id
                JOIN scorecard_holes sh ON sh.scorecard_id = s.id
                WHERE g.course_id = :course AND sh.stroke_index IS NOT NULL
                ORDER BY sh.hole_number
                """).setParameter("course", courseId).getResultList();

        Map<Integer, Integer> indexes = new LinkedHashMap<>();
        for (Object[] r : rows) {
            indexes.put(((Number) r[0]).intValue(), ((Number) r[1]).intValue());
        }
        return indexes;
    }
}
