package vnpt.vsp.api.error;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.exc.InvalidFormatException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.mock.http.MockHttpInputMessage;
import vnpt.vsp.module.correction.entity.GeometryLayer;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Unit tests for the parts of {@link GlobalExceptionHandler} that tell a client
 * developer what to change.
 *
 * @see RequestErrorContractTest for the same behaviour through the filter chain
 */
class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler(new ObjectMapper());

    private static HttpMessageNotReadableException wrap(Throwable cause) {
        return new HttpMessageNotReadableException(
                "JSON parse error", cause,
                new MockHttpInputMessage("{}".getBytes(StandardCharsets.UTF_8)));
    }

    @Test
    @DisplayName("a photograph over the cap says so, instead of reading as the app being broken")
    void oversizedUploadIsAnsweredWithWhatToDoAboutIt() {
        // Tomcat rejects the part while parsing, so the controller that would
        // have said "the photograph is larger than 8 MB" never runs. Unhandled,
        // this reached the catch-all and the golfer who photographed the club's
        // card was told to contact support with a correlation ID.
        var request = new org.springframework.mock.web.MockHttpServletRequest(
                "POST", "/courses/1/scorecard-corrections/extract");

        ResponseEntity<ErrorResponse> response = handler.handleUploadTooLarge(
                new org.springframework.web.multipart.MaxUploadSizeExceededException(8L * 1024 * 1024),
                request);

        assertEquals(HttpStatus.PAYLOAD_TOO_LARGE, response.getStatusCode());
        ErrorResponse body = response.getBody();
        assertNotNull(body);
        // Named so a client can attach it to the field the golfer touched.
        assertEquals("image", body.getField());
        assertTrue(body.getMessage().contains("8 MB"),
                "the golfer needs the number to act on, not just that it was too big");
    }

    @Test
    @DisplayName("Jackson's own enum coercion failure echoes the value, names the field and lists the wire forms")
    void invalidFormatOnEnumIsReportedInFull() throws Exception {
        JsonParser parser = new ObjectMapper().createParser("{}");
        InvalidFormatException cause = InvalidFormatException.from(
                parser, "not one of the values", "tee", GeometryLayer.class);
        cause.prependPath(new Object(), "layer");

        ResponseEntity<ErrorResponse> response = handler.handleMessageNotReadable(wrap(cause), null);
        ErrorResponse body = response.getBody();

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertNotNull(body);
        assertEquals(VspErrorCode.VALIDATION_003.getCode(), body.getCode());
        assertEquals("layer", body.getField());
        assertEquals("Invalid value 'tee' for 'layer'. Accepted values: green, fairway, bunker, water, ob",
                body.getMessage());
    }

    @Test
    @DisplayName("A nested field reports its full JSON path")
    void nestedPathIsReported() throws Exception {
        JsonParser parser = new ObjectMapper().createParser("{}");
        InvalidFormatException cause = InvalidFormatException.from(
                parser, "not one of the values", "tee", GeometryLayer.class);
        cause.prependPath(new Object(), "layer");
        cause.prependPath(new Object(), 2);
        cause.prependPath(new Object(), "corrections");

        ErrorResponse body = handler.handleMessageNotReadable(wrap(cause), null).getBody();

        assertNotNull(body);
        assertEquals("corrections[2].layer", body.getField());
    }

    @Test
    @DisplayName("A body that really is malformed is still reported as malformed JSON")
    void malformedJsonKeepsItsCode() {
        ResponseEntity<ErrorResponse> response =
                handler.handleMessageNotReadable(wrap(new RuntimeException("Unexpected end-of-input")), null);
        ErrorResponse body = response.getBody();

        assertNotNull(body);
        assertEquals(VspErrorCode.VALIDATION_004.getCode(), body.getCode());
        assertEquals("Malformed JSON in request body", body.getMessage());
    }

    @Test
    @DisplayName("A rejected non-enum value is not dressed up as an enum problem")
    void nonEnumMismatchKeepsMalformedJsonCode() throws Exception {
        JsonParser parser = new ObjectMapper().createParser("{}");
        InvalidFormatException cause = InvalidFormatException.from(
                parser, "not a number", "abc", Integer.class);
        cause.prependPath(new Object(), "holeId");

        ErrorResponse body = handler.handleMessageNotReadable(wrap(cause), null).getBody();

        assertNotNull(body);
        assertEquals(VspErrorCode.VALIDATION_004.getCode(), body.getCode());
    }

    @Test
    @DisplayName("A VspApiException keeps its code, status and field")
    void vspApiExceptionIsRenderedFromItsCode() {
        VspApiException ex = new VspApiException(VspErrorCode.VALIDATION_006, "Idempotency-Key");

        ResponseEntity<ErrorResponse> response = handler.handleVspApiException(ex, null);
        ErrorResponse body = response.getBody();

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertNotNull(body);
        assertEquals("VSP-ERR-VALIDATION-006", body.getCode());
        assertEquals("Idempotency-Key", body.getField());
        assertTrue(body.getMessage() != null && !body.getMessage().isBlank());
    }
}
