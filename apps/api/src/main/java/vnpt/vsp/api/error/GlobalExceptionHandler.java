package vnpt.vsp.api.error;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.NoHandlerFoundException;

/**
 * Central {@link RestControllerAdvice} that converts all API exceptions into
 * structured {@link ErrorResponse} objects with a stable error code and a
 * correlation ID for log correlation.
 * <p>
 * Handles:
 * <ul>
 *   <li>{@link VspApiException} — domain-stable errors with optional field context</li>
 *   <li>{@link MethodArgumentNotValidException} — bean-validation failures</li>
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

    private static final String CORRELATION_ID_KEY = "correlationId";

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

    // ─── Malformed JSON body ─────────────────────────────────────────────────

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleMessageNotReadable(
            HttpMessageNotReadableException ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.VALIDATION_004.getCode())
                .message("Malformed JSON in request body")
                .correlationId(correlationId())
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
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

    // ─── Catch-all — never expose raw message to clients ────────────────────

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(
            Exception ex,
            HttpServletRequest request) {

        ErrorResponse body = ErrorResponse.builder()
                .code(VspErrorCode.INTERNAL_001.getCode())
                .message("An unexpected error occurred. Please contact support with the correlation ID.")
                .correlationId(correlationId())
                .build();

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
}
