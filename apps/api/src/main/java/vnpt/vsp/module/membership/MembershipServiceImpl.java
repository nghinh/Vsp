package vnpt.vsp.module.membership;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@MembershipModule
public class MembershipServiceImpl implements MembershipService {

    @Override
    public Optional<Membership> getMembership(String membershipId) {
        return Optional.empty();
    }

    @Override
    public List<Membership> getMembershipsForUser(String userId) {
        return List.of();
    }

    @Override
    public List<MembershipPlan> getAvailablePlans() {
        return List.of();
    }

    @Override
    public Optional<MembershipPlan> getPlan(String planId) {
        return Optional.empty();
    }

    @Override
    public boolean hasEntitlement(String userId, String courseId, String entitlement) {
        return false;
    }
}
