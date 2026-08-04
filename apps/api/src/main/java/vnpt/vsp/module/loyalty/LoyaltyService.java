package vnpt.vsp.module.loyalty;

/**
 * Loyalty module public service interface.
 * Exposes loyalty account and points operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 *
 * Boundary rule: This service must not accept RoundModule or ScoreModule types.
 */
public interface LoyaltyService {

    /**
     * Get a loyalty account by ID.
     *
     * @param accountId the account identifier
     * @return the account or empty if not found
     */
    java.util.Optional<LoyaltyAccount> getAccount(String accountId);

    /**
     * Get a loyalty account for a user.
     *
     * @param userId the user identifier
     * @return the account or empty if not found
     */
    java.util.Optional<LoyaltyAccount> getAccountByUser(String userId);

    /**
     * Get transaction history for an account.
     *
     * @param accountId the account identifier
     * @return list of transactions
     */
    java.util.List<LoyaltyTransaction> getTransactionHistory(String accountId);

    /**
     * Earn points for a user.
     *
     * @param userId the user identifier
     * @param points number of points to earn
     * @param source the source of the points (e.g., "booking", "purchase")
     * @return the updated account
     */
    LoyaltyAccount earnPoints(String userId, int points, String source);

    /**
     * Redeem points for a user.
     *
     * @param userId the user identifier
     * @param points number of points to redeem
     * @param rewardId the reward identifier
     * @return the updated account
     */
    LoyaltyAccount redeemPoints(String userId, int points, String rewardId);

    /**
     * Loyalty account entity.
     */
    class LoyaltyAccount {
        private String accountId;
        private String userId;
        private int pointsBalance;
        private int lifetimePoints;
        private String tier;

        public String getAccountId() { return accountId; }
        public void setAccountId(String accountId) { this.accountId = accountId; }
        public String getUserId() { return userId; }
        public void setUserId(String userId) { this.userId = userId; }
        public int getPointsBalance() { return pointsBalance; }
        public void setPointsBalance(int pointsBalance) { this.pointsBalance = pointsBalance; }
        public int getLifetimePoints() { return lifetimePoints; }
        public void setLifetimePoints(int lifetimePoints) { this.lifetimePoints = lifetimePoints; }
        public String getTier() { return tier; }
        public void setTier(String tier) { this.tier = tier; }
    }

    /**
     * Loyalty transaction entity.
     */
    class LoyaltyTransaction {
        private String transactionId;
        private String accountId;
        private int points;
        private String type;
        private String source;
        private java.time.Instant timestamp;

        public String getTransactionId() { return transactionId; }
        public void setTransactionId(String transactionId) { this.transactionId = transactionId; }
        public String getAccountId() { return accountId; }
        public void setAccountId(String accountId) { this.accountId = accountId; }
        public int getPoints() { return points; }
        public void setPoints(int points) { this.points = points; }
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
        public String getSource() { return source; }
        public void setSource(String source) { this.source = source; }
        public java.time.Instant getTimestamp() { return timestamp; }
        public void setTimestamp(java.time.Instant timestamp) { this.timestamp = timestamp; }
    }
}