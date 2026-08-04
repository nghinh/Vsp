package vnpt.vsp.module.weather.provider;

/**
 * Exception thrown by a WeatherProvider when fetching fails.
 */
public class WeatherProviderException extends RuntimeException {

    private final String providerName;

    public WeatherProviderException(String providerName, String message) {
        super(message);
        this.providerName = providerName;
    }

    public WeatherProviderException(String providerName, String message, Throwable cause) {
        super(message, cause);
        this.providerName = providerName;
    }

    public String getProviderName() {
        return providerName;
    }
}
