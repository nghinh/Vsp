package vnpt.vsp.module.course;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.course.dto.ScorecardDto;
import vnpt.vsp.module.course.entity.Scorecard;
import vnpt.vsp.module.course.entity.ScorecardHole;
import vnpt.vsp.module.course.entity.ScorecardSegment;
import vnpt.vsp.module.course.repository.ScorecardRepository;

import java.util.Comparator;
import java.util.List;
import java.util.Optional;

/** Reads published cards. */
@Service
public class ScorecardQueryService {

    private final ScorecardRepository scorecardRepository;

    public ScorecardQueryService(ScorecardRepository scorecardRepository) {
        this.scorecardRepository = scorecardRepository;
    }

    @Transactional(readOnly = true)
    public List<ScorecardDto> byFacility(Long facilityId) {
        return scorecardRepository.findByFacilityId(facilityId).stream()
                .map(this::toDto)
                .toList();
    }

    /**
     * The card printed for exactly these đường, in this order.
     *
     * <p>Matched on the pairing rather than the name: the golfer picks A and
     * C, and what the club titled that card is not something the phone knows.
     * A club has a handful of cards, so the comparison is a loop rather than a
     * query that has to express ordered set equality in JPQL.
     */
    @Transactional(readOnly = true)
    public Optional<ScorecardDto> byPairing(Long facilityId, List<Long> courseIds) {
        return scorecardRepository.findByFacilityId(facilityId).stream()
                .filter(card -> segmentCourseIds(card).equals(courseIds))
                .findFirst()
                .map(this::toDto);
    }

    private List<Long> segmentCourseIds(Scorecard card) {
        return card.getSegments().stream()
                .sorted(Comparator.comparingInt(ScorecardSegment::getPosition))
                .map(ScorecardSegment::getCourseId)
                .toList();
    }

    private ScorecardDto toDto(Scorecard card) {
        return new ScorecardDto(
                card.getId(),
                card.getFacilityId(),
                card.getName(),
                card.getHolesCount(),
                card.getParTotal(),
                segmentCourseIds(card),
                card.getHoles().stream()
                        .sorted(Comparator.comparingInt(ScorecardHole::getHoleNumber))
                        .map(h -> new ScorecardDto.Line(h.getHoleNumber(), h.getPar(), h.getStrokeIndex()))
                        .toList());
    }
}
