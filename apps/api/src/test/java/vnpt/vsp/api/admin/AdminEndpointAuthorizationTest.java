package vnpt.vsp.api.admin;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.identity.security.JwtService;
import vnpt.vsp.module.role.entity.AdminAccount;
import vnpt.vsp.module.role.entity.AdminRoleAssignment;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.role.repository.AdminAccountRepository;
import vnpt.vsp.module.role.repository.AdminRoleAssignmentRepository;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Who may reach the admin surface, checked through the whole stack: a real
 * bearer token, the real filter chain, the real {@code @PreAuthorize}.
 *
 * <p>Every one of these endpoints answered {@code 403} with an empty body to
 * everyone, admins included, because the {@code /admin/**} filter chain was
 * built without the JWT filter and every request arrived anonymous. The obvious
 * repair — adding the filter — is only half of one: two endpoints here
 * ({@code GET /admin/roles}, {@code GET /admin/users}) had no authorization
 * check of any kind, so on its own it would have opened the admin directory to
 * every signed-in golfer. This test is what says the two halves landed
 * together, so it asserts on both sides of every row:</p>
 *
 * <ul>
 *   <li>no token — refused, and refused with a body that says why</li>
 *   <li>an ordinary golfer's token — refused</li>
 *   <li>an admin holding a role the endpoint does not name — refused, which is
 *       what proves the per-endpoint annotation is doing the work and not just
 *       the "some admin role" floor on the URL</li>
 *   <li>the role the endpoint names — reaches the handler</li>
 * </ul>
 *
 * <p>One row per controller class, because the defect was per-class: a class
 * with no annotation was invisible while everything answered 403.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AdminEndpointAuthorizationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private AdminAccountRepository adminAccountRepository;
    @Autowired private AdminRoleAssignmentRepository roleAssignmentRepository;
    @jakarta.persistence.PersistenceContext private jakarta.persistence.EntityManager entityManager;

    /** Account ids well outside anything another test seeds. */
    private static final long GOLFER_ID = 990_000L;
    private static final long FIRST_ADMIN_ID = 990_001L;

    private final Map<RoleName, String> tokenByRole = new EnumMap<>(RoleName.class);
    private String golferToken;

    /**
     * One admin account per role, plus a golfer with no admin account at all.
     * Roles are read from the database on every request, so an account that
     * exists only in the token would be indistinguishable from a golfer.
     */
    @BeforeEach
    void seedAccounts() {
        golferToken = jwtService.generateAccessToken(GOLFER_ID);

        long accountId = FIRST_ADMIN_ID;
        for (RoleName role : RoleName.values()) {
            AdminAccount account = new AdminAccount();
            account.setGolferAccountId(accountId);
            account.setMfaEnabled(false);
            adminAccountRepository.saveAndFlush(account);

            AdminRoleAssignment assignment = new AdminRoleAssignment();
            assignment.setAdminAccount(account);
            assignment.setRoleName(role);
            roleAssignmentRepository.saveAndFlush(assignment);

            tokenByRole.put(role, jwtService.generateAccessToken(accountId));
            accountId++;
        }

        // The assignment was written through its own repository, so the account
        // still held in this session has the empty roleAssignments collection it
        // was constructed with. Anything reading an account through the mapping
        // — GET /admin/me does — would see no roles. Dropping the session makes
        // the next read load what the database actually holds, which is what a
        // request arriving on its own transaction gets.
        entityManager.flush();
        entityManager.clear();
    }

    /**
     * One endpoint per admin controller class, with the role it names.
     * <p>
     * CADDIE_MASTER is deliberately absent from every row: it is an admin role,
     * so it clears the URL-level floor, which makes it the token that tells a
     * working per-endpoint annotation from a missing one.
     */
    static Stream<Endpoint> endpoints() {
        return Stream.of(
                new Endpoint("RoleController", HttpMethod.GET, "/admin/roles", RoleName.SUPER_ADMIN),
                new Endpoint("RoleController", HttpMethod.GET, "/admin/users", RoleName.SUPER_ADMIN),
                new Endpoint("FacilityAdminController", HttpMethod.GET, "/admin/facilities", RoleName.COURSE_ADMIN),
                new Endpoint("CourseAdminController", HttpMethod.GET, "/admin/facilities/1/courses", RoleName.COURSE_ADMIN),
                new Endpoint("HoleAdminController", HttpMethod.GET, "/admin/courses/1/holes", RoleName.COURSE_ADMIN),
                new Endpoint("TeeSetAdminController", HttpMethod.GET, "/admin/courses/1/tee-sets", RoleName.COURSE_ADMIN),
                new Endpoint("PinPositionController", HttpMethod.GET, "/admin/courses/1/pins", RoleName.GREENKEEPER),
                new Endpoint("GreenConditionController", HttpMethod.GET, "/admin/courses/1/green-conditions", RoleName.GREENKEEPER),
                new Endpoint("CourseConditionController", HttpMethod.GET, "/admin/courses/1/conditions", RoleName.GREENKEEPER),
                new Endpoint("CorrectionController", HttpMethod.GET, "/admin/corrections", RoleName.GREENKEEPER),
                new Endpoint("CourseAlertController", HttpMethod.GET, "/admin/alerts", RoleName.COURSE_ADMIN),
                new Endpoint("DataQualityController", HttpMethod.GET, "/admin/data-quality/stale", RoleName.AUDITOR),
                new Endpoint("GeometryController", HttpMethod.GET, "/admin/courses/1/geometry/draft", RoleName.COURSE_ADMIN),
                new Endpoint("CourseImportController", HttpMethod.POST, "/admin/courses/1/import/preview", RoleName.COURSE_ADMIN),
                new Endpoint("DataLicenseController", HttpMethod.GET, "/admin/licenses", RoleName.SUPER_ADMIN),
                new Endpoint("AdminMarketController", HttpMethod.GET, "/admin/markets", RoleName.SUPER_ADMIN),
                new Endpoint("PrivacyController", HttpMethod.GET, "/admin/privacy-requests", RoleName.AUDITOR),
                // Not under /admin/**, so no URL-level floor protects it — the
                // annotation is the only thing standing between a golfer and a
                // course rollback.
                new Endpoint("CourseVersionController", HttpMethod.GET, "/courses/1/versions", RoleName.COURSE_ADMIN),

                // Geometry review. This is the one action that flips a hole to
                // VERIFIED, which is what the mobile app's provenance gate reads
                // before it will draw a strategic map or walk a golfer to a
                // hole — so a golfer must not be able to reach it about their
                // own course data.
                new Endpoint("GeometryReviewController", HttpMethod.GET, "/admin/courses/1/geometry/review", RoleName.COURSE_ADMIN),
                // A valid body on purpose: @Valid binding runs before method
                // security, so an empty one answers 400 and this row would
                // prove nothing about who is allowed in.
                new Endpoint("GeometryReviewController", HttpMethod.POST, "/admin/courses/1/geometry/verify", RoleName.COURSE_ADMIN,
                        "{\"holeNumbers\":[1],\"note\":\"Checked against imagery\"}"),
                // Par decides what every golfer's over/under-par figure is
                // measured against, so it is gated exactly like verification.
                new Endpoint("GeometryReviewController", HttpMethod.POST, "/admin/courses/1/geometry/par", RoleName.COURSE_ADMIN,
                        "{\"holes\":[{\"holeNumber\":1,\"par\":4}],\"note\":\"From the printed scorecard\"}"),

                // Package builds. The controller's own comment claimed
                // COURSE_ADMIN was required and no annotation enforced it, so a
                // freshly registered golfer could trigger one and get a job id.
                // A build republishes the course package, which tells every
                // device holding that course to download it again.
                new Endpoint("PackageBuildController", HttpMethod.POST, "/courses/1/packages/build", RoleName.COURSE_ADMIN,
                        "{\"dataVersionId\":1,\"triggeredBy\":\"test\"}"),
                new Endpoint("PackageBuildController", HttpMethod.GET, "/courses/1/packages/build/jobs", RoleName.COURSE_ADMIN),

                // The tournament surface and the loyalty surface, likewise
                // outside /admin/**, likewise annotation-only. Every one of
                // these rows was reachable by any signed-in golfer until the
                // annotations landed: creating a tournament, redrawing its
                // flights, inventing tee times, entering players, and declaring
                // who won.
                new Endpoint("TournamentController", HttpMethod.POST,
                        "/tournaments", RoleName.TOURNAMENT_DIRECTOR,
                        """
                        {"name":"Guarded Open","format":"STROKE_PLAY","courseId":1,
                         "startDate":"2030-01-01T00:00:00Z","endDate":"2030-01-02T00:00:00Z"}"""),
                new Endpoint("FlightController", HttpMethod.POST,
                        "/tournaments/" + SOME_TOURNAMENT + "/flights", RoleName.TOURNAMENT_DIRECTOR,
                        """
                        {"flightNumber":1,"startingTee":"FRONT"}"""),
                new Endpoint("TeeTimeController", HttpMethod.POST,
                        "/tournaments/" + SOME_TOURNAMENT + "/tee-times", RoleName.TOURNAMENT_DIRECTOR,
                        """
                        {"teeTime":"2030-01-01T00:00:00Z","courseId":1}"""),
                new Endpoint("TournamentRegistrationController", HttpMethod.POST,
                        "/tournaments/" + SOME_TOURNAMENT + "/players", RoleName.TOURNAMENT_DIRECTOR),
                new Endpoint("TournamentResultController", HttpMethod.POST,
                        "/tournaments/" + SOME_TOURNAMENT + "/results/publish", RoleName.TOURNAMENT_DIRECTOR),

                // Running a club outing. The score endpoint is the one that
                // matters here: a golfer who could reach it could type their
                // own card, and the prizes are decided off exactly these
                // numbers minutes later.
                new Endpoint("OutingController", HttpMethod.POST,
                        "/tournaments/" + SOME_TOURNAMENT + "/outing/scores",
                        RoleName.TOURNAMENT_DIRECTOR, "[]"),
                new Endpoint("OutingController", HttpMethod.PUT,
                        "/tournaments/" + SOME_TOURNAMENT + "/outing/roster",
                        RoleName.TOURNAMENT_DIRECTOR, "[]"),
                new Endpoint("OutingController", HttpMethod.GET,
                        "/tournaments/" + SOME_TOURNAMENT + "/outing/results",
                        RoleName.TOURNAMENT_DIRECTOR),
                new Endpoint("OutingController", HttpMethod.POST,
                        "/tournaments/" + SOME_TOURNAMENT + "/outing/technical",
                        RoleName.TOURNAMENT_DIRECTOR, "[]"),

                // Reading a loyalty account by id reads somebody else's balance
                // and, next door, their whole transaction history.
                // Listing every policy exposes each club's tie-break and
                // handicap rules; it is a read a golfer must not have.
                new Endpoint("TournamentPolicyController", HttpMethod.GET,
                        "/tournament-policies", RoleName.TOURNAMENT_DIRECTOR),

                new Endpoint("LoyaltyController", HttpMethod.GET,
                        "/loyalty/accounts/some-account", RoleName.SUPER_ADMIN)
        );
    }

    /** A tournament id no seed data uses; the rows above only need the route to resolve. */
    private static final String SOME_TOURNAMENT = "11111111-1111-1111-1111-111111111111";

    @ParameterizedTest(name = "{0}")
    @MethodSource("endpoints")
    @DisplayName("A request with no token is refused, and says so in the body")
    void anonymousIsRefused(Endpoint endpoint) throws Exception {
        mockMvc.perform(endpoint.build(null))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("VSP-ERR-AUTH-001"))
                .andExpect(jsonPath("$.message").isNotEmpty());
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("endpoints")
    @DisplayName("An ordinary golfer's token is refused with 403 and an error body")
    void golferIsRefused(Endpoint endpoint) throws Exception {
        mockMvc.perform(endpoint.build(golferToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("VSP-ERR-AUTH-005"))
                .andExpect(jsonPath("$.message").isNotEmpty());
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("endpoints")
    @DisplayName("An admin holding an unrelated role is refused — the URL floor is not the only gate")
    void wrongAdminRoleIsRefused(Endpoint endpoint) throws Exception {
        mockMvc.perform(endpoint.build(tokenByRole.get(RoleName.CADDIE_MASTER)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("VSP-ERR-AUTH-005"));
    }

    /**
     * The role the endpoint names reaches the handler. What the handler then
     * answers is that endpoint's business — the test database holds no course 1
     * — so this asserts only that the request was not turned away by security.
     */
    @ParameterizedTest(name = "{0}")
    @MethodSource("endpoints")
    @DisplayName("The role the endpoint names reaches the handler")
    void namedRoleReachesTheHandler(Endpoint endpoint) throws Exception {
        int statusCode = mockMvc.perform(endpoint.build(tokenByRole.get(endpoint.role())))
                .andReturn().getResponse().getStatus();

        org.junit.jupiter.api.Assertions.assertFalse(
                statusCode == 401 || statusCode == 403,
                endpoint + " refused the role it requires (HTTP " + statusCode + ")");
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("listingEndpoints")
    @DisplayName("The two endpoints with no in-method check answer 200 to a SUPER_ADMIN")
    void listingEndpointsServeSuperAdmin(String path) throws Exception {
        mockMvc.perform(request(HttpMethod.GET, path)
                        .header("Authorization", "Bearer " + tokenByRole.get(RoleName.SUPER_ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    static Stream<String> listingEndpoints() {
        return Stream.of("/admin/roles", "/admin/users");
    }

    // ─── GET /admin/me ───────────────────────────────────────────────────────

    /**
     * {@code /admin/me} is the one admin endpoint every admin role may reach, so
     * it cannot be a row in the table above — those rows prove that a role the
     * endpoint does not name is refused. It gets its own three tests, asserting
     * the same three boundaries.
     * <p>
     * It exists because the operations portal had no way to learn who it was
     * talking as, and answered the question itself in TypeScript. What the
     * portal is allowed to do has to be a fact the server states.
     */
    @ParameterizedTest(name = "{0}")
    @org.junit.jupiter.params.provider.EnumSource(RoleName.class)
    @DisplayName("Every admin role may read its own identity, and gets its own roles back")
    void everyAdminRoleCanReadItsOwnIdentity(RoleName role) throws Exception {
        mockMvc.perform(request(HttpMethod.GET, "/admin/me")
                        .header("Authorization", "Bearer " + tokenByRole.get(role)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.roles").isArray())
                .andExpect(jsonPath("$.roles[0]").value(role.name()));
    }

    @org.junit.jupiter.api.Test
    @DisplayName("An ordinary golfer asking who they are is refused, not told they hold no roles")
    void golferCannotReadAnAdminIdentity() throws Exception {
        mockMvc.perform(request(HttpMethod.GET, "/admin/me")
                        .header("Authorization", "Bearer " + golferToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("VSP-ERR-AUTH-005"));
    }

    @org.junit.jupiter.api.Test
    @DisplayName("No token, no identity")
    void anonymousCannotReadAnAdminIdentity() throws Exception {
        mockMvc.perform(request(HttpMethod.GET, "/admin/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("VSP-ERR-AUTH-001"));
    }

    /**
     * A route to exercise, the single role that route names, and the body to
     * send it.
     * <p>
     * The body is not decoration. Spring MVC binds and validates a
     * {@code @Valid @RequestBody} before it invokes the handler, and
     * {@code @PreAuthorize} is an advice around that invocation — so a request
     * with an empty body is answered 400 for the malformed body and never
     * reaches the authorization decision. That is not a hole (the handler still
     * does not run), but a row sending {@code {}} would prove nothing about
     * who is allowed in. Rows whose handler validates its body carry one that
     * passes validation, so the 403 below is the authorization saying no.
     */
    record Endpoint(String controller, HttpMethod method, String path, RoleName role, String body) {

        Endpoint(String controller, HttpMethod method, String path, RoleName role) {
            this(controller, method, path, role, "{}");
        }

        MockHttpServletRequestBuilder build(String token) {
            MockHttpServletRequestBuilder builder = request(method, path);
            if (token != null) {
                builder.header("Authorization", "Bearer " + token);
            }
            // PUT and PATCH bind a body exactly as POST does. Sending it only
            // for POST meant a PUT row was answered 400 for the missing body
            // and never reached the authorization decision it was written to
            // check — the row passed the anonymous case and quietly proved
            // nothing about the other two.
            if (method == HttpMethod.POST || method == HttpMethod.PUT || method == HttpMethod.PATCH) {
                builder.contentType(MediaType.APPLICATION_JSON).content(body);
            }
            return builder;
        }

        @Override
        public String toString() {
            return controller + " " + method + " " + path + " (" + role + ")";
        }
    }

    /**
     * No {@code @PreAuthorize} may go back to passing the authentication as an
     * argument.
     * <p>
     * {@code hasRole(#authentication, 'X')} is what 49 expressions used to say.
     * Spring's {@code hasRole} takes one argument, so every one of them threw at
     * evaluation time and answered 500 — but the shape is worse than the arity.
     * {@code #authentication} is a SpEL <em>variable</em>, resolved from the
     * method's parameter names: on a handler that has no parameter spelled
     * exactly {@code authentication} it is simply null, and a check written
     * against a null authentication is a check that quietly decides nothing.
     * The authentication is already in scope as {@code authentication}, without
     * the {@code #}.
     */
    @org.junit.jupiter.api.Test
    @DisplayName("No @PreAuthorize passes the authentication as an argument")
    void noExpressionTakesAuthenticationAsAnArgument(
            @Autowired org.springframework.context.ApplicationContext context) {

        List<String> offenders = context.getBeansWithAnnotation(
                        org.springframework.web.bind.annotation.RestController.class)
                .values().stream()
                .map(org.springframework.aop.support.AopUtils::getTargetClass)
                .flatMap(type -> Stream.concat(
                        Stream.of((java.lang.reflect.AnnotatedElement) type),
                        Stream.of(type.getDeclaredMethods()))
                        .map(element -> {
                            var annotation = org.springframework.core.annotation.AnnotatedElementUtils
                                    .findMergedAnnotation(element,
                                            org.springframework.security.access.prepost.PreAuthorize.class);
                            return annotation == null ? null : type.getSimpleName() + ": " + annotation.value();
                        })
                        .filter(java.util.Objects::nonNull))
                .filter(entry -> entry.contains("#authentication"))
                .sorted()
                .toList();

        org.junit.jupiter.api.Assertions.assertTrue(offenders.isEmpty(),
                "These expressions pass the authentication as an argument and cannot evaluate: " + offenders);
    }

    /**
     * Guards the row list against a controller class being added without one.
     * <p>
     * Two ways in. A controller mapped under {@code /admin/**} — and, since
     * TournamentController and LoyaltyController were neither admin-mapped nor
     * annotated, any controller that names a role anywhere. A class that has
     * decided it needs roles has to prove here that the decision survives the
     * whole stack.
     */
    @org.junit.jupiter.api.Test
    @DisplayName("Every controller that is admin-mapped or role-gated appears in the table above")
    void everyRoleGatedControllerIsCovered(@Autowired org.springframework.context.ApplicationContext context) {
        List<String> mapped = context.getBeansWithAnnotation(org.springframework.web.bind.annotation.RestController.class)
                .values().stream()
                .map(bean -> org.springframework.aop.support.AopUtils.getTargetClass(bean))
                .filter(type -> isAdminMapped(type) || namesARole(type))
                .map(Class::getSimpleName)
                .sorted()
                .toList();

        List<String> covered = endpoints().map(Endpoint::controller).distinct().toList();
        List<String> missing = mapped.stream().filter(name -> !covered.contains(name)).toList();

        org.junit.jupiter.api.Assertions.assertTrue(missing.isEmpty(),
                "These controllers are admin-mapped or role-gated but no row above proves a golfer is denied them: "
                        + missing);
    }

    private static boolean isAdminMapped(Class<?> type) {
        var mapping = org.springframework.core.annotation.AnnotatedElementUtils
                .findMergedAnnotation(type, org.springframework.web.bind.annotation.RequestMapping.class);
        if (mapping != null && Stream.of(mapping.value()).anyMatch(v -> v.startsWith("/admin"))) {
            return true;
        }
        return Stream.of(type.getDeclaredMethods()).anyMatch(method -> {
            var methodMapping = org.springframework.core.annotation.AnnotatedElementUtils
                    .findMergedAnnotation(method, org.springframework.web.bind.annotation.RequestMapping.class);
            return methodMapping != null
                    && Stream.of(methodMapping.value()).anyMatch(v -> v.startsWith("/admin"));
        });
    }

    private static boolean namesARole(Class<?> type) {
        return Stream.concat(Stream.of((java.lang.reflect.AnnotatedElement) type),
                        Stream.of(type.getDeclaredMethods()))
                .anyMatch(element -> org.springframework.core.annotation.AnnotatedElementUtils
                        .findMergedAnnotation(element,
                                org.springframework.security.access.prepost.PreAuthorize.class) != null);
    }

    /**
     * No handler asks for a principal this application never creates.
     * <p>
     * {@code JwtAuthenticationFilter} builds every authentication with a
     * {@link Long} account id as the principal, so
     * {@code @AuthenticationPrincipal UserDetails} resolves to null on every
     * request — with no error, no log line and no failing test. Two controllers
     * asked for exactly that and quietly attributed their writes to a
     * placeholder: course imports were filed under {@code "system"} and payments
     * under {@code "ANONYMOUS"}, whoever had actually run them. The mistake is
     * invisible at the call site, which is why it is asserted here rather than
     * left to review.
     */
    @org.junit.jupiter.api.Test
    @DisplayName("No handler injects @AuthenticationPrincipal as anything but the account id")
    void noHandlerInjectsAPrincipalThisApplicationNeverCreates(
            @Autowired org.springframework.context.ApplicationContext context) {

        List<String> offenders = context.getBeansWithAnnotation(
                        org.springframework.web.bind.annotation.RestController.class)
                .values().stream()
                .map(org.springframework.aop.support.AopUtils::getTargetClass)
                .flatMap(type -> Stream.of(type.getDeclaredMethods())
                        .flatMap(method -> Stream.of(method.getParameters())
                                .filter(parameter -> parameter.isAnnotationPresent(
                                        org.springframework.security.core.annotation.AuthenticationPrincipal.class))
                                .filter(parameter -> parameter.getType() != Long.class)
                                .map(parameter -> type.getSimpleName() + "." + method.getName()
                                        + "(" + parameter.getType().getSimpleName() + ")")))
                .sorted()
                .toList();

        org.junit.jupiter.api.Assertions.assertTrue(offenders.isEmpty(),
                "These parameters are injected null on every request — the principal is a Long: " + offenders);
    }

    // ─── Every state-changing endpoint has made a decision ───────────────────

    /**
     * Handlers that change state and are deliberately reachable by any caller
     * the filter chain lets through: the caller acting on their own data, or,
     * for {@code /auth/**}, an anonymous caller signing in or registering.
     * <p>
     * This is the list a reviewer reads. Adding a line to it is a claim that the
     * endpoint is safe for every signed-in golfer, and it is meant to be harder
     * to write than an annotation is.
     */
    private static final List<String> OPEN_BY_DESIGN = List.of(
            // The public authentication surface, plus session revocation and
            // the two social sign-ins, all of which authenticate the caller
            // rather than trust one.
            "AuthController.registerWithPhone",
            "AuthController.registerWithEmail",
            "AuthController.sendOtp",
            "AuthController.verifyOtp",
            "AuthController.initiatePasswordRecovery",
            "AuthController.resetPassword",
            "AuthController.login",
            "AuthController.refreshToken",
            "AuthController.revokeSession",
            "AuthController.authenticateWithGoogle",
            "AuthController.authenticateWithApple",

            // A golfer's own bag, clubs, rounds, scores, shots and profile.
            "BagController.createBag",
            "BagController.updateBag",
            "BagController.deleteBag",
            "BagController.activateBag",
            "BagController.createClub",
            "BagController.updateClub",
            "BagController.deleteClub",
            "RoundController.createRound",
            "RoundController.completeRound",
            "RoundController.abandonRound",
            "RoundController.correctScores",
            "ScoreController.syncScores",
            "ScoreController.submitCorrections",
            "ShotController.createShot",
            "ShotController.updateShot",
            "ShotController.deleteShot",
            "ShotController.mergeShots",
            "ShotController.recordDetection",
            "ProfileController.updateMyProfile",
            "UserCourseController.addFavorite",
            "UserCourseController.removeFavorite",
            "UserCourseController.recordRecentView",

            // A golfer's own bookings, consents, privacy requests and points.
            "BookingController.createBooking",
            "BookingController.updateBookingStatus",
            "BookingController.cancelBooking",
            "BookingController.recordConsent",
            "SponsorshipController.recordConsent",
            "PrivacyController.createRequest",
            "LoyaltyController.redeemPoints",

            // A golfer reporting that a course feature is drawn wrongly. It
            // enters a queue an admin approves, which is where the privilege is.
            "GeometryCorrectionController.submitGeometryCorrection",

            // A golfer typing in the club's printed scorecard. Same queue,
            // same admin decision — nothing is published by submitting it.
            "ScorecardController.submit",

            // Reads the TOURNAMENT_DIRECTOR role in the method body rather than
            // in an annotation, and grants different abilities depending on the
            // answer — see TournamentPolicyController.
            "TournamentPolicyController.createPolicy",
            "TournamentPolicyController.updatePolicy",
            "TournamentPolicyController.lockPolicy"
    );

    /**
     * State-changing handlers that any signed-in golfer can reach and that look
     * like they should not be. Recorded rather than fixed: naming the right role
     * for a payment refund or a course package build is a decision for whoever
     * owns those modules, and inventing one here would be a guess wearing the
     * clothes of a control.
     * <p>
     * The list exists so they are visible and counted, and so the guard below
     * still fails for anything <em>new</em>. Shrinking it is the work; growing
     * it should take an argument.
     */
    private static final List<String> UNGATED_AND_SUSPECT = List.of(
            // "POST /payments/reconciliation — Trigger reconciliation (admin
            // only)", says its own javadoc. There is no check of any kind.
            "PaymentController.runReconciliation",
            // Refunds and the payment-intent lifecycle. The service records an
            // actor, but nothing establishes that the caller may act on this
            // payment.
            "PaymentController.createPaymentIntent",
            "PaymentController.confirmPayment",
            "PaymentController.refundPayment"
            // PackageBuildController.triggerBuild used to be here. It is now
            // annotated: a freshly registered golfer could trigger a build and
            // got a job id back, and a build republishes the course package,
            // which tells every device holding that course to download it again.
    );

    /**
     * The guard the two named controllers needed and did not have.
     * <p>
     * TournamentController and LoyaltyController were invisible: no annotation,
     * no {@code /admin/**} prefix, nothing to notice. A reader would have had to
     * already know the class existed to observe that it had no check. So every
     * handler that changes state now has to say something — it names a role, or
     * its name appears in one of the two lists above and somebody has written
     * down why. A controller added tomorrow with neither fails this test, with
     * its own method names in the message.
     * <p>
     * Reads are not covered. They are the platform's norm — course search, a
     * leaderboard, one's own profile — and a list of every one of them would be
     * noise a reviewer skims rather than a decision a reviewer makes. Reads that
     * do need a role are caught by the coverage test above instead.
     */
    @org.junit.jupiter.api.Test
    @DisplayName("Every state-changing endpoint names a role or is listed as deliberately open")
    void everyStateChangingEndpointHasMadeADecision(
            @Autowired org.springframework.context.ApplicationContext context) {

        List<String> undecided = stateChangingHandlers(context)
                .filter(handler -> !handler.isRoleGated())
                .map(Handler::id)
                .filter(id -> !OPEN_BY_DESIGN.contains(id) && !UNGATED_AND_SUSPECT.contains(id))
                .sorted()
                .toList();

        org.junit.jupiter.api.Assertions.assertTrue(undecided.isEmpty(),
                "These endpoints change state and any signed-in golfer can reach them. Give them a @PreAuthorize, "
                        + "or add them to OPEN_BY_DESIGN with a reason: " + undecided);
    }

    /**
     * Keeps the two lists from outliving what they describe: an entry that has
     * since been annotated, renamed or deleted has to go, so the lists stay a
     * true statement about today's code rather than a record of what was once
     * true.
     */
    @org.junit.jupiter.api.Test
    @DisplayName("No entry in either list is stale")
    void neitherListHasStaleEntries(
            @Autowired org.springframework.context.ApplicationContext context) {

        List<String> ungated = stateChangingHandlers(context)
                .filter(handler -> !handler.isRoleGated())
                .map(Handler::id)
                .toList();

        List<String> stale = Stream.concat(OPEN_BY_DESIGN.stream(), UNGATED_AND_SUSPECT.stream())
                .filter(id -> !ungated.contains(id))
                .sorted()
                .toList();

        org.junit.jupiter.api.Assertions.assertTrue(stale.isEmpty(),
                "These are listed as ungated but are now annotated, renamed or gone — remove them: " + stale);
    }

    /** A handler that changes state, and whether anything requires a role of its caller. */
    private record Handler(String id, boolean isRoleGated) {}

    private static Stream<Handler> stateChangingHandlers(
            org.springframework.context.ApplicationContext context) {

        java.util.Set<org.springframework.web.bind.annotation.RequestMethod> writes = java.util.EnumSet.of(
                org.springframework.web.bind.annotation.RequestMethod.POST,
                org.springframework.web.bind.annotation.RequestMethod.PUT,
                org.springframework.web.bind.annotation.RequestMethod.PATCH,
                org.springframework.web.bind.annotation.RequestMethod.DELETE);

        return context.getBeansWithAnnotation(
                        org.springframework.web.bind.annotation.RestController.class)
                .values().stream()
                .map(org.springframework.aop.support.AopUtils::getTargetClass)
                .flatMap(type -> {
                    boolean classIsGated = org.springframework.core.annotation.AnnotatedElementUtils
                            .findMergedAnnotation(type,
                                    org.springframework.security.access.prepost.PreAuthorize.class) != null;
                    return Stream.of(type.getDeclaredMethods())
                            .filter(method -> {
                                var mapping = org.springframework.core.annotation.AnnotatedElementUtils
                                        .findMergedAnnotation(method,
                                                org.springframework.web.bind.annotation.RequestMapping.class);
                                return mapping != null
                                        && Stream.of(mapping.method()).anyMatch(writes::contains);
                            })
                            .map(method -> new Handler(
                                    type.getSimpleName() + "." + method.getName(),
                                    classIsGated
                                            || org.springframework.core.annotation.AnnotatedElementUtils
                                                    .findMergedAnnotation(method,
                                                            org.springframework.security.access.prepost
                                                                    .PreAuthorize.class) != null));
                });
    }
}
