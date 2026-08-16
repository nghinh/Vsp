package vnpt.vsp.module.geometry.vision;

/**
 * Whatever reads a picture for us.
 *
 * <p>An interface rather than a call to one vendor's SDK, because the
 * operator picks the model: an OpenAI-compatible endpoint today, something
 * self-hosted tomorrow, and the code that traces golf holes should not know
 * the difference. Configuration is server-side only — a vision key on a
 * phone is a key in everybody's hands.
 */
public interface VisionProvider {

    /// False when this deployment has no model configured. Callers refuse
    /// rather than pretend: an empty answer looks exactly like a hole with
    /// no features.
    boolean isConfigured();

    /// Which model answered. Recorded against everything it draws, so a
    /// later, better model's work can be told apart from its predecessor's.
    String modelVersion();

    /**
     * @param image     the picture, already encoded
     * @param mediaType its MIME type
     * @param prompt    what to look for and how to answer
     * @return the model's answer, verbatim; callers do the validating
     */
    String analyzeImage(byte[] image, String mediaType, String prompt, int maxTokens);
}
