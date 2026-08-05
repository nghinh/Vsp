package vnpt.vsp.module.loyalty;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for the in-memory {@link LoyaltyServiceImpl} — Story 12.2.
 */
class LoyaltyServiceImplTest {

    private LoyaltyServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new LoyaltyServiceImpl();
    }

    @Test
    void earnPoints_createsAccountAndAccrues() {
        LoyaltyService.LoyaltyAccount account = service.earnPoints("user-1", 500, "booking");
        assertEquals(500, account.getPointsBalance());
        assertEquals(500, account.getLifetimePoints());
        assertEquals("BRONZE", account.getTier());
        assertTrue(service.getAccountByUser("user-1").isPresent());
        assertEquals(1, service.getTransactionHistory(account.getAccountId()).size());
    }

    @Test
    void earnPoints_tierUpgradesWithLifetime() {
        service.earnPoints("user-2", 1500, "purchase");
        assertEquals("SILVER", service.getAccountByUser("user-2").orElseThrow().getTier());
        service.earnPoints("user-2", 4000, "purchase");
        assertEquals("GOLD", service.getAccountByUser("user-2").orElseThrow().getTier());
        service.earnPoints("user-2", 5000, "purchase");
        assertEquals("PLATINUM", service.getAccountByUser("user-2").orElseThrow().getTier());
    }

    @Test
    void redeemPoints_decrementsBalanceButNotLifetime() {
        service.earnPoints("user-3", 1000, "booking");
        LoyaltyService.LoyaltyAccount account = service.redeemPoints("user-3", 300, "reward-x");
        assertEquals(700, account.getPointsBalance());
        assertEquals(1000, account.getLifetimePoints());
        assertEquals(2, service.getTransactionHistory(account.getAccountId()).size());
    }

    @Test
    void redeemPoints_insufficientBalance_throws() {
        service.earnPoints("user-4", 100, "booking");
        assertThrows(IllegalStateException.class, () -> service.redeemPoints("user-4", 500, "reward"));
    }

    @Test
    void redeemPoints_unknownUser_throws() {
        assertThrows(IllegalStateException.class, () -> service.redeemPoints("ghost", 10, "reward"));
    }

    @Test
    void earnPoints_nonPositive_throws() {
        assertThrows(IllegalArgumentException.class, () -> service.earnPoints("u", 0, "booking"));
    }

    @Test
    void getAccountById_resolvesFromUserAccount() {
        LoyaltyService.LoyaltyAccount account = service.earnPoints("user-5", 50, "booking");
        assertTrue(service.getAccount(account.getAccountId()).isPresent());
        assertEquals("user-5", service.getAccount(account.getAccountId()).orElseThrow().getUserId());
    }
}
