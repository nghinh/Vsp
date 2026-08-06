package vnpt.vsp.module.loyalty;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for loyalty endpoints.
 *
 * <p>Per Story 12.2. Loyalty is a customer-operations boundary module with no coupling
 * to the round/score modules. "me" endpoints resolve the current user from the
 * authenticated principal.
 *
 * <p>This class carried no {@code @PreAuthorize} of any kind, and it is not
 * under {@code /admin/**}, so the only thing between a signed-in golfer and any
 * of it was {@code anyRequest().authenticated()}. Two consequences, now closed:
 * the {@code /accounts/{accountId}} endpoints read <em>any</em> account's
 * balance and full transaction history by id, and {@code points/earn} let a
 * golfer credit themselves an unbounded number of points by naming the amount
 * in a query parameter.
 *
 * <p>The endpoints that act on the caller's own account stay open to any
 * authenticated user — that is what they are for — and are listed as such in
 * {@code AdminEndpointAuthorizationTest}, where the choice is reviewable rather
 * than merely absent.
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
     *
     * <p>The id names any account, not the caller's, so this is a staff view of
     * somebody else's balance and tier.
     */
    @GetMapping("/accounts/{accountId}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
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

    /**
     * Get transaction history for an account.
     *
     * <p>Also by arbitrary account id: where a member played, when, and what
     * they spent. Staff only, for the same reason as {@link #getAccount}.
     */
    @GetMapping("/accounts/{accountId}/transactions")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<List<LoyaltyService.LoyaltyTransaction>> getTransactionHistory(@PathVariable String accountId) {
        return ResponseEntity.ok(loyaltyService.getTransactionHistory(accountId));
    }

    /**
     * Earn points for the current user.
     *
     * <p>The caller names the number of points and the source, and the service
     * credits them. With no authorization check that was a mint: {@code POST
     * /loyalty/users/me/points/earn?points=1000000&source=booking} from any
     * signed-in golfer, repeatable, and the tier recalculates on the way out.
     *
     * <p>SUPER_ADMIN is the narrowest role this platform has, and it is the
     * right one until the endpoint stops being self-service. Points should
     * accrue as a server-side consequence of a booking or a round, never
     * because a client asked for them — nothing inside this application calls
     * {@code earnPoints} today, so the endpoint is the only path to it, and
     * closing that path is the fix that belongs in a security change. Turning
     * accrual into something the loyalty module decides for itself is a design
     * change for whoever owns it.
     */
    @PostMapping("/users/me/points/earn")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
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
