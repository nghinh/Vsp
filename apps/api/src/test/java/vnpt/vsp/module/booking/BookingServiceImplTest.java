package vnpt.vsp.module.booking;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.NoSuchElementException;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for the in-memory {@link BookingServiceImpl} — Story 12.2.
 * Includes the consent boundary (no booking without consent).
 */
class BookingServiceImplTest {

    private BookingServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new BookingServiceImpl();
    }

    private BookingService.BookingRequest request(boolean consent) {
        BookingService.BookingRequest req = new BookingService.BookingRequest();
        req.setCourseId("course-1");
        req.setTeeTime(Instant.now().plusSeconds(3600));
        req.setConsentGiven(consent);
        return req;
    }

    @Test
    void getAvailableSlots_returnsSlotsForCourse() {
        List<BookingService.BookingSlot> slots = service.getAvailableSlots("course-1");
        assertFalse(slots.isEmpty());
        assertTrue(slots.stream().allMatch(s -> "course-1".equals(s.getCourseId())));
        assertTrue(slots.stream().allMatch(BookingService.BookingSlot::isAvailable));
    }

    @Test
    void createBooking_withConsent_confirmsBooking() {
        BookingService.Booking booking = service.createBooking(request(true));
        assertNotNull(booking.getBookingId());
        assertEquals("CONFIRMED", booking.getStatus());
        assertTrue(booking.isConsentGiven());
        assertNotNull(booking.getConsentTimestamp());
        assertTrue(service.getBooking(booking.getBookingId()).isPresent());
    }

    @Test
    void createBooking_withoutConsent_rejected() {
        assertThrows(IllegalStateException.class, () -> service.createBooking(request(false)));
    }

    @Test
    void createBooking_missingFields_rejected() {
        BookingService.BookingRequest req = new BookingService.BookingRequest();
        req.setConsentGiven(true);
        assertThrows(IllegalArgumentException.class, () -> service.createBooking(req));
    }

    @Test
    void cancelBooking_setsCancelledStatus() {
        BookingService.Booking booking = service.createBooking(request(true));
        BookingService.Booking cancelled = service.cancelBooking(booking.getBookingId());
        assertEquals("CANCELLED", cancelled.getStatus());
    }

    @Test
    void updateBookingStatus_updates() {
        BookingService.Booking booking = service.createBooking(request(true));
        BookingService.Booking updated = service.updateBookingStatus(booking.getBookingId(), "checked_in");
        assertEquals("CHECKED_IN", updated.getStatus());
    }

    @Test
    void operationsOnUnknownBooking_throwNotFound() {
        assertThrows(NoSuchElementException.class, () -> service.cancelBooking("nope"));
        assertThrows(NoSuchElementException.class, () -> service.updateBookingStatus("nope", "x"));
        assertThrows(NoSuchElementException.class, () -> service.recordConsent("nope", true, Instant.now()));
        assertTrue(service.getBooking("nope").isEmpty());
    }

    @Test
    void recordConsent_updatesBooking() {
        BookingService.Booking booking = service.createBooking(request(true));
        service.recordConsent(booking.getBookingId(), false, Instant.now());
        assertFalse(service.getBooking(booking.getBookingId()).orElseThrow().isConsentGiven());
    }
}
