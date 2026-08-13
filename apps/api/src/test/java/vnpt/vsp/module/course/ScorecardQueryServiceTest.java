package vnpt.vsp.module.course;

import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;
import vnpt.vsp.module.course.dto.ScorecardDto;
import vnpt.vsp.module.course.entity.Scorecard;
import vnpt.vsp.module.course.entity.ScorecardHole;
import vnpt.vsp.module.course.entity.ScorecardSegment;
import vnpt.vsp.module.course.entity.ScorecardTee;
import vnpt.vsp.module.course.entity.ScorecardTeeYardage;
import vnpt.vsp.module.course.repository.ScorecardRepository;
import vnpt.vsp.module.course.repository.ScorecardTeeRepository;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Reading a published card back, tee rows and all.
 *
 * <p>The tee rows were being written and never read. An approved correction
 * filled {@code scorecard_tees} and {@code scorecard_tee_yardages} on
 * production — course rating, slope and ninety yardages per card — and no query
 * anywhere touched them, so the golfer who photographed the card and the
 * reviewer who approved it both saw nothing come of it. These tests fail the
 * moment the read path stops carrying them.
 *
 * <p>Course rating and slope matter more than the yardages do: they are the
 * only ones in the database at all, since neither {@code courses} nor {@code
 * tee_sets} has a column for either, and without them a round cannot become a
 * handicap differential.
 */
@DataJpaTest(showSql = false, properties = "spring.jpa.properties.hibernate.generate_statistics=true")
@ActiveProfiles("test")
class ScorecardQueryServiceTest {

    @Autowired private ScorecardRepository scorecardRepository;
    @Autowired private ScorecardTeeRepository scorecardTeeRepository;
    @Autowired private TestEntityManager em;

    private ScorecardQueryService service;

    @BeforeEach
    void setUp() {
        service = new ScorecardQueryService(scorecardRepository, scorecardTeeRepository);
    }

    @Test
    @DisplayName("a card carries the rating, slope and yardages of every tee it prints")
    void cardCarriesItsTees() {
        Scorecard card = card(100L, "A + B", List.of(21L, 22L));
        tee(card, "GOLD", "72.4", 132, 18);
        tee(card, "RED", "69.1", 118, 18);
        flushAndClear();

        List<ScorecardDto> cards = service.byFacility(100L);

        assertThat(cards).hasSize(1);
        List<ScorecardDto.Tee> tees = cards.get(0).tees();
        assertThat(tees).extracting(ScorecardDto.Tee::name).containsExactly("GOLD", "RED");

        ScorecardDto.Tee gold = tees.get(0);
        assertThat(gold.courseRating()).isEqualByComparingTo("72.4");
        assertThat(gold.slopeRating()).isEqualTo(132);
        assertThat(gold.yardages()).hasSize(18);

        // Written back to front on purpose: the rows come out of the database in
        // no promised order, and a client that draws the card in the order it
        // was handed them would print hole 18's yardage against hole 1.
        assertThat(gold.yardages()).extracting(ScorecardDto.Yardage::hole)
                .containsExactlyElementsOf(holeNumbers());
        assertThat(gold.yardages().get(0).yards()).isEqualTo(300 + 1);
        assertThat(gold.yardages().get(17).yards()).isEqualTo(300 + 18);
    }

    @Test
    @DisplayName("a card the club published without a rating table still reads back")
    void cardWithoutTeesStillReads() {
        card(101L, "King's Course", List.of(31L));
        flushAndClear();

        List<ScorecardDto> cards = service.byFacility(101L);

        // A photograph taken with the rating table outside the frame is still a
        // card worth having for its pars and stroke indexes, so the absence has
        // to read as an empty list rather than blow up or drop the card.
        assertThat(cards).hasSize(1);
        assertThat(cards.get(0).tees()).isEmpty();
        assertThat(cards.get(0).holes()).hasSize(18);
    }

