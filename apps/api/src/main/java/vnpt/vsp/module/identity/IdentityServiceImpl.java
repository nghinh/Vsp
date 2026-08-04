package vnpt.vsp.module.identity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.identity.dto.*;
import vnpt.vsp.module.identity.entity.GolferAccount;
import vnpt.vsp.module.identity.entity.OtpCode;
import vnpt.vsp.module.identity.entity.PasswordRecoveryToken;
import vnpt.vsp.module.identity.entity.RefreshToken;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;
import vnpt.vsp.module.identity.repository.OtpCodeRepository;
import vnpt.vsp.module.identity.repository.PasswordRecoveryTokenRepository;
import vnpt.vsp.module.identity.repository.RefreshTokenRepository;
import vnpt.vsp.module.identity.security.JwtService;
import vnpt.vsp.module.identity.security.PasswordService;
import vnpt.vsp.module.identity.service.SocialTokenValidatorService;
import vnpt.vsp.module.identity.service.SocialTokenValidatorService.SocialTokenClaims;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * Implementation of {@link IdentityService} for phone/email authentication.
 * Per PRD Section 8.1: phone, email registration with OTP verification and password recovery.
 */
@Service
public class IdentityServiceImpl implements IdentityService {

    private static final Logger log = LoggerFactory.getLogger(IdentityServiceImpl.class);
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final Pattern PHONE_PATTERN = Pattern.compile("^\\+?[0-9]{10,15}$");
    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[^@]+@[^@]+\\.[^@]+$");

    private final GolferAccountRepository golferAccountRepository;
    private final OtpCodeRepository otpCodeRepository;
    private final PasswordRecoveryTokenRepository passwordRecoveryTokenRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordService passwordService;
    private final JwtService jwtService;
    private final SocialTokenValidatorService socialTokenValidator;
    private final AuditService auditService;

    public IdentityServiceImpl(
            GolferAccountRepository golferAccountRepository,
            OtpCodeRepository otpCodeRepository,
            PasswordRecoveryTokenRepository passwordRecoveryTokenRepository,
            RefreshTokenRepository refreshTokenRepository,
            PasswordService passwordService,
            JwtService jwtService,
            SocialTokenValidatorService socialTokenValidator,
            AuditService auditService) {
        this.golferAccountRepository = golferAccountRepository;
        this.otpCodeRepository = otpCodeRepository;
        this.passwordRecoveryTokenRepository = passwordRecoveryTokenRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordService = passwordService;
        this.jwtService = jwtService;
        this.socialTokenValidator = socialTokenValidator;
        this.auditService = auditService;
    }

    // ─── Registration ────────────────────────────────────────────────────────

    @Override
    @Transactional
    public AuthResponse registerWithPhone(PhoneRegisterRequest request) {
        // Check if phone already exists
        if (golferAccountRepository.existsByPhone(request.getPhone())) {
            throw VspApiException.forField(VspErrorCode.AUTH_008, "phone");
        }

        // Create new account
        GolferAccount account = new GolferAccount();
        account.setPhone(request.getPhone());
        account.setDisplayName(request.getDisplayName());
        account.setPasswordHash(passwordService.hashPassword(request.getPassword()));
        account.setStatus(GolferAccount.Status.PENDING);

        account = golferAccountRepository.save(account);
        log.info("Created golfer account with phone: {}", maskPhone(request.getPhone()));

        // Generate and save OTP (simulated - just log the code)
        OtpCode otp = createOtp(account, OtpCode.OtpType.PHONE_VERIFY);
        log.info("SIMULATED SMS: OTP for {} is {}", maskPhone(request.getPhone()), otp.getCode());

        // Return tokens (account not verified yet, but user can log in)
        return buildAuthResponse(account);
    }

    @Override
    @Transactional
    public AuthResponse registerWithEmail(EmailRegisterRequest request) {
        // Check if email already exists
        if (golferAccountRepository.existsByEmail(request.getEmail())) {
            throw VspApiException.forField(VspErrorCode.AUTH_008, "email");
        }

        // Create new account
        GolferAccount account = new GolferAccount();
        account.setEmail(request.getEmail());
        account.setDisplayName(request.getDisplayName());
        account.setPasswordHash(passwordService.hashPassword(request.getPassword()));
        account.setStatus(GolferAccount.Status.PENDING);

        account = golferAccountRepository.save(account);
        log.info("Created golfer account with email: {}", maskEmail(request.getEmail()));

        // Generate and save OTP (simulated - just log the code)
        OtpCode otp = createOtp(account, OtpCode.OtpType.EMAIL_VERIFY);
        log.info("SIMULATED EMAIL: OTP for {} is {}", maskEmail(request.getEmail()), otp.getCode());

        // Return tokens
        return buildAuthResponse(account);
    }

