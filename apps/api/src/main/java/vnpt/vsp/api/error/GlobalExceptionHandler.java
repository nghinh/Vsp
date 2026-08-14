package vnpt.vsp.api.error;

import com.fasterxml.jackson.databind.JsonMappingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.exc.InvalidFormatException;
import com.fasterxml.jackson.databind.exc.ValueInstantiationException;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import jakarta.validation.ConstraintViolationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.Arrays;
import java.util.stream.Collectors;

/**
 * Central {@link RestControllerAdvice} that converts all API exceptions into
 * structured {@link ErrorResponse} objects with a stable error code and a
 * correlation ID for log correlation.
 * <p>
 * Handles:
 * <ul>
 *   <li>{@link VspApiException} — domain-stable errors with optional field context</li>
 *   <li>{@link MethodArgumentNotValidException} — bean-validation failures on a body</li>
 *   <li>{@link ConstraintViolationException} — the same on a query parameter
 *       or path variable, which Spring reports as a different type entirely</li>
 *   <li>{@link HttpMessageNotReadableException} — malformed JSON body</li>
 *   <li>{@link MissingServletRequestParameterException} — missing required query/path param</li>
 *   <li>{@link MethodArgumentTypeMismatchException} — wrong type for a request param</li>
 *   <li>{@link HttpRequestMethodNotSupportedException} — wrong HTTP verb</li>
 *   <li>{@link NoHandlerFoundException} — 404 because no route matches</li>
 *   <li>{@link Exception} — unexpected errors, never exposed as a raw message</li>
 * </ul>
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private static final String CORRELATION_ID_KEY = "correlationId";

    /** Used only to render enum constants in the wire form the client must send. */
    private final ObjectMapper objectMapper;

    public GlobalExceptionHandler(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /**
     * Returns the correlation ID from the MDC set by {@link vnpt.vsp.api.error.CorrelationIdFilter},
     * or {@code "unknown"} when no request context is available.
     */
    private String correlationId() {
        return MDC.get(CORRELATION_ID_KEY);
    }

    // ─── VspApiException ─────────────────────────────────────────────────────

    @ExceptionHandler(VspApiException.class)
    public ResponseEntity<ErrorResponse> handleVspApiException(
            VspApiException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.from(ex, correlationId());
        HttpStatus status = ex.getErrorCode().getHttpStatus();
        return ResponseEntity.status(status).body(body);
    }

    // ─── FeatureRestrictedException (per Story 7.4 Slice E) ─────────────────

    @ExceptionHandler(FeatureRestrictedException.class)
    public ResponseEntity<ErrorResponse> handleFeatureRestrictedException(
            FeatureRestrictedException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(ex.getErrorCode().getCode())
                .message(ex.getMessage())
                .correlationId(correlationId())
                .details(ex.getDetails())
                .build();

        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(body);
    }

    // ─── Bean Validation ─────────────────────────────────────────────────────

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(
            MethodArgumentNotValidException ex,
            HttpServletRequest request) {

        var fieldError = ex.getBindingResult().getFieldError();
        String field = fieldError != null ? fieldError.getField() : null;
        String message = fieldError != null
                ? fieldError.getDefaultMessage()
                : VspErrorCode.VALIDATION_001.getDefaultMessage();

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.VALIDATION_001.getCode())
                .message(message)
                .correlationId(correlationId())
                .field(field)
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    /**
     * A query parameter or path variable that failed its own constraint.
     *
     * <p>Spring reports these as {@link ConstraintViolationException} rather
     * than as {@link MethodArgumentNotValidException}, which only covers an
     * annotated request <em>body</em>. Nothing handled it, so every controller
     * annotated {@code @Validated} answered a caller's out-of-range parameter
     * with 500 and a correlation id — telling them to contact support about
     * their own typo, and putting a stack trace in the log for it.
     *
     * <p>Live before this: {@code /courses/search?lat=999} and {@code ?size=9999}
     * were both 500. Those are the endpoints the app calls.
     */
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ErrorResponse> handleConstraintViolation(
            ConstraintViolationException ex,
            HttpServletRequest request) {

        var violation = ex.getConstraintViolations().stream().findFirst().orElse(null);

        // The propertyPath reads "searchCourses.lat"; a caller sent "lat".
        String field = null;
        if (violation != null) {
            String path = violation.getPropertyPath().toString();
            int dot = path.lastIndexOf('.');
            field = dot >= 0 ? path.substring(dot + 1) : path;
        }

        String message = violation != null
                ? (field + " " + violation.getMessage())
                : VspErrorCode.VALIDATION_001.getDefaultMessage();

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.VALIDATION_001.getCode())
                .message(message)
                .correlationId(correlationId())
                .field(field)
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    // ─── Malformed JSON body ─────────────────────────────────────────────────

    /**
     * Jackson reports every body it could not turn into the request object as
     * {@link HttpMessageNotReadableException}, whether the JSON was truly
     * malformed or merely carried a value the target type rejects. Reporting
     * both as "Malformed JSON" sends a client developer hunting for a syntax
     * error in a body whose syntax is perfect — the actual problem, an
     * unaccepted enum value, is the one case where the server knows exactly
     * what the client should have sent, so it says so.
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleMessageNotReadable(
            HttpMessageNotReadableException ex,
            HttpServletRequest request) {

        ErrorResponse body = describeRejectedEnumValue(ex);
        if (body == null) {
            body = ErrorResponse.builder()
                    .code(VspErrorCode.VALIDATION_004.getCode())
                    .message("Malformed JSON in request body")
                    .correlationId(correlationId())
                    .build();
        }

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    /**
     * Builds a field-level error for a JSON value that named no constant of an
     * enum-typed field, or {@code null} when the failure was something else.
     *
     * <p>The response names the field, echoes the value the client sent, and
     * lists the accepted values in their wire form. It never names a Java type
     * or a package.</p>
     */
    private ErrorResponse describeRejectedEnumValue(HttpMessageNotReadableException ex) {
        JsonMappingException mappingException = findCause(ex, JsonMappingException.class);
        if (mappingException == null) {
            return null;
        }

        Class<?> targetType = null;
        Object rejectedValue = null;
        if (mappingException instanceof InvalidFormatException invalidFormat) {
            // Jackson coerced the value itself and found no matching constant.
            targetType = invalidFormat.getTargetType();
            rejectedValue = invalidFormat.getValue();
        } else if (mappingException instanceof ValueInstantiationException valueInstantiation) {
            // An @JsonCreator factory rejected the value by throwing.
            targetType = valueInstantiation.getType() != null
                    ? valueInstantiation.getType().getRawClass() : null;
        }
        if (targetType == null || !targetType.isEnum()) {
            return null;
        }

        String field = pathOf(mappingException);
        String accepted = acceptedValues(targetType);
        String message = rejectedValue != null
                ? "Invalid value '%s' for '%s'. Accepted values: %s".formatted(rejectedValue, field, accepted)
                : "Invalid value for '%s'. Accepted values: %s".formatted(field, accepted);

        return ErrorResponse.builder()
                .code(VspErrorCode.VALIDATION_003.getCode())
                .message(message)
                .correlationId(correlationId())
                .field(field)
                .build();
    }

    /**
     * The accepted values as the client must spell them — serialised through
     * Jackson so a {@code @JsonValue} wire form ({@code "green"}) is listed
     * rather than the constant name ({@code "GREEN"}).
     */
    private String acceptedValues(Class<?> enumType) {
        return Arrays.stream(enumType.getEnumConstants())
                .map(constant -> {
                    try {
                        return objectMapper.convertValue(constant, String.class);
                    } catch (IllegalArgumentException e) {
                        return ((Enum<?>) constant).name();
                    }
                })
                .collect(Collectors.joining(", "));
    }

    /** Dotted JSON path to the offending field, e.g. {@code layer} or {@code holes[2].par}. */
    private String pathOf(JsonMappingException ex) {
        StringBuilder path = new StringBuilder();
        for (JsonMappingException.Reference reference : ex.getPath()) {
            if (reference.getFieldName() != null) {
                if (!path.isEmpty()) {
                    path.append('.');
                }
                path.append(reference.getFieldName());
            } else if (reference.getIndex() >= 0) {
                path.append('[').append(reference.getIndex()).append(']');
            }
        }
        return path.isEmpty() ? "request body" : path.toString();
    }

    @SuppressWarnings("unchecked")
    private <T extends Throwable> T findCause(Throwable ex, Class<T> type) {
        for (Throwable current = ex; current != null; current = current.getCause()) {
            if (type.isInstance(current)) {
                return (T) current;
            }
            if (current.getCause() == current) {
                break;
            }
        }
        return null;
    }

    // ─── Missing required parameter ─────────────────────────────────────────

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ErrorResponse> handleMissingParameter(
            MissingServletRequestParameterException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.VALIDATION_002.getCode())
                .message("Missing required parameter: " + ex.getParameterName())
                .correlationId(correlationId())
                .field(ex.getParameterName())
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    // ─── Upload larger than the cap ─────────────────────────────────────────

    /**
     * Tomcat rejects an oversized part while parsing the request, so this never
     * reaches the controller that would have said something useful about it.
     *
     * <p>Without this the golfer who photographed the club's card got "An
     * unexpected error occurred. Please contact support with the correlation
     * ID" — which tells them nothing they can act on, and reads as the app
     * being broken rather than the photo being big. 413 rather than 400, so a
     * client can tell "this photo is too big" from "this photo is not a
     * photo" and offer to shrink it rather than to retake it.
     */
    @ExceptionHandler(org.springframework.web.multipart.MaxUploadSizeExceededException.class)
    public ResponseEntity<ErrorResponse> handleUploadTooLarge(
            org.springframework.web.multipart.MaxUploadSizeExceededException ex,
            HttpServletRequest request) {

        log.warn("Upload rejected as too large on {} — correlationId={}",
                request.getRequestURI(), correlationId());

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.VALIDATION_001.getCode())
                .message("The photograph is too large — send one under 8 MB")
                .correlationId(correlationId())
                .field("image")
                .build();

        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).body(body);
    }

    // ─── Wrong type for a request parameter ────────────────────────────────

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorResponse> handleTypeMismatch(
            MethodArgumentTypeMismatchException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.VALIDATION_003.getCode())
                .message("Invalid value for parameter '" + ex.getName() + "'")
                .correlationId(correlationId())
                .field(ex.getName())
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    // ─── Unsupported HTTP method ────────────────────────────────────────────

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ErrorResponse> handleMethodNotSupported(
            HttpRequestMethodNotSupportedException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.INTERNAL_001.getCode())
                .message("HTTP method not supported: " + ex.getMethod())
                .correlationId(correlationId())
                .build();

        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).body(body);
    }

    // ─── No handler found (404) ─────────────────────────────────────────────

    @ExceptionHandler(NoHandlerFoundException.class)
    public ResponseEntity<ErrorResponse> handleNoHandlerFound(
            NoHandlerFoundException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.INTERNAL_001.getCode())
                .message("No endpoint found for " + ex.getHttpMethod() + " " + ex.getRequestURL())
                .correlationId(correlationId())
                .build();

        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(body);
    }

    // Spring 6.1+ raises NoResourceFoundException (not NoHandlerFoundException) when a
    // request path matches no controller and falls through to static-resource handling.
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ErrorResponse> handleNoResourceFound(
            NoResourceFoundException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.INTERNAL_001.getCode())
                .message("No endpoint found for " + request.getMethod() + " " + request.getRequestURI())
                .correlationId(correlationId())
                .build();

        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(body);
    }

    // ─── Method security ────────────────────────────────────────────────────

    /**
     * A {@code @PreAuthorize} refusal. Method security throws this from inside
     * the controller invocation, so it reaches this advice rather than Spring
     * Security's {@code ExceptionTranslationFilter} — and the catch-all below
     * would otherwise report an authorization decision as {@code 500 Unexpected
     * server error}, which tells the caller nothing and reads like an outage.
     */
    @ExceptionHandler(org.springframework.security.access.AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(
            org.springframework.security.access.AccessDeniedException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.AUTH_005.getCode())
                .message(VspErrorCode.AUTH_005.getDefaultMessage())
                .correlationId(correlationId())
                .build();

        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(body);
    }

    /**
     * A handler reached with no usable authentication — for instance
     * {@code authentication.principal} evaluated on an anonymous request.
     */
    @ExceptionHandler(org.springframework.security.core.AuthenticationException.class)
    public ResponseEntity<ErrorResponse> handleAuthentication(
            org.springframework.security.core.AuthenticationException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.AUTH_001.getCode())
                .message("Authentication required — send a valid access token as 'Authorization: Bearer <token>'")
                .correlationId(correlationId())
                .build();

        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(body);
    }

    // ─── Catch-all — never expose raw message to clients ────────────────────

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(
            Exception ex,
            HttpServletRequest request) {

        String correlationId = correlationId();

        // The response tells the caller to contact support with this id. That
        // is a promise the server has to keep: without this line the id
        // appears nowhere in the logs, and an unexpected failure leaves
        // nothing behind to look up. The message stays out of the response —
        // it is logged here instead, where support can read it.
        log.error("Unhandled exception on {} {} — correlationId={}",
                request.getMethod(), request.getRequestURI(), correlationId, ex);

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.INTERNAL_001.getCode())
                .message("An unexpected error occurred. Please contact support with the correlation ID.")
                .correlationId(correlationId)
                .build();

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
}
