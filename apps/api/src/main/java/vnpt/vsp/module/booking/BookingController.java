package vnpt.vsp.module.booking;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.NoSuchElementException;

/**
 * REST controller for booking endpoints.
 *
 * <p>Per Story 12.2. Booking is a customer-operations boundary module; it holds no
 * coupling to the round/score modules. All write operations honour the consent
 * boundary — a booking cannot be created without consent.
 */
@RestController
@RequestMapping("/booking")
public class BookingController {

    private final BookingService bookingService;

    public BookingController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    /** Get available booking slots for a course. */
    @GetMapping("/courses/{courseId}/slots")
    public ResponseEntity<List<BookingService.BookingSlot>> getAvailableSlots(@PathVariable String courseId) {
        return ResponseEntity.ok(bookingService.getAvailableSlots(courseId));
    }

    /** Create a new booking. Requires consent (consent boundary). */
    @PostMapping("/bookings")
    public ResponseEntity<?> createBooking(@RequestBody BookingService.BookingRequest request) {
        try {
            BookingService.Booking booking = bookingService.createBooking(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(booking);
        } catch (IllegalStateException e) {
            return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(error(e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(error(e.getMessage()));
        }
    }

    /** Get a booking by ID. */
    @GetMapping("/bookings/{bookingId}")
    public ResponseEntity<BookingService.Booking> getBooking(@PathVariable String bookingId) {
        return bookingService.getBooking(bookingId)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /** Update booking status. */
    @PatchMapping("/bookings/{bookingId}/status")
    public ResponseEntity<?> updateBookingStatus(
            @PathVariable String bookingId,
            @RequestParam String status) {
        try {
            return ResponseEntity.ok(bookingService.updateBookingStatus(bookingId, status));
        } catch (NoSuchElementException e) {
            return ResponseEntity.notFound().build();
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(error(e.getMessage()));
        }
    }

    /** Cancel a booking. */
    @DeleteMapping("/bookings/{bookingId}")
    public ResponseEntity<?> cancelBooking(@PathVariable String bookingId) {
        try {
            return ResponseEntity.ok(bookingService.cancelBooking(bookingId));
        } catch (NoSuchElementException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /** Record consent for a booking. */
    @PostMapping("/bookings/{bookingId}/consent")
    public ResponseEntity<Void> recordConsent(
            @PathVariable String bookingId,
            @RequestParam boolean consentGiven) {
        try {
            bookingService.recordConsent(bookingId, consentGiven, Instant.now());
            return ResponseEntity.noContent().build();
        } catch (NoSuchElementException e) {
            return ResponseEntity.notFound().build();
        }
    }

    private java.util.Map<String, String> error(String message) {
        return java.util.Map.of("message", message != null ? message : "Bad request");
    }
}
