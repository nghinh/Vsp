package vnpt.vsp.module.bag;

import org.junit.jupiter.api.Test;
import vnpt.vsp.module.bag.entity.Club;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The set a bag starts with, and what it is allowed to claim.
 *
 * <p>Seeding distances is the useful half of this feature and the dangerous
 * half: once written, a carry from a table is indistinguishable from one a
 * golfer measured. Everything asserted here is about keeping the two apart.
 */
class StandardBagTest {

    @Test
    void isALegalBag() {
        assertThat(StandardBag.clubs()).hasSize(14);
    }

    /// The bag is read longest-first by the club chooser, which relies on it.
    @Test
    void runsLongestToShortest() {
        var carries = StandardBag.clubs().stream()
                .map(StandardBag.Standard::carryMeters).toList();

        assertThat(carries).isSortedAccordingTo((a, b) -> Double.compare(b, a));
    }

    /// A putter carries nothing. Giving it a distance would put it in the
    /// running for an approach shot.
    @Test
    void thePutterCarriesNothing() {
        var putter = StandardBag.clubs().stream()
                .filter(c -> c.type() == Club.ClubType.PUTTER)
                .findFirst().orElseThrow();

        assertThat(putter.carryMeters()).isZero();
    }

    /// ClubType stops at IRON, so eight irons would be eight rows all reading
    /// "IRON" — which tells a golfer nothing about which one to hit.
    @Test
    void namesAnIronByItsLoftRatherThanItsType() {
        assertThat(StandardBag.nameFor(Club.ClubType.IRON, 34.0)).isEqualTo("Sắt 7");
        assertThat(StandardBag.nameFor(Club.ClubType.IRON, 27.0)).isEqualTo("Sắt 5");
        assertThat(StandardBag.nameFor(Club.ClubType.WEDGE, 54.0)).isEqualTo("Sand wedge");
    }

    /// A loft the standard set does not describe — a golfer's own 2-iron —
    /// reads as an iron rather than being forced into the nearest name.
    @Test
    void fallsBackToTheTypeForAClubTheSetDoesNotDescribe() {
        assertThat(StandardBag.nameFor(Club.ClubType.IRON, 18.0)).isEqualTo("Sắt");
        assertThat(StandardBag.nameFor(Club.ClubType.IRON, null)).isEqualTo("Sắt");
    }

    /// Neighbouring irons are three or four degrees apart, so a club within two
    /// of a standard one is that club.
    @Test
    void toleratesTheLoftBeingALittleOff() {
        assertThat(StandardBag.nameFor(Club.ClubType.IRON, 35.5)).isEqualTo("Sắt 7");
    }
}
