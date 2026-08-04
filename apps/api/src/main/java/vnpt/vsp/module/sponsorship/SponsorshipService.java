package vnpt.vsp.module.sponsorship;

/**
 * Sponsorship module public service interface.
 * Exposes sponsorship and advertising operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 *
 * Boundary rule: This service must not accept RoundModule or ScoreModule types.
 */
public interface SponsorshipService {

    /**
     * Get a sponsorship by ID.
     *
     * @param sponsorshipId the sponsorship identifier
     * @return the sponsorship or empty if not found
     */
    java.util.Optional<Sponsorship> getSponsorship(String sponsorshipId);

    /**
     * Get sponsorships for a course.
     *
     * @param courseId the course identifier
     * @return list of sponsorships
     */
    java.util.List<Sponsorship> getSponsorshipsForCourse(String courseId);

    /**
     * Record consent for a sponsorship.
     *
     * @param sponsorshipId the sponsorship identifier
     * @param consentGiven whether consent was given
     */
    void recordConsent(String sponsorshipId, boolean consentGiven);

    /**
     * Sponsorship entity.
     */
    class Sponsorship {
        private String sponsorshipId;
        private String courseId;
        private String sponsorName;
        private String logoUrl;
        private java.util.List<String> targetSlots;
        private boolean consentGiven;

        public String getSponsorshipId() { return sponsorshipId; }
        public void setSponsorshipId(String sponsorshipId) { this.sponsorshipId = sponsorshipId; }
        public String getCourseId() { return courseId; }
        public void setCourseId(String courseId) { this.courseId = courseId; }
        public String getSponsorName() { return sponsorName; }
        public void setSponsorName(String sponsorName) { this.sponsorName = sponsorName; }
        public String getLogoUrl() { return logoUrl; }
        public void setLogoUrl(String logoUrl) { this.logoUrl = logoUrl; }
        public java.util.List<String> getTargetSlots() { return targetSlots; }
        public void setTargetSlots(java.util.List<String> targetSlots) { this.targetSlots = targetSlots; }
        public boolean isConsentGiven() { return consentGiven; }
        public void setConsentGiven(boolean consentGiven) { this.consentGiven = consentGiven; }
    }
}