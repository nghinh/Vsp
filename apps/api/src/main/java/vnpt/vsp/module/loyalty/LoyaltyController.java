package vnpt.vsp.module.loyalty;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for loyalty endpoints.
 *
 * All endpoints return 405 Not Implemented — this is a stub module.
 * Full implementation is out of scope for Story 12.2.
 */
@RestController
@RequestMapping("/loyalty")
public class LoyaltyController {

    private final LoyaltyService loyaltyService;

    public LoyaltyController(LoyaltyService loyaltyService) {
        this.loyaltyService = loyaltyService;
    }

    /**
     * Get a loyalty account by ID.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/accounts/{accountId}")
    public ResponseEntity<LoyaltyService.LoyaltyAccount> getAccount(@PathVariable String accountId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Get the current user's loyalty account.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/users/me/account")
    public ResponseEntity<LoyaltyService.LoyaltyAccount> getMyAccount() {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Get transaction history for an account.
     * Returns 405 Not Implemented — stub only.
     */
    @GetMapping("/accounts/{accountId}/transactions")
    public ResponseEntity<List<LoyaltyService.LoyaltyTransaction>> getTransactionHistory(@PathVariable String accountId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Earn points for the current user.
     * Returns 405 Not Implemented — stub only.
     */
    @PostMapping("/users/me/points/earn")
    public ResponseEntity<LoyaltyService.LoyaltyAccount> earnPoints(
            @RequestParam int points,
            @RequestParam String source) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }

    /**
     * Redeem points for the current user.
     * Returns 405 Not Implemented — stub only.
     */
    @PostMapping("/users/me/points/redeem")
    public ResponseEntity<LoyaltyService.LoyaltyAccount> redeemPoints(
            @RequestParam int points,
            @RequestParam String rewardId) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).build();
    }
}