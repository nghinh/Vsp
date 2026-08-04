package vnpt.vsp.module.payment.presentation.dtos;

import jakarta.validation.constraints.Min;
import vnpt.vsp.module.payment.domain.models.RefundReason;

import java.util.Map;

/**
 * Request DTO for refund payment.
 */
public class RefundPaymentRequest {

    @Min(value = 1, message = "amount must be positive if provided")
    private Long amount;

    private RefundReason reason;

    private String reasonDetail;

    private Map<String, String> metadata;

    // Getters
    public Long getAmount() { return amount; }
    public RefundReason getReason() { return reason; }
    public String getReasonDetail() { return reasonDetail; }
}
