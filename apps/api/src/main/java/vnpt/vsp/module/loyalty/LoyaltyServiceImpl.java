package vnpt.vsp.module.loyalty;

import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * In-memory implementation of {@link LoyaltyService}.
 *
 * <p>Per Story 12.2: loyalty is a customer-operations boundary module. It owns its
 * own account/points state and deliberately shares no types with the round or score
 * modules (verified by {@code LoyaltyBoundaryTest}). Persistence is in-memory — the
 * B2B2C loyalty ledger backing store (or an external loyalty provider) is the
 * integration seam and is out of scope for the platform core.
 *
 * <p>Points and tiers follow a simple, deterministic model so the endpoints are fully
 * functional for client integration and testing.
 */
@Service
@LoyaltyModule
public class LoyaltyServiceImpl implements LoyaltyService {

    private final ConcurrentHashMap<String, LoyaltyAccount> accountsByUser = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, String> userIdByAccountId = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, List<LoyaltyTransaction>> transactionsByAccount = new ConcurrentHashMap<>();

    @Override
    public Optional<LoyaltyAccount> getAccount(String accountId) {
        String userId = userIdByAccountId.get(accountId);
        return userId != null ? Optional.ofNullable(accountsByUser.get(userId)) : Optional.empty();
    }

    @Override
    public Optional<LoyaltyAccount> getAccountByUser(String userId) {
        return Optional.ofNullable(accountsByUser.get(userId));
    }

    @Override
    public List<LoyaltyTransaction> getTransactionHistory(String accountId) {
        return List.copyOf(transactionsByAccount.getOrDefault(accountId, List.of()));
    }

    @Override
    public synchronized LoyaltyAccount earnPoints(String userId, int points, String source) {
        if (points <= 0) {
            throw new IllegalArgumentException("Points to earn must be positive");
        }
        LoyaltyAccount account = accountsByUser.computeIfAbsent(userId, this::createAccount);
        account.setPointsBalance(account.getPointsBalance() + points);
        account.setLifetimePoints(account.getLifetimePoints() + points);
        account.setTier(tierForLifetime(account.getLifetimePoints()));
        recordTransaction(account, points, "EARN", source);
        return account;
    }

    @Override
    public synchronized LoyaltyAccount redeemPoints(String userId, int points, String rewardId) {
        if (points <= 0) {
            throw new IllegalArgumentException("Points to redeem must be positive");
        }
        LoyaltyAccount account = accountsByUser.get(userId);
        if (account == null) {
            throw new IllegalStateException("No loyalty account for user " + userId);
        }
        if (account.getPointsBalance() < points) {
            throw new IllegalStateException("Insufficient points balance");
        }
        account.setPointsBalance(account.getPointsBalance() - points);
        recordTransaction(account, -points, "REDEEM", rewardId);
        return account;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private LoyaltyAccount createAccount(String userId) {
        LoyaltyAccount account = new LoyaltyAccount();
        account.setAccountId(UUID.randomUUID().toString());
        account.setUserId(userId);
        account.setPointsBalance(0);
        account.setLifetimePoints(0);
        account.setTier(tierForLifetime(0));
        userIdByAccountId.put(account.getAccountId(), userId);
        transactionsByAccount.put(account.getAccountId(), new CopyOnWriteArrayList<>());
        return account;
    }

    private void recordTransaction(LoyaltyAccount account, int points, String type, String source) {
        LoyaltyTransaction tx = new LoyaltyTransaction();
        tx.setTransactionId(UUID.randomUUID().toString());
        tx.setAccountId(account.getAccountId());
        tx.setPoints(points);
        tx.setType(type);
        tx.setSource(source);
        tx.setTimestamp(Instant.now());
        transactionsByAccount
                .computeIfAbsent(account.getAccountId(), k -> new CopyOnWriteArrayList<>())
                .add(tx);
    }

    private String tierForLifetime(int lifetimePoints) {
        if (lifetimePoints >= 10000) return "PLATINUM";
        if (lifetimePoints >= 5000) return "GOLD";
        if (lifetimePoints >= 1000) return "SILVER";
        return "BRONZE";
    }
}
