package vnpt.vsp.module.payment.presentation.dtos;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.Map;

/**
 * Request DTOs for payment endpoints.
 */
public class CreatePaymentIntentRequest {

    @NotNull(message = "amount is required")
    @Min(value = 1, message = "amount must be positive")
    private Long amount;

    @NotBlank(message = "currency is required")
    @Size(min = 3, max = 3, message = "currency must be ISO 4217 (3 chars)")
    private String currency;

    private List<String> paymentMethodTypes;

    private Map<String, String> metadata;

    private String returnUrl;

    // Getters
    public Long getAmount() { return amount; }
    public String getCurrency() { return currency; }
    public List<String> getPaymentMethodTypes() { return paymentMethodTypes; }
    public Map<String, String> getMetadata() { return metadata; }
    public String getReturnUrl() { return returnUrl; }
}
