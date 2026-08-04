package vnpt.vsp.module.payment.presentation.controllers;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.payment.domain.models.*;
import vnpt.vsp.module.payment.domain.services.PaymentAuditService;
import vnpt.vsp.module.payment.domain.services.PaymentService;
import vnpt.vsp.module.payment.domain.services.ReconciliationService;
import vnpt.vsp.module.payment.presentation.dtos.ConfirmPaymentRequest;
import vnpt.vsp.module.payment.presentation.dtos.CreatePaymentIntentRequest;
import vnpt.vsp.module.payment.presentation.dtos.RefundPaymentRequest;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * REST controller for payment endpoints.
 *
 * Per Story 12.3: Payment and Transaction Services.
 * All write endpoints require Idempotency-Key header.
 */
@RestController
@RequestMapping("/payments")
@Validated
public class PaymentController {

    private final PaymentService paymentService;
    private final PaymentAuditService auditService;
    private final ReconciliationService reconciliationService;

    public PaymentController(PaymentService paymentService,
                              PaymentAuditService auditService,
                              ReconciliationService reconciliationService) {
        this.paymentService = paymentService;
        this.auditService = auditService;
        this.reconciliationService = reconciliationService;
    }

    /**
     * POST /payments/intent — Create a payment intent.
     * Requires Idempotency-Key header.
     */
    @PostMapping("/intent")
    public ResponseEntity<Map<String, Object>> createPaymentIntent(
            @Valid @RequestBody CreatePaymentIntentRequest request,
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @AuthenticationPrincipal UserDetails user) {

        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            return badRequest("Idempotency-Key header is required");
        }

        String actor = user != null ? user.getUsername() : "ANONYMOUS";

        var result = paymentService.createPaymentIntent(
                request.getAmount(),
                request.getCurrency(),
                idempotencyKey,
                request.getMetadata(),
                request.getReturnUrl(),
                actor
        );

        Map<String, Object> body = new HashMap<>();
        body.put("transactionId", result.transactionId());
        body.put("providerReference", result.providerReference());
        body.put("state", result.state().name().toLowerCase());
        body.put("amount", result.amount());
        body.put("currency", result.currency());
        body.put("clientSecret", result.clientSecret());
        body.put("returnUrl", result.returnUrl());
        body.put("createdAt", result.createdAt());