    @Test
    @DisplayName("the card matched to the đường being played carries its tees too")
    void pairingLookupCarriesTees() {
        Scorecard ab = card(102L, "A + B", List.of(41L, 42L));
        tee(ab, "BLUE", "71.2", 126, 18);
        Scorecard ac = card(102L, "A + C", List.of(41L, 43L));
        tee(ac, "BLACK", "73.8", 140, 18);
        flushAndClear();

        // The scoring path looks a card up by the pairing in the round. If only
        // the facility listing carried tees, the golfer part-way through A+C
        // could be told their pars and never their yardages.
        ScorecardDto matched = service.byPairing(102L, List.of(41L, 43L)).orElseThrow();

        assertThat(matched.name()).isEqualTo("A + C");
        assertThat(matched.tees()).singleElement()
                .satisfies(tee -> {
                    assertThat(tee.name()).isEqualTo("BLACK");
                    assertThat(tee.slopeRating()).isEqualTo(140);
                    assertThat(tee.yardages()).hasSize(18);
                });
    }

    @Test
    @DisplayName("listing a facility's cards costs the same however many tees they print")
    void teesDoNotCostAQueryEach() {
        for (int i = 1; i <= 3; i++) {
            tee(card(200L, "Card " + i, List.of(50L + i)), "WHITE", "70.0", 120, 18);
        }
        for (int i = 1; i <= 3; i++) {
            Scorecard card = card(201L, "Card " + i, List.of(60L + i));
            for (String name : List.of("BLACK", "BLUE", "WHITE", "RED")) {
                tee(card, name, "70.0", 120, 18);
            }
        }
        flushAndClear();

        // Two clubs with the same three cards; one prints four tees per card
        // where the other prints one. Walking the lazy collections would make
        // the second club cost fifteen more round trips than the first — a
        // hundred and eighty yardage rows fetched eighteen at a time — and the
        // endpoint would get slower every time a club published a fuller card,
        // which is the one thing it exists to encourage.
        long oneTeePerCard = statementsFor(200L);
        long fourTeesPerCard = statementsFor(201L);

        assertThat(fourTeesPerCard).isEqualTo(oneTeePerCard);
    }

    // ─── Fixtures ───────────────────────────────────────────────────────────

    private long statementsFor(long facilityId) {
        Statistics stats = em.getEntityManager().getEntityManagerFactory()
                .unwrap(SessionFactory.class).getStatistics();
        em.clear();
        stats.clear();
        service.byFacility(facilityId);
        return stats.getPrepareStatementCount();
    }

    private void flushAndClear() {
        em.flush();
        em.clear();
    }

    private Scorecard card(long facilityId, String name, List<Long> courseIds) {
        Scorecard card = new Scorecard();
        card.setFacilityId(facilityId);
        card.setName(name);
        card.setHolesCount(18);
        card.setParTotal(72);
        card.setPublisher("scorecard-query-test");
        em.persist(card);
        em.flush();

        for (int position = 0; position < courseIds.size(); position++) {
            card.getSegments().add(new ScorecardSegment(card, position, courseIds.get(position)));
        }
        for (int hole = 1; hole <= 18; hole++) {
            card.getHoles().add(new ScorecardHole(card, hole, hole % 3 == 0 ? 3 : 4, hole));
        }
        em.persist(card);
        em.flush();
        return card;
    }

    private void tee(Scorecard card, String name, String rating, Integer slope, int holes) {
        ScorecardTee tee = new ScorecardTee(card, name, new BigDecimal(rating), slope);
        em.persist(tee);
        em.flush();
        for (int hole = holes; hole >= 1; hole--) {
            tee.getYardages().add(new ScorecardTeeYardage(tee, hole, 300 + hole));
        }
        card.getTees().add(tee);
        em.flush();
    }

    private static List<Integer> holeNumbers() {
        return java.util.stream.IntStream.rangeClosed(1, 18).boxed().toList();
    }
}
