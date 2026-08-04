package vnpt.vsp.module.sponsorship;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for sponsorship endpoints.
 *
 * All endpoints return 405 Not Implemented — this is a stub module.
 * Full implementation is out of scope for Story 12.2.
 */
@RestController
@RequestMapping("/sponsorship")
public class SponsorshipController {

    private final SponsorshipService sponsorshipService;

    public SponsorshipController(SponsorshipService sponsorshipService) {
        this.sponsorshipService = sponsorshipService;
    }

    /**
     * Get a sponsorship by ID.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/sponsorships/{sponsorshipId}")
    public ResponseEntity<SponsorshipService.Sponsorship> getSponsorship(@PathVariable String sponsorshipId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Get sponsorships for a course.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/courses/{courseId}/sponsorships")
    public ResponseEntity<List<SponsorshipService.Sponsorship>> getSponsorshipsForCourse(@PathVariable String courseId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Record consent for a sponsorship.
     * Returns 405 Not Implemented — stub only.
     */
    @PostMapping("/sponsorships/{sponsorshipId}/consent")
    public ResponseEntity<Void> recordConsent(
            @PathVariable String sponsorshipId,
            @RequestParam boolean consentGiven) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }
}