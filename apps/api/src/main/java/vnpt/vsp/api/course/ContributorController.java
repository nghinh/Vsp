package vnpt.vsp.api.course;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import vnpt.vsp.module.correction.ContributorService;
import vnpt.vsp.module.correction.dto.ContributorResponse;

import java.util.List;

/**
 * Credit for the people who filled in the country's scorecards.
 *
 * <p>Reads only, and only display names and counts — see
 * {@link ContributorService} for why nothing else is exposed.
 */
@RestController
public class ContributorController {

    private final ContributorService contributorService;

    public ContributorController(ContributorService contributorService) {
        this.contributorService = contributorService;
    }

    @GetMapping("/contributors")
    public List<ContributorResponse> leaderboard() {
        return contributorService.leaderboard();
    }

    @GetMapping("/courses/{courseId}/contributors")
    public List<ContributorResponse> forCourse(@PathVariable Long courseId) {
        return contributorService.forCourse(courseId);
    }
}
