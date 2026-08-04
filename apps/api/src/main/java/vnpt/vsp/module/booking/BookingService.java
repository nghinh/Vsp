package vnpt.vsp.module.booking;

/**
 * Booking module public service interface.
 * Exposes tee-time booking and slot management operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 *
 * Boundary rule: This service must not accept RoundModule or ScoreModule types.
 */
public interface BookingService {

    /**
     * Get available booking slots for a course.
     *
     * @param courseId the course identifier
     * @return list of available booking slots
     */
    java.util.List<BookingSlot> getAvailableSlots(String courseId);

    /**
     * Create a new booking reservation.
     *
     * @param request the booking request
     * @return the created booking
     */
    Booking createBooking(BookingRequest request);

    /**
     * Get a booking by ID.
     *
     * @param bookingId the booking identifier
     * @return the booking or empty if not found
     */
    java.util.Optional<Booking> getBooking(String bookingId);

    /**
     * Update booking status.
     *
     * @param bookingId the booking identifier
     * @param status the new status
     * @return updated booking
     */
    Booking updateBookingStatus(String bookingId, String status);

    /**
     * Cancel a booking.
     *
     * @param bookingId the booking identifier
     * @return cancelled booking
     */
    Booking cancelBooking(String bookingId);

    /**
     * Record user consent for a booking.
     *
     * @param bookingId the booking identifier
     * @param consentGiven whether consent was given
     * @param timestamp when consent was given
     */
    void recordConsent(String bookingId, boolean consentGiven, java.time.Instant timestamp);

    /**
     * Available booking slot.
     */
    class BookingSlot {
        private String slotId;
        private String courseId;
        private java.time.Instant startTime;
        private java.time.Instant endTime;
        private boolean available;

        public String getSlotId() { return slotId; }
        public void setSlotId(String slotId) { this.slotId = slotId; }
        public String getCourseId() { return courseId; }
        public void setCourseId(String courseId) { this.courseId = courseId; }
        public java.time.Instant getStartTime() { return startTime; }
        public void setStartTime(java.time.Instant startTime) { this.startTime = startTime; }
        public java.time.Instant getEndTime() { return endTime; }
        public void setEndTime(java.time.Instant endTime) { this.endTime = endTime; }
        public boolean isAvailable() { return available; }
        public void setAvailable(boolean available) { this.available = available; }
    }

    /**
     * Booking entity.
     */
    class Booking {
        private String bookingId;
        private String userId;
        private String courseId;
        private java.time.Instant teeTime;
        private java.util.List<BookingPlayer> players;
        private String status;
        private boolean consentGiven;
        private java.time.Instant consentTimestamp;

        public String getBookingId() { return bookingId; }
        public void setBookingId(String bookingId) { this.bookingId = bookingId; }
        public String getUserId() { return userId; }
        public void setUserId(String userId) { this.userId = userId; }
        public String getCourseId() { return courseId; }
        public void setCourseId(String courseId) { this.courseId = courseId; }
        public java.time.Instant getTeeTime() { return teeTime; }
        public void setTeeTime(java.time.Instant teeTime) { this.teeTime = teeTime; }
        public java.util.List<BookingPlayer> getPlayers() { return players; }
        public void setPlayers(java.util.List<BookingPlayer> players) { this.players = players; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public boolean isConsentGiven() { return consentGiven; }
        public void setConsentGiven(boolean consentGiven) { this.consentGiven = consentGiven; }
        public java.time.Instant getConsentTimestamp() { return consentTimestamp; }
        public void setConsentTimestamp(java.time.Instant consentTimestamp) { this.consentTimestamp = consentTimestamp; }
    }

    /**
     * Player in a booking.
     */
    class BookingPlayer {
        private String playerId;
        private String name;
        private String email;

        public String getPlayerId() { return playerId; }
        public void setPlayerId(String playerId) { this.playerId = playerId; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
    }

    /**
     * Booking request.
     */
    class BookingRequest {
        private String courseId;
        private java.time.Instant teeTime;
        private java.util.List<BookingPlayer> players;
        private boolean consentGiven;

        public String getCourseId() { return courseId; }
        public void setCourseId(String courseId) { this.courseId = courseId; }
        public java.time.Instant getTeeTime() { return teeTime; }
        public void setTeeTime(java.time.Instant teeTime) { this.teeTime = teeTime; }
        public java.util.List<BookingPlayer> getPlayers() { return players; }
        public void setPlayers(java.util.List<BookingPlayer> players) { this.players = players; }
        public boolean isConsentGiven() { return consentGiven; }
        public void setConsentGiven(boolean consentGiven) { this.consentGiven = consentGiven; }
    }
}