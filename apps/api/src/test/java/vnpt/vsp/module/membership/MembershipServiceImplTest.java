package vnpt.vsp.module.membership;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for the in-memory {@link MembershipServiceImpl} — Story 12.2.
 */
class MembershipServiceImplTest {

    private MembershipServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new MembershipServiceImpl();
    }

    @Test
    void getAvailablePlans_returnsSeededPlans() {
        List<MembershipService.MembershipPlan> plans = service.getAvailablePlans();
        assertEquals(3, plans.size());
        assertTrue(service.getPlan("plan-premium").isPresent());
        assertTrue(service.getPlan("plan-premium").orElseThrow()
                .getEntitlements().contains("advanced-analytics"));
    }

    @Test
    void hasEntitlement_fromPlanGrant() {
        MembershipService.Membership m = new MembershipService.Membership();
        m.setUserId("user-1");
        m.setPlanId("plan-premium");
        service.register(m);

        assertTrue(service.hasEntitlement("user-1", null, "advanced-analytics"));
        assertFalse(service.hasEntitlement("user-1", null, "guest-passes"));
    }

    @Test
    void hasEntitlement_courseScopedMembership() {
        MembershipService.Membership m = new MembershipService.Membership();
        m.setUserId("user-2");
        m.setPlanId("plan-standard");
        m.setCourseId("course-A");
        service.register(m);

        assertTrue(service.hasEntitlement("user-2", "course-A", "booking"));
        assertFalse(service.hasEntitlement("user-2", "course-B", "booking"));
    }

    @Test
    void hasEntitlement_expiredMembership_denied() {
        MembershipService.Membership m = new MembershipService.Membership();
        m.setUserId("user-3");
        m.setPlanId("plan-elite");
        m.setExpiryDate(Instant.now().minus(1, ChronoUnit.DAYS));
        service.register(m);

        assertFalse(service.hasEntitlement("user-3", null, "booking"));
    }

    @Test
    void hasEntitlement_directGrantOnMembership() {
        MembershipService.Membership m = new MembershipService.Membership();
        m.setUserId("user-4");
        m.setEntitlements(List.of("special-access"));
        service.register(m);

        assertTrue(service.hasEntitlement("user-4", null, "special-access"));
    }

    @Test
    void getMembershipsForUser_returnsOnlyTheirs() {
        MembershipService.Membership m1 = new MembershipService.Membership();
        m1.setUserId("user-5");
        m1.setPlanId("plan-standard");
        service.register(m1);
        MembershipService.Membership m2 = new MembershipService.Membership();
        m2.setUserId("other");
        m2.setPlanId("plan-standard");
        service.register(m2);

        assertEquals(1, service.getMembershipsForUser("user-5").size());
    }

    @Test
    void hasEntitlement_unknownUser_false() {
        assertFalse(service.hasEntitlement("nobody", null, "booking"));
    }
}
