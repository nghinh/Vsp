package vnpt.vsp.module.membership;

import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory implementation of {@link MembershipService}.
 *
 * <p>Per Story 12.2: membership is a customer-operations boundary module that must not
 * couple to the round/score modules (verified by {@code MembershipBoundaryTest}). Plans
 * are seeded deterministically and member records are held in-memory; the membership
 * system of record is the integration seam and is out of scope for the platform core.
 *
 * <p>{@link #hasEntitlement(String, String, String)} resolves an entitlement from the
 * user's active memberships and their plan grants, honouring course scoping.
 */
@Service
@MembershipModule
public class MembershipServiceImpl implements MembershipService {

    private final Map<String, MembershipPlan> plansById = new LinkedHashMap<>();
    private final ConcurrentHashMap<String, Membership> membershipsById = new ConcurrentHashMap<>();

    public MembershipServiceImpl() {
        seedPlans();
    }

    private void seedPlans() {
        plansById.put("plan-standard", plan("plan-standard", "Standard", "SILVER",
                List.of("booking", "leaderboard"), 0.0));
        plansById.put("plan-premium", plan("plan-premium", "Premium", "GOLD",
                List.of("booking", "leaderboard", "advanced-analytics", "priority-tee-times"), 10.0));
        plansById.put("plan-elite", plan("plan-elite", "Elite", "PLATINUM",
                List.of("booking", "leaderboard", "advanced-analytics", "priority-tee-times", "guest-passes"), 20.0));
    }

    @Override
    public Optional<Membership> getMembership(String membershipId) {
        return Optional.ofNullable(membershipsById.get(membershipId));
    }

    @Override
    public List<Membership> getMembershipsForUser(String userId) {
        List<Membership> out = new ArrayList<>();
        for (Membership m : membershipsById.values()) {
            if (m.getUserId() != null && m.getUserId().equals(userId)) {
                out.add(m);
            }
        }
        return out;
    }

    @Override
    public List<MembershipPlan> getAvailablePlans() {
        return List.copyOf(plansById.values());
    }

    @Override
    public Optional<MembershipPlan> getPlan(String planId) {
        return Optional.ofNullable(plansById.get(planId));
    }

    @Override
    public boolean hasEntitlement(String userId, String courseId, String entitlement) {
        if (userId == null || entitlement == null) {
            return false;
        }
        Instant now = Instant.now();
        for (Membership m : getMembershipsForUser(userId)) {
            if (!isActive(m, now)) {
                continue;
            }
            // Course-scoped memberships only grant entitlements for their course
            // (null membership courseId means a global membership).
            if (m.getCourseId() != null && courseId != null && !m.getCourseId().equals(courseId)) {
                continue;
            }
            if (grants(m, entitlement)) {
                return true;
            }
        }
        return false;
    }

    // ─── Test / integration seam ───────────────────────────────────────────

    /**
     * Registers a membership record (used by the membership provisioning seam and
     * tests). Kept package-visible-plus-public so callers within the module boundary
     * can seed state without crossing into round/score modules.
     */
    public Membership register(Membership membership) {
        if (membership.getMembershipId() == null) {
            membership.setMembershipId(java.util.UUID.randomUUID().toString());
        }
        if (membership.getStatus() == null) {
            membership.setStatus("ACTIVE");
        }
        membershipsById.put(membership.getMembershipId(), membership);
        return membership;
    }

    private boolean isActive(Membership m, Instant now) {
        if (m.getStatus() != null && !m.getStatus().equalsIgnoreCase("ACTIVE")) {
            return false;
        }
        if (m.getEffectiveDate() != null && now.isBefore(m.getEffectiveDate())) {
            return false;
        }
        if (m.getExpiryDate() != null && now.isAfter(m.getExpiryDate())) {
            return false;
        }
        return true;
    }

    private boolean grants(Membership m, String entitlement) {
        if (m.getEntitlements() != null && m.getEntitlements().contains(entitlement)) {
            return true;
        }
        MembershipPlan plan = m.getPlanId() != null ? plansById.get(m.getPlanId()) : null;
        return plan != null && plan.getEntitlements() != null && plan.getEntitlements().contains(entitlement);
    }

    private MembershipPlan plan(String id, String name, String tier, List<String> entitlements, Double discount) {
        MembershipPlan p = new MembershipPlan();
        p.setPlanId(id);
        p.setName(name);
        p.setTier(tier);
        p.setEntitlements(entitlements);
        p.setBookingDiscountPercent(discount);
        return p;
    }
}
