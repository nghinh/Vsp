package vnpt.vsp.module.course.dto;

import java.util.List;

/** A published card, as the phone and the portal read it. */
public record ScorecardDto(
        Long scorecardId,
        Long facilityId,
        String name,
        Integer holesCount,
        Integer parTotal,
        List<Long> segmentCourseIds,
        List<Line> holes) {

    /** One numbered line: the hole the golfer counts, its par and its index. */
    public record Line(Integer hole, Integer par, Integer strokeIndex) {}
}
