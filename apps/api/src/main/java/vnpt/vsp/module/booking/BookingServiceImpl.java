package vnpt.vsp.module.booking;

import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory implementation of {@link BookingService}.
 *
 * <p>Per Story 12.2: booking is a customer-operations boundary module that must not
 * couple to the round/score modules (verified by {@code BookingBoundaryTest}). It owns
 * its own booking state; the tee-sheet system of record (or an external booking
 * provider) is the integration seam and is out of scope for the platform core, so
 * storage is in-memory.
 *
 * <p>Consent boundary (Story 12.2 AC1): a booking cannot be created without recorded
 * consent — {@link #createBooking(BookingRequest)} rejects requests where consent was
 * not given.
 */
@Service
@BookingModule
public class BookingServiceImpl implements BookingService {

    private static final String STATUS_CONFIRMED = "CONFIRMED";
    private static final String STATUS_CANCELLED = "CANCELLED";

    private final ConcurrentHashMap<String, Booking> bookings = new ConcurrentHashMap<>();

    @Override
    public List<BookingSlot> getAvailableSlots(String courseId) {
        // Generate a deterministic set of hourly tee slots for the next open window.
        // A real deployment reads these from the course's tee-sheet provider.
        List<BookingSlot> slots = new ArrayList<>();
        Instant base = Instant.now().truncatedTo(ChronoUnit.HOURS).plus(Duration.ofHours(1));
        for (int i = 0; i < 8; i++) {
            Instant start = base.plus(Duration.ofMinutes(i * 15L));
            BookingSlot slot = new BookingSlot();
            slot.setSlotId(courseId + ":" + start.toEpochMilli());
            slot.setCourseId(courseId);
            slot.setStartTime(start);
            slot.setEndTime(start.plus(Duration.ofMinutes(15)));
            slot.setAvailable(true);
            slots.add(slot);
        }
        return slots;
    }

    @Override
    public Booking createBooking(BookingRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Booking request is required");
        }
        // Consent boundary — no booking without explicit consent.
        if (!request.isConsentGiven()) {
            throw new IllegalStateException("Consent is required before creating a booking");
        }
        if (request.getCourseId() == null || request.getTeeTime() == null) {
            throw new IllegalArgumentException("courseId and teeTime are required");
        }

        Booking booking = new Booking();
        booking.setBookingId(UUID.randomUUID().toString());
        booking.setCourseId(request.getCourseId());
        booking.setTeeTime(request.getTeeTime());
        booking.setPlayers(request.getPlayers());
        booking.setStatus(STATUS_CONFIRMED);
        booking.setConsentGiven(true);
        booking.setConsentTimestamp(Instant.now());

        bookings.put(booking.getBookingId(), booking);
        return booking;
    }

    @Override
    public Optional<Booking> getBooking(String bookingId) {
        return Optional.ofNullable(bookings.get(bookingId));
    }

    @Override
    public Booking updateBookingStatus(String bookingId, String status) {
        Booking booking = requireBooking(bookingId);
        if (status == null || status.isBlank()) {
            throw new IllegalArgumentException("status is required");
        }
        booking.setStatus(status.toUpperCase());
        return booking;
    }

    @Override
    public Booking cancelBooking(String bookingId) {
        Booking booking = requireBooking(bookingId);
        booking.setStatus(STATUS_CANCELLED);
        return booking;
    }

    @Override
    public void recordConsent(String bookingId, boolean consentGiven, Instant timestamp) {
        Booking booking = requireBooking(bookingId);
        booking.setConsentGiven(consentGiven);
        booking.setConsentTimestamp(timestamp != null ? timestamp : Instant.now());
    }

    private Booking requireBooking(String bookingId) {
        Booking booking = bookings.get(bookingId);
        if (booking == null) {
            throw new java.util.NoSuchElementException("Booking not found: " + bookingId);
        }
        return booking;
    }
}
