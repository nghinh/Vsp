package vnpt.vsp.module.payment.presentation.dtos;

import vnpt.vsp.module.payment.domain.models.PaymentFailureReason;

/**
 * Request DTO for payment confirmation.
 */
public class ConfirmPaymentRequest {

    private String providerReference;
    private boolean success;
    private PaymentFailureReason failureReason;
    private String failureMessage;

    // Getters
    public String getProviderReference() { return providerReference; }
    public boolean isSuccess() { return success; }
    public PaymentFailureReason getFailureReason() { return failureReason; }
    public String getFailureMessage() { return failureMessage; }
}