        return ResponseEntity.status(HttpStatus.CREATED).body(body);
    }

    /**
     * GET /payments/{paymentId} — Get payment status.
     */
    @GetMapping("/{paymentId}")
    public ResponseEntity<Map<String, Object>> getPayment(@PathVariable UUID paymentId) {
        var tx = paymentService.getPayment(paymentId)
                .orElse(null);

        if (tx == null) {
            return notFound();
        }

        return ResponseEntity.ok(toStatusResponse(tx));
    }

    /**
     * POST /payments/{paymentId}/confirm — Confirm payment (webhook/callback).
     * Requires Idempotency-Key header.
     */
    @PostMapping("/{paymentId}/confirm")
    public ResponseEntity<Map<String, Object>> confirmPayment(
            @PathVariable UUID paymentId,
            @Valid @RequestBody ConfirmPaymentRequest request,
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey) {

        String actor = request.getProviderReference() != null
                ? "PROVIDER_WEBHOOK"
                : "SYSTEM";

        var tx = paymentService.confirmPayment(
                paymentId,
                request.getProviderReference(),
                request.isSuccess(),
                request.getFailureReason(),
                request.getFailureMessage(),
                actor
        );

        return ResponseEntity.ok(toStatusResponse(tx));
    }

    /**
     * POST /payments/{paymentId}/refund — Refund a payment.
     * Requires Idempotency-Key header.
     */
    @PostMapping("/{paymentId}/refund")
    public ResponseEntity<Map<String, Object>> refundPayment(
            @PathVariable UUID paymentId,
            @Valid @RequestBody RefundPaymentRequest request,
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @AuthenticationPrincipal UserDetails user) {

        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            return badRequest("Idempotency-Key header is required");
        }

        String actor = user != null ? user.getUsername() : "ANONYMOUS";

        var result = paymentService.refundPayment(
                paymentId,
                request.getAmount(),
                request.getReason(),
                request.getReasonDetail(),
                idempotencyKey,
                actor
        );

        Map<String, Object> body = new HashMap<>();
        body.put("refundRequestId", result.refundRequestId());
        body.put("transactionId", result.transactionId());
        body.put("status", result.status().name().toLowerCase());
        body.put("amount", result.amount());
        body.put("reason", result.reason().name().toLowerCase());
        body.put("providerRefundRef", result.providerRefundRef());
        body.put("requestedAt", result.requestedAt());
        body.put("processedAt", result.processedAt());

        return ResponseEntity.ok(body);
    }

    /**
     * GET /payments/{paymentId}/audit — Get payment audit log.
     */
    @GetMapping("/{paymentId}/audit")
    public ResponseEntity<Map<String, Object>> getPaymentAuditLog(@PathVariable UUID paymentId) {
        var tx = paymentService.getPayment(paymentId).orElse(null);
        if (tx == null) {
            return notFound();
        }

        var entries = auditService.getAuditTrail(paymentId);

        List<Map<String, Object>> entryDtos = entries.stream()
                .map(e -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", e.getId().toString());
                    m.put("transactionId", e.getTransaction().getId().toString());
                    m.put("action", e.getAction().name());
                    m.put("actor", e.getActor());
                    m.put("previousState", e.getPreviousState() != null ? e.getPreviousState().name().toLowerCase() : null);
                    m.put("newState", e.getNewState() != null ? e.getNewState().name().toLowerCase() : null);
                    m.put("metadataJson", e.getMetadataJson());
                    m.put("timestamp", e.getTimestamp().toString());
                    return m;
                })
                .collect(Collectors.toList());

        Map<String, Object> body = new HashMap<>();
        body.put("transactionId", paymentId.toString());
        body.put("entries", entryDtos);

        return ResponseEntity.ok(body);
    }

    /**
     * POST /payments/reconciliation — Trigger reconciliation (admin only).
     */
    @PostMapping("/reconciliation")
    public ResponseEntity<Map<String, Object>> runReconciliation() {
        var report = reconciliationService.runReconciliation();

        List<Map<String, Object>> discrepancyDtos = report.discrepancies().stream()
                .map(d -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("transactionId", d.transactionId());
                    m.put("platformState", d.platformState());
                    m.put("providerState", d.providerState());
                    m.put("amount", d.amount());
                    m.put("currency", d.currency());
                    m.put("resolution", d.resolution());
                    m.put("notes", d.notes());
                    m.put("detectedAt", report.runAt());
                    return m;
                })
                .collect(Collectors.toList());

        Map<String, Object> body = new HashMap<>();
        body.put("runAt", report.runAt());
        body.put("checkedTransactions", report.checkedTransactions());
        body.put("discrepancies", discrepancyDtos);
        body.put("status", report.status());

        return ResponseEntity.status(HttpStatus.ACCEPTED).body(body);
    }

    private Map<String, Object> toStatusResponse(PaymentTransactionEntity tx) {
        Map<String, Object> body = new HashMap<>();
        body.put("id", tx.getId().toString());
        body.put("providerReference", tx.getProviderReference());
        body.put("paymentMethodRef", tx.getPaymentMethodRef());
        body.put("state", tx.getState().name().toLowerCase());
        body.put("failureReason", tx.getFailureReason() != null ? tx.getFailureReason().name().toLowerCase() : null);
        body.put("failureMessage", tx.getFailureMessage());
        body.put("amount", tx.getAmount());
        body.put("currency", tx.getCurrency());
        body.put("refundedAmount", tx.getRefundedAmount());
        body.put("createdAt", tx.getCreatedAt().toString());
        body.put("updatedAt", tx.getUpdatedAt().toString());
        return body;
    }

    private ResponseEntity<Map<String, Object>> badRequest(String message) {
        Map<String, Object> body = new HashMap<>();
        body.put("code", "VSP-ERR-VALIDATION-006");
        body.put("message", message);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    private ResponseEntity<Map<String, Object>> notFound() {
        Map<String, Object> body = new HashMap<>();
        body.put("code", "VSP-ERR-PAYMENT-001");
        body.put("message", "Payment not found");
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(body);
    }
}
