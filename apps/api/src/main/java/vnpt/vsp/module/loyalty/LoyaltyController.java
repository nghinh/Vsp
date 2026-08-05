package vnpt.vsp.module.loyalty;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for loyalty endpoints.
 *
 * <p>Per Story 12.2. Loyalty is a customer-operations boundary module with no coupling
 * to the round/score modules. "me" endpoints resolve the current user from the
 * authenticated principal.
 */
@RestController
@RequestMapping("/loyalty")
public class LoyaltyController {

    private final LoyaltyService loyaltyService;

    public LoyaltyController(LoyaltyService loyaltyService) {
        this.loyaltyService = loyaltyService;
    }

    /** Get a loyalty account by ID. */
    @GetMapping("/accounts/{accountId}")
    public ResponseEntity<LoyaltyService.LoyaltyAccount> getAccount(@PathVariable String accountId) {
        return loyaltyService.getAccount(accountId)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /** Get the current user's loyalty account. */
    @GetMapping("/users/me/account")
    public ResponseEntity<LoyaltyService.LoyaltyAccount> getMyAccount(Authentication authentication) {
        String userId = currentUserId(authentication);
        return loyaltyService.getAccountByUser(userId)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /** Get transaction history for an account. */
    @GetMapping("/accounts/{accountId}/transactions")
    public ResponseEntity<List<LoyaltyService.LoyaltyTransaction>> getTransactionHistory(@PathVariable String accountId) {
        return ResponseEntity.ok(loyaltyService.getTransactionHistory(accountId));
    }

    /** Earn points for the current user. */
    @PostMapping("/users/me/points/earn")
    public ResponseEntity<?> earnPoints(
            Authentication authentication,
            @RequestParam int points,
            @RequestParam String source) {
        try {
            return ResponseEntity.ok(loyaltyService.earnPoints(currentUserId(authentication), points, source));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(java.util.Map.of("message", e.getMessage()));
        }
    }

    /** Redeem points for the current user. */
    @PostMapping("/users/me/points/redeem")
    public ResponseEntity<?> redeemPoints(
            Authentication authentication,
            @RequestParam int points,
            @RequestParam String rewardId) {
        try {
            return ResponseEntity.ok(loyaltyService.redeemPoints(currentUserId(authentication), points, rewardId));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(java.util.Map.of("message", e.getMessage()));
        } catch (IllegalStateException e) {
            return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(java.util.Map.of("message", e.getMessage()));
        }
    }

    private String currentUserId(Authentication authentication) {
        return String.valueOf(authentication.getPrincipal());
    }
}
