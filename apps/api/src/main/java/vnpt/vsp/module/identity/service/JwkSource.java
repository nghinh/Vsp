package vnpt.vsp.module.identity.service;

import java.security.PublicKey;
import java.util.Optional;

/**
 * Supplies the public keys an identity provider publishes at a JWKS endpoint.
 *
 * <p>Split out from {@link SocialTokenValidatorService} for one reason: the
 * validator's job is to decide whether a token is genuine, and that decision has
 * to be testable without reaching Google or Apple. A test supplies a key it
 * generated itself; production supplies {@link HttpJwkSource}.
 *
 * <p>An implementation must <em>fail closed</em>. Returning empty means "no key,
 * so no signature can be checked", and every caller treats that as a refusal. An
 * implementation that cannot reach the provider must return empty rather than
 * let the token through unchecked.
 */
public interface JwkSource {

    /**
     * The signing key the provider publishes under {@code keyId}.
     *
     * @param jwksUri the provider's JWKS endpoint
     * @param keyId   the {@code kid} from the token header; may be null, in
     *                which case a key set holding exactly one key may be used
     * @return the key, or empty if it is unknown or the key set is unreachable
     */
    Optional<PublicKey> findKey(String jwksUri, String keyId);
}
