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
                new Endpoint("CourseVersionController", HttpMethod.GET, "/courses/1/versions", RoleName.COURSE_ADMIN)
        );
    }

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

    /** A route to exercise, and the single role that route names. */
    record Endpoint(String controller, HttpMethod method, String path, RoleName role) {

        MockHttpServletRequestBuilder build(String token) {
            MockHttpServletRequestBuilder builder = request(method, path);
            if (token != null) {
                builder.header("Authorization", "Bearer " + token);
            }
            if (method == HttpMethod.POST) {
                builder.contentType(MediaType.APPLICATION_JSON).content("{}");
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

    /** Guards the row list against a controller class being added without one. */
    @org.junit.jupiter.api.Test
    @DisplayName("Every controller mapped under /admin/** appears in the table above")
    void everyAdminControllerIsCovered(@Autowired org.springframework.context.ApplicationContext context) {
        List<String> mapped = context.getBeansWithAnnotation(org.springframework.web.bind.annotation.RestController.class)
                .values().stream()
                .map(bean -> org.springframework.aop.support.AopUtils.getTargetClass(bean))
                .filter(type -> {
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
                })
                .map(Class::getSimpleName)
                .sorted()
                .toList();

        List<String> covered = endpoints().map(Endpoint::controller).distinct().toList();
        List<String> missing = mapped.stream().filter(name -> !covered.contains(name)).toList();

        org.junit.jupiter.api.Assertions.assertTrue(missing.isEmpty(),
                "These controllers serve /admin/** but no row above proves a golfer is denied them: " + missing);
    }
}
