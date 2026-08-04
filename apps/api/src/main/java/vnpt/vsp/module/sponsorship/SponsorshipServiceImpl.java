package vnpt.vsp.module.sponsorship;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@SponsorshipModule
public class SponsorshipServiceImpl implements SponsorshipService {

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
        throw new UnsupportedOperationException("Sponsorship consent is not implemented");
    }
}