    // ─── OTP ────────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public OtpSendResponse sendOtp(OtpSendRequest request) {
        OtpCode.OtpType otpType = OtpCode.OtpType.valueOf(request.getType());
        GolferAccount account = resolveAccount(request.getIdentifier());

        if (account == null) {
            throw VspApiException.forField(VspErrorCode.AUTH_010, "identifier");
        }

        // Invalidate any existing active OTPs of the same type
        otpCodeRepository.deleteByGolferAccountIdAndType(account.getId(), otpType);

        // Create new OTP
        OtpCode otp = createOtp(account, otpType);

        // Simulated delivery
        if (otpType == OtpCode.OtpType.PHONE_VERIFY || otpType == OtpCode.OtpType.PASSWORD_RECOVERY) {
            log.info("SIMULATED SMS: OTP for {} is {}", maskIdentifier(request.getIdentifier()), otp.getCode());
        } else {
            log.info("SIMULATED EMAIL: OTP for {} is {}", maskIdentifier(request.getIdentifier()), otp.getCode());
        }

        return OtpSendResponse.success();
    }

    @Override
    @Transactional
    public AuthResponse verifyOtp(OtpVerifyRequest request) {
        OtpCode.OtpType otpType = OtpCode.OtpType.valueOf(request.getType());
        GolferAccount account = resolveAccount(request.getIdentifier());

        if (account == null) {
            throw VspApiException.forField(VspErrorCode.AUTH_010, "identifier");
        }

        OtpCode otp = otpCodeRepository
                .findActiveOtpByCode(account.getId(), request.getCode(), otpType, Instant.now())
                .orElseThrow(() -> VspApiException.forField(VspErrorCode.AUTH_011, "code"));

        // Mark OTP as verified
        otp.markVerified();
        otpCodeRepository.save(otp);

        // If this was a verification OTP, mark account as verified
        if (otpType == OtpCode.OtpType.PHONE_VERIFY || otpType == OtpCode.OtpType.EMAIL_VERIFY) {
            account.setVerifiedAt(Instant.now());
            account.setStatus(GolferAccount.Status.ACTIVE);
            golferAccountRepository.save(account);
            log.info("Golfer account verified: {}", account.getId());
        }

        return buildAuthResponse(account);
    }

    // ─── Password Recovery ───────────────────────────────────────────────────

    @Override
    @Transactional
    public OtpSendResponse initiatePasswordRecovery(PasswordRecoverRequest request) {
        GolferAccount account = resolveAccount(request.getIdentifier());

        if (account == null || !account.hasPassword()) {
            // Don't reveal if account exists - just return success
            log.info("Password recovery requested for non-existent or passwordless account");
            return OtpSendResponse.success();
        }

        // Delete any existing recovery tokens
        passwordRecoveryTokenRepository.deleteByGolferAccountId(account.getId());

        // Create new OTP for password recovery
        OtpCode otp = createOtp(account, OtpCode.OtpType.PASSWORD_RECOVERY);

        // Simulated delivery
        if (isPhoneIdentifier(request.getIdentifier())) {
            log.info("SIMULATED SMS: Password recovery OTP for {} is {}",
                    maskIdentifier(request.getIdentifier()), otp.getCode());
        } else {
            log.info("SIMULATED EMAIL: Password recovery OTP for {} is {}",
                    maskIdentifier(request.getIdentifier()), otp.getCode());
        }

        return OtpSendResponse.success();
    }

    @Override
    @Transactional
    public AuthResponse resetPassword(PasswordResetRequest request) {
        PasswordRecoveryToken recoveryToken = passwordRecoveryTokenRepository
                .findActiveToken(request.getToken(), Instant.now())
                .orElseThrow(() -> VspApiException.forField(VspErrorCode.AUTH_012, "token"));

        GolferAccount account = recoveryToken.getGolferAccount();

        // Update password
        account.setPasswordHash(passwordService.hashPassword(request.getNewPassword()));
        golferAccountRepository.save(account);

        // Mark token as used
        recoveryToken.markUsed();
        passwordRecoveryTokenRepository.save(recoveryToken);

        log.info("Password reset completed for account: {}", account.getId());

        return buildAuthResponse(account);
    }

    // ─── Login ──────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public AuthResponse login(String identifier, String password) {
        GolferAccount account = resolveAccount(identifier);

        if (account == null || !account.hasPassword()) {
            auditService.log(AuditAction.AUTH_LOGIN_FAILED,
                    "GolferAccount", null, null, null,
                    buildLoginFailedMetadata(identifier, "INVALID_IDENTIFIER"));
            throw VspApiException.forField(VspErrorCode.AUTH_001, "identifier");
        }

        if (!passwordService.verifyPassword(password, account.getPasswordHash())) {
            auditService.log(AuditAction.AUTH_LOGIN_FAILED,
                    "GolferAccount", String.valueOf(account.getId()), null, null,
                    buildLoginFailedMetadata(identifier, "INVALID_PASSWORD"));
            throw VspApiException.forField(VspErrorCode.AUTH_001, "password");
        }

        if (account.getStatus() == GolferAccount.Status.SUSPENDED) {
            auditService.log(AuditAction.AUTH_LOGIN_FAILED,
                    "GolferAccount", String.valueOf(account.getId()), null, null,
                    buildLoginFailedMetadata(identifier, "ACCOUNT_SUSPENDED"));
            throw VspApiException.forField(VspErrorCode.AUTH_004, "identifier");
        }

        if (account.getStatus() == GolferAccount.Status.DELETED) {
            auditService.log(AuditAction.AUTH_LOGIN_FAILED,
                    "GolferAccount", String.valueOf(account.getId()), null, null,
                    buildLoginFailedMetadata(identifier, "ACCOUNT_DELETED"));
            throw VspApiException.forField(VspErrorCode.AUTH_001, "identifier");
        }

        log.info("Successful login for account: {}", account.getId());

        return buildAuthResponse(account);
    }

    // ─── Token Refresh ──────────────────────────────────────────────────────

    @Override
    @Transactional
    public AuthResponse refreshToken(String refreshToken) {
        if (!jwtService.isRefreshToken(refreshToken)) {
            throw VspApiException.forField(VspErrorCode.AUTH_003, "refreshToken");
        }

        Long accountId = jwtService.validateToken(refreshToken);
        if (accountId == null) {
            throw VspApiException.forField(VspErrorCode.AUTH_002, "refreshToken");
        }

        GolferAccount account = golferAccountRepository.findById(accountId)
                .orElseThrow(() -> VspApiException.forField(VspErrorCode.AUTH_006, "refreshToken"));

        if (account.getStatus() == GolferAccount.Status.DELETED) {
            throw VspApiException.forField(VspErrorCode.AUTH_006, "refreshToken");
        }

        // Delegate to rotation with no device info (stateless refresh from mobile app)
        return rotateRefreshToken(refreshToken, null, null, null);
    }

    // ─── Session Management ─────────────────────────────────────────────────

    @Override
    @Transactional
    public AuthResponse rotateRefreshToken(String refreshToken, String deviceInfo, String userAgent, String ipAddress) {
        if (!jwtService.isRefreshToken(refreshToken)) {
            throw VspApiException.forField(VspErrorCode.AUTH_003, "refreshToken");
        }

        Long accountId = jwtService.validateToken(refreshToken);
        if (accountId == null) {
            throw VspApiException.forField(VspErrorCode.AUTH_002, "refreshToken");
        }

        String tokenHash = jwtService.hashToken(refreshToken);

        RefreshToken storedToken = refreshTokenRepository
                .findActiveByAccountIdAndTokenHash(accountId, tokenHash, Instant.now())
                .orElseThrow(() -> VspApiException.forField(VspErrorCode.AUTH_006, "refreshToken"));

        // Mark old token as revoked
        storedToken.revoke();

        // Create new refresh token
        String newRefreshToken = jwtService.generateRefreshToken(accountId);
        String newTokenHash = jwtService.hashToken(newRefreshToken);

        RefreshToken newToken = new RefreshToken();
        newToken.setGolferAccount(storedToken.getGolferAccount());
        newToken.setTokenHash(newTokenHash);
        newToken.setDeviceInfo(deviceInfo);
        newToken.setUserAgent(userAgent);
        newToken.setIpAddress(ipAddress);
        newToken.setExpiresAt(Instant.now().plusMillis(jwtService.getRefreshTokenExpirationMs()));
        newToken = refreshTokenRepository.save(newToken);

        // Link old token to new one
        storedToken.setReplacedByToken(newToken);
        refreshTokenRepository.save(storedToken);

        // Generate new access token
        String newAccessToken = jwtService.generateAccessToken(accountId);

        log.info("Refresh token rotated for account {}: old session {} revoked, new session {} created",
                accountId, storedToken.getId(), newToken.getId());

        return AuthResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(newRefreshToken)
                .expiresIn(jwtService.getAccessTokenExpirationSeconds())
                .tokenType("Bearer")
                .userId(accountId)
                .displayName(storedToken.getGolferAccount().getDisplayName())
                .status(storedToken.getGolferAccount().getStatus().name())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public List<SessionResponse> listSessions(Long golferAccountId, Long currentTokenId) {
        List<RefreshToken> activeTokens = refreshTokenRepository
                .findActiveSessionsByAccountId(golferAccountId, Instant.now());

        return activeTokens.stream()
                .map(token -> SessionResponse.builder()
                        .sessionId(token.getId())
                        .deviceInfo(token.getDeviceInfo())
                        .userAgent(token.getUserAgent())
                        .ipAddress(token.getIpAddress())
                        .createdAt(token.getCreatedAt())
                        .expiresAt(token.getExpiresAt())
                        .currentSession(token.getId().equals(currentTokenId))
                        .build())
                .toList();
    }

    @Override
    @Transactional
    public void revokeSession(Long golferAccountId, Long sessionId) {
        RefreshToken token = refreshTokenRepository
                .findByIdAndGolferAccountId(sessionId, golferAccountId)
                .orElseThrow(() -> VspApiException.forField(VspErrorCode.AUTH_018, "sessionId"));

        if (token.isRevoked()) {
            throw VspApiException.forField(VspErrorCode.AUTH_019, "sessionId");
        }

        token.revoke();
        refreshTokenRepository.save(token);

        log.info("Session {} revoked for account {}", sessionId, golferAccountId);
    }

    @Override
    @Transactional
    public int revokeAllSessions(Long golferAccountId) {
        int count = refreshTokenRepository.revokeAllActiveSessions(golferAccountId, Instant.now(), Instant.now());
        log.info("Revoked {} sessions for account {}", count, golferAccountId);
        return count;
    }

    // ─── Profile ────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public GolferProfileResponse getCurrentProfile(Long golferAccountId) {
        GolferAccount account = golferAccountRepository.findById(golferAccountId)
                .orElseThrow(() -> VspApiException.forField(VspErrorCode.AUTH_006, "userId"));

        return GolferProfileResponse.builder()
                .id(account.getId())
                .phone(account.getPhone())
                .email(account.getEmail())
                .displayName(account.getDisplayName())
                .status(account.getStatus().name())
                .verified(account.isVerified())
                .createdAt(account.getCreatedAt() != null ? account.getCreatedAt().toString() : null)
                .build();
    }

    // ─── Token Validation ───────────────────────────────────────────────────

    @Override
    public Long validateAccessToken(String accessToken) {
        if (!jwtService.isAccessToken(accessToken)) {
            return null;
        }
        return jwtService.validateToken(accessToken);
    }

    // ─── Social Authentication ─────────────────────────────────────────────

    @Override
    @Transactional
    public SocialAuthResponse authenticateWithGoogle(GoogleAuthRequest request) {
        // Validate the Google ID token and extract claims
        SocialTokenClaims claims = socialTokenValidator.validateGoogleToken(request.getIdToken())
                .orElseThrow(() -> VspApiException.forField(VspErrorCode.AUTH_014, "idToken"));

        String email = claims.email();
        String googleSubject = claims.subject();
        String displayName = request.getDisplayName() != null ? request.getDisplayName() : claims.displayName();

        // Check if this Google subject is already linked to an account
        Optional<GolferAccount> existingByGoogle = golferAccountRepository.findByGoogleSubject(googleSubject);
        if (existingByGoogle.isPresent()) {
            // Already linked - just authenticate
            GolferAccount account = existingByGoogle.get();
            log.info("Google auth: existing account {} linked to Google subject {}",
                    account.getId(), googleSubject);
            return buildSocialAuthResponse(account, "GOOGLE", false);
        }

        // Check if email is already registered with a different provider
        Optional<GolferAccount> existingByEmail = golferAccountRepository.findByEmail(email);
        if (existingByEmail.isPresent()) {
            GolferAccount account = existingByEmail.get();

            // If this email already has Google linked (via another Google account), conflict
            if (account.getGoogleSubject() != null && !account.getGoogleSubject().equals(googleSubject)) {
                log.warn("Google auth: email {} already linked to a different Google subject", email);
                throw VspApiException.forField(VspErrorCode.AUTH_017, "email");
            }

            // If this email already has Apple linked, that's fine (canonical account)
            if (account.getAppleSubject() != null) {
                log.info("Google auth: linking Google subject {} to existing canonical account {} (email={})",
                        googleSubject, account.getId(), maskEmail(email));
            }

            // Link Google to existing canonical account
            account.setGoogleSubject(googleSubject);
            if (displayName != null && !displayName.isBlank() && (account.getDisplayName() == null || account.getDisplayName().isBlank())) {
                account.setDisplayName(displayName);
            }
            if (!account.isVerified() && email != null) {
                // Google emails are verified by Google
                account.setVerifiedAt(Instant.now());
                account.setStatus(GolferAccount.Status.ACTIVE);
            }
            golferAccountRepository.save(account);
            log.info("Google auth: linked Google subject {} to existing account {} via email match",
                    googleSubject, account.getId());
            return buildSocialAuthResponse(account, "GOOGLE", false);
        }

        // Create a new account
        GolferAccount account = new GolferAccount();
        account.setGoogleSubject(googleSubject);
        account.setEmail(email);
        account.setDisplayName(displayName != null ? displayName : "Golfer");
        account.setStatus(GolferAccount.Status.ACTIVE);
        account.setVerifiedAt(Instant.now()); // Google verifies email

        account = golferAccountRepository.save(account);
        log.info("Google auth: created new account {} for Google subject {} (email={})",
                account.getId(), googleSubject, maskEmail(email));

        return buildSocialAuthResponse(account, "GOOGLE", true);
    }

    @Override
    @Transactional
    public SocialAuthResponse authenticateWithApple(AppleAuthRequest request) {
        // Validate the Apple identity token and extract claims
        SocialTokenClaims claims = socialTokenValidator.validateAppleToken(request.getIdToken())
                .orElseThrow(() -> VspApiException.forField(VspErrorCode.AUTH_015, "idToken"));

        String email = claims.email();
        String appleSubject = claims.subject();
        String displayName = request.getDisplayName() != null ? request.getDisplayName() : claims.displayName();

        // Check if this Apple subject is already linked to an account
        Optional<GolferAccount> existingByApple = golferAccountRepository.findByAppleSubject(appleSubject);
        if (existingByApple.isPresent()) {
            // Already linked - just authenticate
            GolferAccount account = existingByApple.get();
            log.info("Apple auth: existing account {} linked to Apple subject {}",
                    account.getId(), appleSubject);
            return buildSocialAuthResponse(account, "APPLE", false);
        }

        // Check if email is already registered with a different provider
        Optional<GolferAccount> existingByEmail = golferAccountRepository.findByEmail(email);
        if (existingByEmail.isPresent()) {
            GolferAccount account = existingByEmail.get();

            // If this email already has Apple linked (via another Apple account), conflict
            if (account.getAppleSubject() != null && !account.getAppleSubject().equals(appleSubject)) {
                log.warn("Apple auth: email {} already linked to a different Apple subject", email);
                throw VspApiException.forField(VspErrorCode.AUTH_017, "email");
            }

            // If this email already has Google linked, that's fine (canonical account)
            if (account.getGoogleSubject() != null) {
                log.info("Apple auth: linking Apple subject {} to existing canonical account {} (email={})",
                        appleSubject, account.getId(), maskEmail(email));
            }

            // Link Apple to existing canonical account
            account.setAppleSubject(appleSubject);
            if (displayName != null && !displayName.isBlank() && (account.getDisplayName() == null || account.getDisplayName().isBlank())) {
                account.setDisplayName(displayName);
            }
            if (!account.isVerified() && email != null) {
                // Apple verifies email
                account.setVerifiedAt(Instant.now());
                account.setStatus(GolferAccount.Status.ACTIVE);
            }
            golferAccountRepository.save(account);
            log.info("Apple auth: linked Apple subject {} to existing account {} via email match",
                    appleSubject, account.getId());
            return buildSocialAuthResponse(account, "APPLE", false);
        }

        // Create a new account
        GolferAccount account = new GolferAccount();
        account.setAppleSubject(appleSubject);
        account.setEmail(email);
        account.setDisplayName(displayName != null ? displayName : "Golfer");
        account.setStatus(GolferAccount.Status.ACTIVE);
        account.setVerifiedAt(Instant.now()); // Apple verifies email

        account = golferAccountRepository.save(account);
        log.info("Apple auth: created new account {} for Apple subject {} (email={})",
                account.getId(), appleSubject, maskEmail(email));

        return buildSocialAuthResponse(account, "APPLE", true);
    }

    private SocialAuthResponse buildSocialAuthResponse(GolferAccount account, String provider, boolean isNewAccount) {
        String accessToken = jwtService.generateAccessToken(account.getId());
        String refreshToken = jwtService.generateRefreshToken(account.getId());

        return SocialAuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .expiresIn(jwtService.getAccessTokenExpirationSeconds())
                .tokenType("Bearer")
                .userId(account.getId())
                .displayName(account.getDisplayName())
                .status(account.getStatus().name())
                .provider(provider)
                .isNewAccount(isNewAccount)
                .build();
    }

    // ─── Helper Methods ────────────────────────────────────────────────────

    private OtpCode createOtp(GolferAccount account, OtpCode.OtpType type) {
        OtpCode otp = new OtpCode();
        otp.setGolferAccount(account);
        otp.setCode(generateOtpCode());
        otp.setType(type);
        otp.setExpiresAt(Instant.now().plus(10, ChronoUnit.MINUTES));
        return otpCodeRepository.save(otp);
    }

    private String generateOtpCode() {
        int code = SECURE_RANDOM.nextInt(900000) + 100000;  // 100000-999999
        return String.valueOf(code);
    }

    private AuthResponse buildAuthResponse(GolferAccount account) {
        String accessToken = jwtService.generateAccessToken(account.getId());
        String refreshToken = jwtService.generateRefreshToken(account.getId());

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .expiresIn(jwtService.getAccessTokenExpirationSeconds())
                .tokenType("Bearer")
                .userId(account.getId())
                .displayName(account.getDisplayName())
                .status(account.getStatus().name())
                .build();
    }

    private GolferAccount resolveAccount(String identifier) {
        if (identifier == null || identifier.isBlank()) {
            return null;
        }

        if (isPhoneIdentifier(identifier)) {
            return golferAccountRepository.findByPhone(identifier).orElse(null);
        } else {
            return golferAccountRepository.findByEmail(identifier).orElse(null);
        }
    }

    private boolean isPhoneIdentifier(String identifier) {
        return PHONE_PATTERN.matcher(identifier).matches();
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 4) return "****";
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 2);
    }

    private String maskEmail(String email) {
        if (email == null || !email.contains("@")) return "****";
        int atIndex = email.indexOf("@");
        if (atIndex < 2) return "****";
        return email.substring(0, 2) + "****" + email.substring(atIndex);
    }

    private String maskIdentifier(String identifier) {
        if (isPhoneIdentifier(identifier)) {
            return maskPhone(identifier);
        } else {
            return maskEmail(identifier);
        }
    }

    /**
     * Builds a non-sensitive JSON metadata string for failed login audit entries.
     * Contains: failure reason, masked identifier, timestamp, and identifier type.
     * Never includes password or other sensitive data.
     */
    private String buildLoginFailedMetadata(String identifier, String reason) {
        return """
                {"reason":"%s","identifier":"%s","identifierType":"%s","timestamp":"%s"}
                """.formatted(
                reason,
                maskIdentifier(identifier),
                isPhoneIdentifier(identifier) ? "phone" : "email",
                Instant.now().toString()
        );
    }
}
