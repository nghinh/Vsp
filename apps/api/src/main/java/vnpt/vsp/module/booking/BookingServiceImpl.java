package vnpt.vsp.module.booking;

import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Service
@BookingModule
public class BookingServiceImpl implements BookingService {

    @Override
    public List<BookingSlot> getAvailableSlots(String courseId) {
        return List.of();
    }

    @Override
    public Booking createBooking(BookingRequest request) {
        throw new UnsupportedOperationException("Booking creation is not implemented");
    }

    @Override
    public Optional<Booking> getBooking(String bookingId) {
        return Optional.empty();
    }

    @Override
    public Booking updateBookingStatus(String bookingId, String status) {
        throw new UnsupportedOperationException("Booking status updates are not implemented");
    }

    @Override
    public Booking cancelBooking(String bookingId) {
        throw new UnsupportedOperationException("Booking cancellation is not implemented");
    }

    @Override
    public void recordConsent(String bookingId, boolean consentGiven, Instant timestamp) {
        throw new UnsupportedOperationException("Booking consent is not implemented");
    }
}
