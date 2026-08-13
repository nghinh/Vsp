package vnpt.vsp.module.course;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.course.dto.ScorecardDto;
import vnpt.vsp.module.course.entity.Scorecard;
import vnpt.vsp.module.course.entity.ScorecardHole;
import vnpt.vsp.module.course.entity.ScorecardSegment;
import vnpt.vsp.module.course.entity.ScorecardTee;
import vnpt.vsp.module.course.entity.ScorecardTeeYardage;
import vnpt.vsp.module.course.repository.ScorecardRepository;
import vnpt.vsp.module.course.repository.ScorecardTeeRepository;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/** Reads published cards. */
@Service
public class ScorecardQueryService {

    private final ScorecardRepository scorecardRepository;
    private final ScorecardTeeRepository scorecardTeeRepository;

    public ScorecardQueryService(
            ScorecardRepository scorecardRepository,
            ScorecardTeeRepository scorecardTeeRepository) {
        this.scorecardRepository = scorecardRepository;
        this.scorecardTeeRepository = scorecardTeeRepository;
    }

    @Transactional(readOnly = true)
    public List<ScorecardDto> byFacility(Long facilityId) {
        List<Scorecard> cards = scorecardRepository.findByFacilityId(facilityId);
        Map<Long, List<ScorecardTee>> tees = teesOf(cards);
        return cards.stream()
                .map(card -> toDto(card, tees.getOrDefault(card.getId(), List.of())))
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
                // The tees are fetched for the one card that matched, after the
                // filter rather than before it. This runs once per hole a
                // golfer writes down, and the pairing they are playing is one
                // card out of the club's several.
                .map(card -> toDto(card, teesOf(List.of(card)).getOrDefault(card.getId(), List.of())));
    }

    private List<Long> segmentCourseIds(Scorecard card) {
        return card.getSegments().stream()
                .sorted(Comparator.comparingInt(ScorecardSegment::getPosition))
                .map(ScorecardSegment::getCourseId)
                .toList();
    }

    /**
     * The tee rows of every one of these cards, keyed by the card they belong
     * to, in one query.
     *
     * <p>Deliberately not {@code card.getTees()}: that collection is lazy and
     * so is each tee's yardages, so walking to them would cost a query per card
     * and a query per tee. Grouping the one flat answer here keeps the cost the
     * same whether the club has published one card or ten.
     */
    private Map<Long, List<ScorecardTee>> teesOf(List<Scorecard> cards) {
        if (cards.isEmpty()) {
            return Map.of();
        }
        List<Long> cardIds = cards.stream().map(Scorecard::getId).toList();
        return scorecardTeeRepository.findWithYardagesByScorecardIdIn(cardIds).stream()
                .collect(Collectors.groupingBy(
                        tee -> tee.getScorecard().getId(),
                        LinkedHashMap::new,
                        Collectors.toList()));
    }

    private ScorecardDto toDto(Scorecard card, List<ScorecardTee> tees) {
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
                        .toList(),
                tees.stream().map(ScorecardQueryService::toTeeDto).toList());
    }

    private static ScorecardDto.Tee toTeeDto(ScorecardTee tee) {
        return new ScorecardDto.Tee(
                tee.getName(),
                tee.getCourseRating(),
                tee.getSlopeRating(),
                tee.getYardages().stream()
                        .sorted(Comparator.comparingInt(ScorecardTeeYardage::getHoleNumber))
                        .map(y -> new ScorecardDto.Yardage(y.getHoleNumber(), y.getYards()))
                        .toList());
    }
}
