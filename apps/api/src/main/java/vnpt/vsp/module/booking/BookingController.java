package vnpt.vsp.module.booking;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

/**
 * REST controller for booking endpoints.
 *
 * All endpoints return 405 Not Implemented — this is a stub module.
 * Full implementation is out of scope for Story 12.2.
 */
@RestController
@RequestMapping("/booking")
public class BookingController {

    private final BookingService bookingService;

    public BookingController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    /**
     * Get available booking slots for a course.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/courses/{courseId}/slots")
    public ResponseEntity<BookingService.BookingSlot> getAvailableSlots(@PathVariable String courseId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Create a new booking.
     * Returns 405 Not Implemented — stub only.
     */
    @PostMapping("/bookings")
    public ResponseEntity<BookingService.Booking> createBooking(@RequestBody BookingService.BookingRequest request) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Get a booking by ID.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/bookings/{bookingId}")
    public ResponseEntity<BookingService.Booking> getBooking(@PathVariable String bookingId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Update booking status.
     * Returns 405 Not Implemented — stub only.
     */
    @PatchMapping("/bookings/{bookingId}/status")
    public ResponseEntity<BookingService.Booking> updateBookingStatus(
            @PathVariable String bookingId,
            @RequestParam String status) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Cancel a booking.
     * Returns 405 Not Implemented — stub only.
     */
    @DeleteMapping("/bookings/{bookingId}")
    public ResponseEntity<Void> cancelBooking(@PathVariable String bookingId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Record consent for a booking.
     * Returns 405 Not Implemented — stub only.
     */
    @PostMapping("/bookings/{bookingId}/consent")
    public ResponseEntity<Void> recordConsent(
            @PathVariable String bookingId,
            @RequestParam boolean consentGiven) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }
}