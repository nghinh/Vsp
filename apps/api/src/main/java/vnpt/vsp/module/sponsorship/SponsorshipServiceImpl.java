package vnpt.vsp.module.sponsorship;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * Sponsorship is an intentionally inert module: the product scope has no
 * sponsorship data yet, and {@link SponsorshipController} answers 405 for every
 * endpoint. The methods therefore return empty results instead of throwing, so
 * a future caller degrades to "no sponsorships" rather than a 500.
 */
@Service
@SponsorshipModule
public class SponsorshipServiceImpl implements SponsorshipService {

    private static final Logger log = LoggerFactory.getLogger(SponsorshipServiceImpl.class);

    @Override
    public Optional<Sponsorship> getSponsorship(String sponsorshipId) {
        return Optional.empty();
    }

    @Override
    public List<Sponsorship> getSponsorshipsForCourse(String courseId) {
        return List.of();
    }

    @Override
    public void recordConsent(String sponsorshipId, boolean consentGiven) {
        // No sponsorship store exists yet — record the intent in the log so the
        // call is traceable, and do not fail the caller.
        log.info("Sponsorship consent ignored (module not enabled) — id={}, consent={}",
                sponsorshipId, consentGiven);
    }
}
