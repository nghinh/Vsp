package vnpt.vsp.module.geometry.vision;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import vnpt.vsp.module.ai.LlmGateway;

/**
 * The vision provider this deployment actually uses.
 *
 * <p>Its own configuration — {@code vsp.vision.*} — falling back to the
 * scorecard reader's when it is not set. Two reasons for the fallback: this
 * server already has a working multimodal endpoint configured for reading
 * photographed cards, and asking an operator to configure a second one
 * before they can try the feature is a reason not to try it.
 *
 * <p>Separate keys still matter once it is in use. Tracing a course is a
 * different budget from reading a scorecard, and a rate limit hit by one
 * should not stop the other.
 */
@Service
public class OpenAiCompatibleVisionProvider implements VisionProvider {

    private final LlmGateway ownGateway;
    private final LlmGateway scorecardGateway;
    private final String configuredModel;

    public OpenAiCompatibleVisionProvider(
            LlmGateway scorecardGateway,
            com.fasterxml.jackson.databind.ObjectMapper objectMapper,
            @Value("${vsp.vision.base-url:}") String baseUrl,
            @Value("${vsp.vision.api-key:}") String apiKey,
            @Value("${vsp.vision.model:}") String model) {
        this.scorecardGateway = scorecardGateway;
        this.configuredModel = model;
        this.ownGateway = baseUrl.isBlank() || apiKey.isBlank()
                ? null
                : new LlmGateway(objectMapper, baseUrl, apiKey, model);
    }

    private LlmGateway gateway() {
        return ownGateway != null ? ownGateway : scorecardGateway;
    }

    @Override
    public boolean isConfigured() {
        return gateway().isEnabled();
    }

    @Override
    public String modelVersion() {
        return configuredModel == null || configuredModel.isBlank()
                ? "scorecard-model" : configuredModel;
    }

    @Override
    public String analyzeImage(byte[] image, String mediaType, String prompt, int maxTokens) {
        return gateway().ask(image, mediaType, prompt, maxTokens);
    }
}
