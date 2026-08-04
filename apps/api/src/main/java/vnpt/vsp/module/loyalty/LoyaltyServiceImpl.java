package vnpt.vsp.module.loyalty;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@LoyaltyModule
public class LoyaltyServiceImpl implements LoyaltyService {

    @Override
    public Optional<LoyaltyAccount> getAccount(String accountId) {
        return Optional.empty();
    }

    @Override
    public Optional<LoyaltyAccount> getAccountByUser(String userId) {
        return Optional.empty();
    }

    @Override
    public List<LoyaltyTransaction> getTransactionHistory(String accountId) {
        return List.of();
    }

    @Override
    public LoyaltyAccount earnPoints(String userId, int points, String source) {
        throw new UnsupportedOperationException("Earning loyalty points is not implemented");
    }

    @Override
    public LoyaltyAccount redeemPoints(String userId, int points, String rewardId) {
        throw new UnsupportedOperationException("Redeeming loyalty points is not implemented");
    }
}
