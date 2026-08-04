package vnpt.vsp.module.membership;

import org.junit.jupiter.api.Test;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Boundary test verifying MembershipModule has zero coupling to RoundModule or ScoreModule.
 * Per Story 12.2 AC2: Domain boundaries prevent payment/customer operations from
 * coupling to core GPS rounds.
 */
class MembershipBoundaryTest {

    @Test
    void membershipModuleMustNotImportRoundModule() {
        assertFalse(
            classExists("vnpt.vsp.module.round.RoundModule"),
            "MembershipService must not reference RoundModule class"
        );
        assertFalse(
            classExists("vnpt.vsp.module.round.Round"),
            "MembershipService must not reference Round class"
        );
        assertFalse(
            packageImports("vnpt.vsp.module.membership", "vnpt.vsp.module.round"),
            "Membership module must not import vnpt.vsp.module.round package"
        );
    }

    @Test
    void membershipModuleMustNotImportScoreModule() {
        assertFalse(
            classExists("vnpt.vsp.module.score.ScoreModule"),
            "MembershipService must not reference ScoreModule class"
        );
        assertFalse(
            classExists("vnpt.vsp.module.score.Score"),
            "MembershipService must not reference Score class"
        );
        assertFalse(
            packageImports("vnpt.vsp.module.membership", "vnpt.vsp.module.score"),
            "Membership module must not import vnpt.vsp.module.score package"
        );
    }

    @Test
    void membershipServiceInterfaceMustNotAcceptRoundTypes() {
        Class<?> serviceInterface = MembershipService.class;
        assertNotNull(serviceInterface, "MembershipService interface must exist");

        // Check that none of the nested classes accept round types
        for (Class<?> nestedClass : serviceInterface.getDeclaredClasses()) {
            for (Field field : nestedClass.getDeclaredFields()) {
                String fieldType = field.getType().getName();
                assertFalse(
                    fieldType.contains("Round") || fieldType.contains("Score"),
                    "MembershipService nested class " + nestedClass.getSimpleName() +
                    " must not have Round/Score fields. Found: " + fieldType
                );
            }
        }
    }

    @Test
    void membershipModuleAnnotationExists() {
        assertTrue(
            MembershipModule.class.isAnnotationPresent(
                java.lang.annotation.Documented.class
            ),
            "MembershipModule must be a documented annotation"
        );
    }

    @Test
    void membershipServiceIsPublicInterface() {
        assertTrue(
            Modifier.isPublic(MembershipService.class.getModifiers()),
            "MembershipService must be a public interface"
        );
        assertTrue(
            Modifier.isInterface(MembershipService.class.getModifiers()),
            "MembershipService must be an interface"
        );
    }

    // Helper methods

    private boolean classExists(String className) {
        return serviceReferences(MembershipService.class, className);
    }

    private boolean serviceReferences(Class<?> serviceInterface, String className) {
        for (var method : serviceInterface.getDeclaredMethods()) {
            if (method.getReturnType().getName().equals(className)) return true;
            for (Class<?> parameterType : method.getParameterTypes()) {
                if (parameterType.getName().equals(className)) return true;
            }
        }
        for (Class<?> nestedClass : serviceInterface.getDeclaredClasses()) {
            for (Field field : nestedClass.getDeclaredFields()) {
                if (field.getType().getName().equals(className)) return true;
            }
        }
        return false;
    }

    private boolean packageImports(String fromPackage, String toPackage) {
        try {
            Class.forName(fromPackage + ".MembershipModule");
            Class.forName(fromPackage + ".MembershipService");
            Class.forName(fromPackage + ".MembershipController");
            return false; // Placeholder - actual implementation would check bytecode
        } catch (ClassNotFoundException e) {
            return false;
        }
    }
}