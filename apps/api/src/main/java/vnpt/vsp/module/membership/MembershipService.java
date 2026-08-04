package vnpt.vsp.module.membership;

/**
 * Membership module public service interface.
 * Exposes membership plan and entitlement operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 *
 * Boundary rule: This service must not accept RoundModule or ScoreModule types.
 */
public interface MembershipService {

    /**
     * Get a membership by ID.
     *
     * @param membershipId the membership identifier
     * @return the membership or empty if not found
     */
    java.util.Optional<Membership> getMembership(String membershipId);

    /**
     * Get memberships for a user.
     *
     * @param userId the user identifier
     * @return list of memberships
     */
    java.util.List<Membership> getMembershipsForUser(String userId);

    /**
     * Get available membership plans.
     *
     * @return list of available plans
     */
    java.util.List<MembershipPlan> getAvailablePlans();

    /**
     * Get a membership plan by ID.
     *
     * @param planId the plan identifier
     * @return the plan or empty if not found
     */
    java.util.Optional<MembershipPlan> getPlan(String planId);

    /**
     * Check if a user has a specific entitlement.
     *
     * @param userId the user identifier
     * @param courseId the course identifier (may be null for global entitlements)
     * @param entitlement the entitlement identifier
     * @return true if the user has the entitlement
     */
    boolean hasEntitlement(String userId, String courseId, String entitlement);

    /**
     * Membership entity.
     */
    class Membership {
        private String membershipId;
        private String userId;
        private String planId;
        private String courseId;
        private String status;
        private java.time.Instant effectiveDate;
        private java.time.Instant expiryDate;
        private java.util.List<String> entitlements;

        public String getMembershipId() { return membershipId; }
        public void setMembershipId(String membershipId) { this.membershipId = membershipId; }
        public String getUserId() { return userId; }
        public void setUserId(String userId) { this.userId = userId; }
        public String getPlanId() { return planId; }
        public void setPlanId(String planId) { this.planId = planId; }
        public String getCourseId() { return courseId; }
        public void setCourseId(String courseId) { this.courseId = courseId; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public java.time.Instant getEffectiveDate() { return effectiveDate; }
        public void setEffectiveDate(java.time.Instant effectiveDate) { this.effectiveDate = effectiveDate; }
        public java.time.Instant getExpiryDate() { return expiryDate; }
        public void setExpiryDate(java.time.Instant expiryDate) { this.expiryDate = expiryDate; }
        public java.util.List<String> getEntitlements() { return entitlements; }
        public void setEntitlements(java.util.List<String> entitlements) { this.entitlements = entitlements; }
    }

    /**
     * Membership plan entity.
     */
    class MembershipPlan {
        private String planId;
        private String name;
        private String tier;
        private java.util.List<String> entitlements;
        private Double bookingDiscountPercent;

        public String getPlanId() { return planId; }
        public void setPlanId(String planId) { this.planId = planId; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getTier() { return tier; }
        public void setTier(String tier) { this.tier = tier; }
        public java.util.List<String> getEntitlements() { return entitlements; }
        public void setEntitlements(java.util.List<String> entitlements) { this.entitlements = entitlements; }
        public Double getBookingDiscountPercent() { return bookingDiscountPercent; }
        public void setBookingDiscountPercent(Double bookingDiscountPercent) { this.bookingDiscountPercent = bookingDiscountPercent; }
    }
}