package vnpt.vsp.module.identity;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.module.identity.dto.*;
import vnpt.vsp.module.identity.dto.SessionResponse;
import vnpt.vsp.module.identity.entity.GolferAccount;
import vnpt.vsp.module.identity.entity.OtpCode;
import vnpt.vsp.module.identity.entity.RefreshToken;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;
import vnpt.vsp.module.identity.repository.OtpCodeRepository;
import vnpt.vsp.module.identity.repository.PasswordRecoveryTokenRepository;
import vnpt.vsp.module.identity.repository.RefreshTokenRepository;
import vnpt.vsp.module.identity.security.JwtService;
import vnpt.vsp.module.identity.security.PasswordService;
import vnpt.vsp.module.identity.service.SocialTokenValidatorService;
import vnpt.vsp.module.identity.service.SocialTokenValidatorService.SocialTokenClaims;
import vnpt.vsp.module.audit.AuditService;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link IdentityServiceImpl}.
 * Tests phone/email registration, OTP verification, password recovery, and login flows.
 */
@ExtendWith(MockitoExtension.class)
class IdentityServiceImplTest {

    @Mock
    private GolferAccountRepository golferAccountRepository;

    @Mock
    private OtpCodeRepository otpCodeRepository;

    @Mock
    private PasswordRecoveryTokenRepository passwordRecoveryTokenRepository;

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @Mock
    private SocialTokenValidatorService socialTokenValidator;

    @Mock
    private AuditService auditService;

    private PasswordService passwordService;
    private JwtService jwtService;
    private IdentityService identityService;

    @BeforeEach
    void setUp() {
        passwordService = new PasswordService();
        // Create a JwtService with a test secret
        jwtService = new TestJwtService();

        identityService = new IdentityServiceImpl(
                golferAccountRepository,
                otpCodeRepository,
                passwordRecoveryTokenRepository,
                refreshTokenRepository,
                passwordService,
                jwtService,
                socialTokenValidator,
                auditService
        );
    }

    // ─── Phone Registration Tests ─────────────────────────────────────────────

    @Test
    void registerWithPhone_createsNewAccount_whenPhoneNotExists() {
        // Given
        PhoneRegisterRequest request = new PhoneRegisterRequest();
        request.setPhone("+84901234567");
        request.setPassword("password123");
        request.setDisplayName("Test Golfer");

        when(golferAccountRepository.existsByPhone("+84901234567")).thenReturn(false);
        when(golferAccountRepository.save(any(GolferAccount.class))).thenAnswer(invocation -> {
            GolferAccount account = invocation.getArgument(0);
            account.setId(1L);
            return account;
        });
        when(otpCodeRepository.save(any(OtpCode.class))).thenAnswer(invocation -> invocation.getArgument(0));

        // When
        AuthResponse response = identityService.registerWithPhone(request);

        // Then
        assertNotNull(response);
        assertNotNull(response.getAccessToken());
        assertNotNull(response.getRefreshToken());
        assertEquals(1L, response.getUserId());
        assertEquals("Test Golfer", response.getDisplayName());
        assertEquals("PENDING", response.getStatus());

        verify(golferAccountRepository).save(any(GolferAccount.class));
        verify(otpCodeRepository).save(any(OtpCode.class));
    }

    @Test
    void registerWithPhone_throwsConflict_whenPhoneAlreadyExists() {
        // Given
        PhoneRegisterRequest request = new PhoneRegisterRequest();
        request.setPhone("+84901234567");
        request.setPassword("password123");
        request.setDisplayName("Test Golfer");

        when(golferAccountRepository.existsByPhone("+84901234567")).thenReturn(true);

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.registerWithPhone(request));

