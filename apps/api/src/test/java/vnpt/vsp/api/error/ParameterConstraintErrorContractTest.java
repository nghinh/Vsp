package vnpt.vsp.api.error;

import jakarta.validation.ConstraintViolationException;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * An out-of-range query parameter is the caller's mistake, not the server's.
 *
 * <p>Spring reports a bad request <em>body</em> as MethodArgumentNotValidException
 * and a bad query parameter or path variable as ConstraintViolationException —
 * two unrelated types. Only the first was handled, so every controller annotated
 * {@code @Validated} answered a caller's typo with 500 and a correlation id,
 * telling them to contact support about their own input.
 *
 * <p>Observed on production before this: {@code /courses/search?lat=999} and
 * {@code ?size=9999} were both 500.
 */
class ParameterConstraintErrorContractTest {

    private final GlobalExceptionHandler handler =
            new GlobalExceptionHandler(new com.fasterxml.jackson.databind.ObjectMapper());

    static class Params {
        @Min(-90) @Max(90) int lat;
    }

    private ConstraintViolationException violationOn(int lat) {
        Validator validator = Validation.buildDefaultValidatorFactory().getValidator();
        Params p = new Params();
        p.lat = lat;
        var violations = validator.validate(p);
        assertThat(violations).isNotEmpty();
        return new ConstraintViolationException(Set.copyOf(violations));
    }

    @Test
    void answersBadRequestRatherThanInternalError() {
        var response = handler.handleConstraintViolation(
                violationOn(999), new MockHttpServletRequest());

        assertThat(response.getStatusCode().value()).isEqualTo(400);
    }

    /// The caller has to be told which parameter, or a 400 is no more useful
    /// than the 500 it replaces.
    @Test
    void namesTheParameterThatWasWrong() {
        var response = handler.handleConstraintViolation(
                violationOn(999), new MockHttpServletRequest());

        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getField()).isEqualTo("lat");
        assertThat(response.getBody().getMessage()).contains("lat");
    }

    @Test
    void carriesTheValidationErrorCode() {
        var response = handler.handleConstraintViolation(
                violationOn(-999), new MockHttpServletRequest());

        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getCode())
                .isEqualTo(VspErrorCode.VALIDATION_001.getCode());
    }
}