        assertEquals(VspErrorCode.AUTH_008, exception.getErrorCode());
        assertEquals("phone", exception.getField());
    }

    // ─── Email Registration Tests ───────────────────────────────────────────

    @Test
    void registerWithEmail_createsNewAccount_whenEmailNotExists() {
        // Given
        EmailRegisterRequest request = new EmailRegisterRequest();
        request.setEmail("test@example.com");
        request.setPassword("password123");
        request.setDisplayName("Test Golfer");

        when(golferAccountRepository.existsByEmail("test@example.com")).thenReturn(false);
        when(golferAccountRepository.save(any(GolferAccount.class))).thenAnswer(invocation -> {
            GolferAccount account = invocation.getArgument(0);
            account.setId(1L);
            return account;
        });
        when(otpCodeRepository.save(any(OtpCode.class))).thenAnswer(invocation -> invocation.getArgument(0));

        // When
        AuthResponse response = identityService.registerWithEmail(request);

        // Then
        assertNotNull(response);
        assertNotNull(response.getAccessToken());
        assertEquals(1L, response.getUserId());

        verify(golferAccountRepository).save(any(GolferAccount.class));
    }

    @Test
    void registerWithEmail_throwsConflict_whenEmailAlreadyExists() {
        // Given
        EmailRegisterRequest request = new EmailRegisterRequest();
        request.setEmail("test@example.com");
        request.setPassword("password123");
        request.setDisplayName("Test Golfer");

        when(golferAccountRepository.existsByEmail("test@example.com")).thenReturn(true);

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.registerWithEmail(request));

        assertEquals(VspErrorCode.AUTH_008, exception.getErrorCode());
        assertEquals("email", exception.getField());
    }

    // ─── Login Tests ─────────────────────────────────────────────────────────

    @Test
    void login_returnsTokens_whenCredentialsValid() {
        // Given
        String phone = "+84901234567";
        String password = "password123";
        String hashedPassword = passwordService.hashPassword(password);

        GolferAccount account = new GolferAccount();
        account.setId(1L);
        account.setPhone(phone);
        account.setPasswordHash(hashedPassword);
        account.setDisplayName("Test Golfer");
        account.setStatus(GolferAccount.Status.ACTIVE);

        when(golferAccountRepository.findByPhone(phone)).thenReturn(Optional.of(account));

        // When
        AuthResponse response = identityService.login(phone, password);

        // Then
        assertNotNull(response);
        assertNotNull(response.getAccessToken());
        assertNotNull(response.getRefreshToken());
        assertEquals(1L, response.getUserId());
    }

    @Test
    void login_throwsInvalidCredentials_whenPasswordWrong() {
        // Given
        String phone = "+84901234567";
        String correctPassword = "password123";
        String wrongPassword = "wrongpassword";
        String hashedPassword = passwordService.hashPassword(correctPassword);

        GolferAccount account = new GolferAccount();
        account.setId(1L);
        account.setPhone(phone);
        account.setPasswordHash(hashedPassword);
        account.setDisplayName("Test Golfer");
        account.setStatus(GolferAccount.Status.ACTIVE);

        when(golferAccountRepository.findByPhone(phone)).thenReturn(Optional.of(account));

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.login(phone, wrongPassword));

        assertEquals(VspErrorCode.AUTH_001, exception.getErrorCode());
    }

    @Test
    void login_throwsInvalidCredentials_whenAccountNotFound() {
        // Given
        String phone = "+84901234567";
        when(golferAccountRepository.findByPhone(phone)).thenReturn(Optional.empty());

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.login(phone, "password123"));

        assertEquals(VspErrorCode.AUTH_001, exception.getErrorCode());
    }

    @Test
    void login_throwsAccountLocked_whenAccountSuspended() {
        // Given
        String phone = "+84901234567";
        String password = "password123";
        String hashedPassword = passwordService.hashPassword(password);

        GolferAccount account = new GolferAccount();
        account.setId(1L);
        account.setPhone(phone);
        account.setPasswordHash(hashedPassword);
        account.setDisplayName("Test Golfer");
        account.setStatus(GolferAccount.Status.SUSPENDED);

        when(golferAccountRepository.findByPhone(phone)).thenReturn(Optional.of(account));

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.login(phone, password));

        assertEquals(VspErrorCode.AUTH_004, exception.getErrorCode());
    }

    // ─── Profile Tests ────────────────────────────────────────────────────────

    @Test
    void getCurrentProfile_returnsProfile_whenAccountExists() {
        // Given
        Long accountId = 1L;
        GolferAccount account = new GolferAccount();
        account.setId(accountId);
        account.setPhone("+84901234567");
        account.setEmail("test@example.com");
        account.setDisplayName("Test Golfer");
        account.setStatus(GolferAccount.Status.ACTIVE);
        account.setVerifiedAt(java.time.Instant.now());

        when(golferAccountRepository.findById(accountId)).thenReturn(Optional.of(account));

        // When
        GolferProfileResponse response = identityService.getCurrentProfile(accountId);

        // Then
        assertNotNull(response);
        assertEquals(accountId, response.getId());
        assertEquals("+84901234567", response.getPhone());
        assertEquals("test@example.com", response.getEmail());
        assertEquals("Test Golfer", response.getDisplayName());
        assertEquals("ACTIVE", response.getStatus());
        assertTrue(response.isVerified());
    }

    @Test
    void getCurrentProfile_throwsNotFound_whenAccountNotExists() {
        // Given
        Long accountId = 999L;
        when(golferAccountRepository.findById(accountId)).thenReturn(Optional.empty());

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.getCurrentProfile(accountId));

        assertEquals(VspErrorCode.AUTH_006, exception.getErrorCode());
    }

    // ─── Token Validation Tests ───────────────────────────────────────────────

    @Test
    void validateAccessToken_returnsAccountId_whenTokenValid() {
        // Given
        Long accountId = 1L;
        String accessToken = jwtService.generateAccessToken(accountId);

        // When
        Long result = identityService.validateAccessToken(accessToken);

        // Then
        assertEquals(accountId, result);
    }

    @Test
    void validateAccessToken_returnsNull_whenTokenInvalid() {
        // Given
        String invalidToken = "invalid.token.here";

        // When
        Long result = identityService.validateAccessToken(invalidToken);

        // Then
        assertNull(result);
    }

    // ─── Password Recovery Tests ──────────────────────────────────────────────

    @Test
    void initiatePasswordRecovery_returnsSuccess_whenAccountExists() {
        // Given
        String email = "test@example.com";
        GolferAccount account = new GolferAccount();
        account.setId(1L);
        account.setEmail(email);
        account.setPasswordHash("somehash");
        account.setStatus(GolferAccount.Status.ACTIVE);

        when(golferAccountRepository.findByEmail(email)).thenReturn(Optional.of(account));
        when(otpCodeRepository.save(any(OtpCode.class))).thenAnswer(invocation -> invocation.getArgument(0));

        PasswordRecoverRequest request = new PasswordRecoverRequest();
        request.setIdentifier(email);

        // When
        OtpSendResponse response = identityService.initiatePasswordRecovery(request);

        // Then
        assertNotNull(response);
        assertEquals("Verification code sent", response.getMessage());

        verify(passwordRecoveryTokenRepository).deleteByGolferAccountId(1L);
        verify(otpCodeRepository).save(any(OtpCode.class));
    }

    @Test
    void initiatePasswordRecovery_returnsSuccess_whenAccountNotExists() {
        // Given - non-existent account should still return success (don't reveal existence)
        when(golferAccountRepository.findByEmail("nonexistent@example.com")).thenReturn(Optional.empty());

        PasswordRecoverRequest request = new PasswordRecoverRequest();
        request.setIdentifier("nonexistent@example.com");

        // When
        OtpSendResponse response = identityService.initiatePasswordRecovery(request);

        // Then
        assertNotNull(response);
        assertEquals("Verification code sent", response.getMessage());
    }

    // ─── Google Auth Tests ─────────────────────────────────────────────────────

    @Test
    void authenticateWithGoogle_createsNewAccount_whenGoogleSubjectNotRegistered() {
        // Given
        GoogleAuthRequest request = new GoogleAuthRequest("google.id.token");
        request.setDisplayName("Google Golfer");

        SocialTokenClaims claims = new SocialTokenClaims(
                "google-subject-123",
                "google@example.com",
                "Google Golfer",
                "GOOGLE"
        );

        when(socialTokenValidator.validateGoogleToken("google.id.token"))
                .thenReturn(Optional.of(claims));
        when(golferAccountRepository.findByGoogleSubject("google-subject-123"))
                .thenReturn(Optional.empty());
        when(golferAccountRepository.findByEmail("google@example.com"))
                .thenReturn(Optional.empty());
        when(golferAccountRepository.save(any(GolferAccount.class))).thenAnswer(invocation -> {
            GolferAccount account = invocation.getArgument(0);
            account.setId(1L);
            return account;
        });

        // When
        SocialAuthResponse response = identityService.authenticateWithGoogle(request);

        // Then
        assertNotNull(response);
        assertNotNull(response.getAccessToken());
        assertNotNull(response.getRefreshToken());
        assertEquals(1L, response.getUserId());
        assertEquals("GOOGLE", response.getProvider());
        assertTrue(response.isNewAccount());

        verify(golferAccountRepository).save(any(GolferAccount.class));
    }

    @Test
    void authenticateWithGoogle_linksExistingAccount_whenEmailMatches() {
        // Given
        GoogleAuthRequest request = new GoogleAuthRequest("google.id.token");

        SocialTokenClaims claims = new SocialTokenClaims(
                "google-subject-456",
                "existing@example.com",
                "Google Golfer",
                "GOOGLE"
        );

        GolferAccount existingAccount = new GolferAccount();
        existingAccount.setId(2L);
        existingAccount.setEmail("existing@example.com");
        existingAccount.setDisplayName("Existing Golfer");
        existingAccount.setStatus(GolferAccount.Status.ACTIVE);
        // No google subject yet

        when(socialTokenValidator.validateGoogleToken("google.id.token"))
                .thenReturn(Optional.of(claims));
        when(golferAccountRepository.findByGoogleSubject("google-subject-456"))
                .thenReturn(Optional.empty());
        when(golferAccountRepository.findByEmail("existing@example.com"))
                .thenReturn(Optional.of(existingAccount));
        when(golferAccountRepository.save(any(GolferAccount.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        // When
        SocialAuthResponse response = identityService.authenticateWithGoogle(request);

        // Then
        assertNotNull(response);
        assertEquals(2L, response.getUserId());
        assertEquals("GOOGLE", response.getProvider());
        assertFalse(response.isNewAccount());

        // Verify the Google subject was linked
        verify(golferAccountRepository).save(argThat(account ->
                "google-subject-456".equals(account.getGoogleSubject())
        ));
    }

    @Test
    void authenticateWithGoogle_returnsExistingAccount_whenGoogleSubjectAlreadyLinked() {
        // Given
        GoogleAuthRequest request = new GoogleAuthRequest("google.id.token");

        SocialTokenClaims claims = new SocialTokenClaims(
                "google-subject-789",
                "google@example.com",
                "Google Golfer",
                "GOOGLE"
        );

        GolferAccount existingAccount = new GolferAccount();
        existingAccount.setId(3L);
        existingAccount.setEmail("google@example.com");
        existingAccount.setGoogleSubject("google-subject-789");
        existingAccount.setDisplayName("Already Linked Golfer");
        existingAccount.setStatus(GolferAccount.Status.ACTIVE);

        when(socialTokenValidator.validateGoogleToken("google.id.token"))
                .thenReturn(Optional.of(claims));
        when(golferAccountRepository.findByGoogleSubject("google-subject-789"))
                .thenReturn(Optional.of(existingAccount));

        // When
        SocialAuthResponse response = identityService.authenticateWithGoogle(request);

        // Then
        assertNotNull(response);
        assertEquals(3L, response.getUserId());
        assertEquals("GOOGLE", response.getProvider());
        assertFalse(response.isNewAccount());

        // No save needed - just returns existing
        verify(golferAccountRepository, never()).save(any(GolferAccount.class));
    }

    @Test
    void authenticateWithGoogle_throwsAuth014_whenTokenInvalid() {
        // Given
        GoogleAuthRequest request = new GoogleAuthRequest("invalid.token");

        when(socialTokenValidator.validateGoogleToken("invalid.token"))
                .thenReturn(Optional.empty());

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.authenticateWithGoogle(request));

        assertEquals(VspErrorCode.AUTH_014, exception.getErrorCode());
    }

    // ─── Apple Auth Tests ─────────────────────────────────────────────────────

    @Test
    void authenticateWithApple_createsNewAccount_whenAppleSubjectNotRegistered() {
        // Given
        AppleAuthRequest request = new AppleAuthRequest("apple.id.token");
        request.setDisplayName("Apple Golfer");

        SocialTokenClaims claims = new SocialTokenClaims(
                "apple-subject-123",
                "apple@example.com",
                "Apple Golfer",
                "APPLE"
        );

        when(socialTokenValidator.validateAppleToken("apple.id.token"))
                .thenReturn(Optional.of(claims));
        when(golferAccountRepository.findByAppleSubject("apple-subject-123"))
                .thenReturn(Optional.empty());
        when(golferAccountRepository.findByEmail("apple@example.com"))
                .thenReturn(Optional.empty());
        when(golferAccountRepository.save(any(GolferAccount.class))).thenAnswer(invocation -> {
            GolferAccount account = invocation.getArgument(0);
            account.setId(1L);
            return account;
        });

        // When
        SocialAuthResponse response = identityService.authenticateWithApple(request);

        // Then
        assertNotNull(response);
        assertNotNull(response.getAccessToken());
        assertEquals(1L, response.getUserId());
        assertEquals("APPLE", response.getProvider());
        assertTrue(response.isNewAccount());

        verify(golferAccountRepository).save(any(GolferAccount.class));
    }

    @Test
    void authenticateWithApple_linksExistingAccount_whenEmailMatches() {
        // Given
        AppleAuthRequest request = new AppleAuthRequest("apple.id.token");

        SocialTokenClaims claims = new SocialTokenClaims(
                "apple-subject-456",
                "existing@example.com",
                "Apple Golfer",
                "APPLE"
        );

        GolferAccount existingAccount = new GolferAccount();
        existingAccount.setId(2L);
        existingAccount.setEmail("existing@example.com");
        existingAccount.setGoogleSubject("google-subject-linked"); // Already has Google linked
        existingAccount.setDisplayName("Canonical Golfer");
        existingAccount.setStatus(GolferAccount.Status.ACTIVE);

        when(socialTokenValidator.validateAppleToken("apple.id.token"))
                .thenReturn(Optional.of(claims));
        when(golferAccountRepository.findByAppleSubject("apple-subject-456"))
                .thenReturn(Optional.empty());
        when(golferAccountRepository.findByEmail("existing@example.com"))
                .thenReturn(Optional.of(existingAccount));
        when(golferAccountRepository.save(any(GolferAccount.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        // When
        SocialAuthResponse response = identityService.authenticateWithApple(request);

        // Then
        assertNotNull(response);
        assertEquals(2L, response.getUserId());
        assertEquals("APPLE", response.getProvider());
        assertFalse(response.isNewAccount());

        // Verify the Apple subject was linked
        verify(golferAccountRepository).save(argThat(account ->
                "apple-subject-456".equals(account.getAppleSubject())
        ));
    }

    @Test
    void authenticateWithApple_throwsAuth015_whenTokenInvalid() {
        // Given
        AppleAuthRequest request = new AppleAuthRequest("invalid.apple.token");

        when(socialTokenValidator.validateAppleToken("invalid.apple.token"))
                .thenReturn(Optional.empty());

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.authenticateWithApple(request));

        assertEquals(VspErrorCode.AUTH_015, exception.getErrorCode());
    }

    // ─── Session Management Tests ──────────────────────────────────────────────

    @Test
    void rotateRefreshToken_issuesNewTokens_and_revokesOldToken() {
        // Given
        Long accountId = 1L;
        String oldRefreshToken = jwtService.generateRefreshToken(accountId);
        String tokenHash = jwtService.hashToken(oldRefreshToken);

        GolferAccount account = new GolferAccount();
        account.setId(accountId);
        account.setDisplayName("Test Golfer");
        account.setStatus(GolferAccount.Status.ACTIVE);

        RefreshToken storedToken = new RefreshToken();
        storedToken.setId(10L);
        storedToken.setGolferAccount(account);
        storedToken.setTokenHash(tokenHash);
        storedToken.setExpiresAt(java.time.Instant.now().plusSeconds(86400));
        // not revoked

        when(refreshTokenRepository.findActiveByAccountIdAndTokenHash(eq(accountId), eq(tokenHash), any(java.time.Instant.class)))
                .thenReturn(Optional.of(storedToken));
        when(refreshTokenRepository.save(any(RefreshToken.class))).thenAnswer(invocation -> {
            RefreshToken rt = invocation.getArgument(0);
            if (rt.getId() == null) rt.setId(11L);
            return rt;
        });

        // When
        AuthResponse response = identityService.rotateRefreshToken(
                oldRefreshToken, "iPhone 15", "Mozilla/5.0", "203.0.113.1");

        // Then
        assertNotNull(response);
        assertNotNull(response.getAccessToken());
        assertNotNull(response.getRefreshToken());
        assertEquals(accountId, response.getUserId());

        // Verify old token was revoked and linked to new token
        assertNotNull(storedToken.getRevokedAt());
        assertNotNull(storedToken.getReplacedByToken());
        assertEquals(11L, storedToken.getReplacedByToken().getId());
    }

    @Test
    void rotateRefreshToken_throwsAuth006_whenTokenNotFoundInDb() {
        // Given
        Long accountId = 1L;
        String oldRefreshToken = jwtService.generateRefreshToken(accountId);
        String tokenHash = jwtService.hashToken(oldRefreshToken);

        when(refreshTokenRepository.findActiveByAccountIdAndTokenHash(eq(accountId), eq(tokenHash), any(java.time.Instant.class)))
                .thenReturn(Optional.empty());

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.rotateRefreshToken(oldRefreshToken, null, null, null));

        assertEquals(VspErrorCode.AUTH_006, exception.getErrorCode());
    }

    @Test
    void rotateRefreshToken_throwsAuth003_whenNotARefreshToken() {
        // Given
        String notARefreshToken = "not-a-refresh-token";

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.rotateRefreshToken(notARefreshToken, null, null, null));

        assertEquals(VspErrorCode.AUTH_003, exception.getErrorCode());
    }

    @Test
    void listSessions_returnsActiveSessions_markingCurrentSession() {
        // Given
        Long accountId = 1L;
        Long currentTokenId = 10L;

        GolferAccount account = new GolferAccount();
        account.setId(accountId);

        RefreshToken token1 = new RefreshToken();
        token1.setId(10L);
        token1.setGolferAccount(account);
        token1.setDeviceInfo("iPhone 15");
        token1.setUserAgent("Mozilla/5.0");
        token1.setIpAddress("203.0.113.1");
        token1.setExpiresAt(java.time.Instant.now().plusSeconds(86400));

        RefreshToken token2 = new RefreshToken();
        token2.setId(20L);
        token2.setGolferAccount(account);
        token2.setDeviceInfo("Android Pixel 8");
        token2.setUserAgent("Mozilla/5.0 Android");
        token2.setIpAddress("198.51.100.5");
        token2.setExpiresAt(java.time.Instant.now().plusSeconds(86400));

        when(refreshTokenRepository.findActiveSessionsByAccountId(eq(accountId), any(java.time.Instant.class)))
                .thenReturn(List.of(token1, token2));

        // When
        List<SessionResponse> sessions = identityService.listSessions(accountId, currentTokenId);

        // Then
        assertEquals(2, sessions.size());

        SessionResponse current = sessions.stream()
                .filter(SessionResponse::isCurrentSession)
                .findFirst()
                .orElseThrow();
        assertEquals(10L, current.getSessionId());
        assertEquals("iPhone 15", current.getDeviceInfo());
        assertEquals("203.0.113.1", current.getIpAddress());

        SessionResponse other = sessions.stream()
                .filter(s -> !s.isCurrentSession())
                .findFirst()
                .orElseThrow();
        assertEquals(20L, other.getSessionId());
        assertEquals("Android Pixel 8", other.getDeviceInfo());
    }

    @Test
    void listSessions_returnsEmptyList_whenNoActiveSessions() {
        // Given
        Long accountId = 1L;
        when(refreshTokenRepository.findActiveSessionsByAccountId(eq(accountId), any(java.time.Instant.class)))
                .thenReturn(List.of());

        // When
        List<SessionResponse> sessions = identityService.listSessions(accountId, null);

        // Then
        assertTrue(sessions.isEmpty());
    }

    @Test
    void revokeSession_revokesToken_whenSessionExists() {
        // Given
        Long accountId = 1L;
        Long sessionId = 10L;

        GolferAccount account = new GolferAccount();
        account.setId(accountId);

        RefreshToken token = new RefreshToken();
        token.setId(sessionId);
        token.setGolferAccount(account);
        token.setExpiresAt(java.time.Instant.now().plusSeconds(86400));
        // not revoked

        when(refreshTokenRepository.findByIdAndGolferAccountId(sessionId, accountId))
                .thenReturn(Optional.of(token));

        // When
        identityService.revokeSession(accountId, sessionId);

        // Then
        assertNotNull(token.getRevokedAt());
        verify(refreshTokenRepository).save(token);
    }

    @Test
    void revokeSession_throwsAuth018_whenSessionNotFound() {
        // Given
        Long accountId = 1L;
        Long sessionId = 999L;

        when(refreshTokenRepository.findByIdAndGolferAccountId(sessionId, accountId))
                .thenReturn(Optional.empty());

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.revokeSession(accountId, sessionId));

        assertEquals(VspErrorCode.AUTH_018, exception.getErrorCode());
    }

    @Test
    void revokeSession_throwsAuth019_whenSessionAlreadyRevoked() {
        // Given
        Long accountId = 1L;
        Long sessionId = 10L;

        GolferAccount account = new GolferAccount();
        account.setId(accountId);

        RefreshToken token = new RefreshToken();
        token.setId(sessionId);
        token.setGolferAccount(account);
        token.setExpiresAt(java.time.Instant.now().plusSeconds(86400));
        token.setRevokedAt(java.time.Instant.now().minusSeconds(60)); // already revoked

        when(refreshTokenRepository.findByIdAndGolferAccountId(sessionId, accountId))
                .thenReturn(Optional.of(token));

        // When/Then
        VspApiException exception = assertThrows(VspApiException.class,
                () -> identityService.revokeSession(accountId, sessionId));

        assertEquals(VspErrorCode.AUTH_019, exception.getErrorCode());
    }

    @Test
    void revokeAllSessions_revokesAllActiveSessions_and_returnsCount() {
        // Given
        Long accountId = 1L;
        when(refreshTokenRepository.revokeAllActiveSessions(eq(accountId), any(java.time.Instant.class), any(java.time.Instant.class)))
                .thenReturn(3);

        // When
        int count = identityService.revokeAllSessions(accountId);

        // Then
        assertEquals(3, count);
        verify(refreshTokenRepository).revokeAllActiveSessions(eq(accountId), any(java.time.Instant.class), any(java.time.Instant.class));
    }

    // ─── Helper Class for Testing ────────────────────────────────────────────

    /**
     * Test implementation of JwtService that doesn't require Spring context.
     */
    private static class TestJwtService extends JwtService {
        private static final String TEST_SECRET = "test-secret-key-for-unit-testing-must-be-at-least-256-bits-long";

        @Override
        public String generateAccessToken(Long golferAccountId) {
            return createToken(golferAccountId, "access", 3600000);
        }

        @Override
        public String generateRefreshToken(Long golferAccountId) {
            return createToken(golferAccountId, "refresh", 604800000);
        }

        @Override
        public Long validateToken(String token) {
            try {
                String[] parts = token.split("\\.");
                if (parts.length != 3) return null;
                String payloadJson = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
                // Extract "sub":"<id>" from the payload JSON
                int subStart = payloadJson.indexOf("\"sub\":\"") + 7;
                int subEnd = payloadJson.indexOf("\"", subStart);
                return Long.parseLong(payloadJson.substring(subStart, subEnd));
            } catch (Exception e) {
                return null;
            }
        }

        @Override
        public int getAccessTokenExpirationSeconds() {
            return 3600;
        }

        @Override
        public boolean isAccessToken(String token) {
            try {
                String[] parts = token.split("\\.");
                if (parts.length != 3) return false;
                String payload = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
                return payload.contains("\"type\":\"access\"");
            } catch (Exception e) {
                return false;
            }
        }

        @Override
        public boolean isRefreshToken(String token) {
            try {
                String[] parts = token.split("\\.");
                if (parts.length != 3) return false;
                String payload = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
                return payload.contains("\"type\":\"refresh\"");
            } catch (Exception e) {
                return false;
            }
        }

        @Override
        public String hashToken(String token) {
            try {
                java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
                byte[] hash = digest.digest(token.getBytes(java.nio.charset.StandardCharsets.UTF_8));
                StringBuilder hexString = new StringBuilder();
                for (byte b : hash) {
                    String hex = Integer.toHexString(0xff & b);
                    if (hex.length() == 1) hexString.append('0');
                    hexString.append(hex);
                }
                return hexString.toString();
            } catch (Exception e) {
                throw new RuntimeException("SHA-256 not available", e);
            }
        }

        @Override
        public long getRefreshTokenExpirationMs() {
            return 604800000L; // 7 days in ms
        }

        private String createToken(Long accountId, String type, long expiration) {
            String header = java.util.Base64.getUrlEncoder().withoutPadding()
                    .encodeToString("{\"alg\":\"HS256\",\"typ\":\"JWT\"}".getBytes());
            String payload = java.util.Base64.getUrlEncoder().withoutPadding()
                    .encodeToString(String.format("{\"sub\":\"%d\",\"type\":\"%s\",\"iat\":%d,\"exp\":%d}",
                            accountId, type, System.currentTimeMillis() / 1000,
                            (System.currentTimeMillis() + expiration) / 1000).getBytes());
            String signature = java.util.Base64.getUrlEncoder().withoutPadding()
                    .encodeToString("test-signature".getBytes());
            return header + "." + payload + "." + signature;
        }
    }
}
