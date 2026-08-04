package vnpt.vsp.module.weather.dto;

import java.io.Serializable;
import java.time.Instant;

/**
 * Weather snapshot DTO — the primary API response object for the /weather endpoint.
 * Maps to packages/contracts/schemas/weather.yaml WeatherSnapshot schema.
 * Per Story 7.1 AC-1: wind, temperature, precipitation, safety fields.
 * Per Story 7.1 AC-3: source, timestamp, forecast/measurement type, stale warning.
 */
public class WeatherSnapshotDto implements Serializable {

    private static final long serialVersionUID = 1L;

    /** Unique ID: provider + location + timestamp hash */
    private String id;

    /** Provider name e.g. "openweathermap", "tomorrow_io" */
    private String provider;

    /** Location coordinates */
    private LocationDto location;

    /** When this snapshot was captured from the provider */
    private Instant capturedAt;

    /** When this snapshot becomes stale */
    private Instant expiresAt;

    /** True = forecast snapshot, false = current/measured */
    private boolean isForecast;

    private TemperatureDto temperature;
    private Integer humidity;
    private String condition; // enum: sunny, partly_cloudy, cloudy, overcast, light_rain, rain, heavy_rain, thunderstorm, fog, windy
    private WindDataDto wind;
    private VisibilityDto visibility;
    private PressureDto pressure;
    private Double feelsLike;
    private Integer precipitationProbability;
    private Integer uvIndex;

    // ─── Source metadata ───────────────────────────────────────────────────

    /** Display name of the provider */
    private String sourceName;

    /** Raw timestamp from the provider response */
    private String sourceTimestamp;

    // ─── Data quality ──────────────────────────────────────────────────────

    /** Accuracy class A/B/C/D from data quality model */
    private String accuracyClass;

    /** Confidence score 0.0–1.0 */
    private Double confidence;

    /** Verification status: "official" | "community" | "estimated" */
    private String verificationStatus;

    // ─── Response headers (transient, not serialized to JSON) ──────────────

    /** Whether this snapshot was served from stale cache */
    private transient boolean stale = false;

    /** Source display name for X-Weather-Source header */
    private transient String responseSource;

    /** Cached-at timestamp for X-Weather-Cached-At header */
    private transient Instant cachedAt;

    /** Fresh-until timestamp for X-Weather-Fresh-Until header */
    private transient Instant freshUntil;

    public WeatherSnapshotDto() {}

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getProvider() {
        return provider;
    }

    public void setProvider(String provider) {
        this.provider = provider;
    }

    public LocationDto getLocation() {
        return location;
    }

    public void setLocation(LocationDto location) {
        this.location = location;
    }

    public Instant getCapturedAt() {
        return capturedAt;
    }

    public void setCapturedAt(Instant capturedAt) {
        this.capturedAt = capturedAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public boolean isForecast() {
        return isForecast;
    }

    public void setForecast(boolean forecast) {
        isForecast = forecast;
    }

    public TemperatureDto getTemperature() {
        return temperature;
    }

    public void setTemperature(TemperatureDto temperature) {
        this.temperature = temperature;
    }

    public Integer getHumidity() {
        return humidity;
    }

    public void setHumidity(Integer humidity) {
        this.humidity = humidity;
    }

    public String getCondition() {
        return condition;
    }

    public void setCondition(String condition) {
        this.condition = condition;
    }

    public WindDataDto getWind() {
        return wind;
    }

    public void setWind(WindDataDto wind) {
        this.wind = wind;
    }

    public VisibilityDto getVisibility() {
        return visibility;
    }

    public void setVisibility(VisibilityDto visibility) {
        this.visibility = visibility;
    }

    public PressureDto getPressure() {
        return pressure;
    }

    public void setPressure(PressureDto pressure) {
        this.pressure = pressure;
    }

    public Double getFeelsLike() {
        return feelsLike;
    }

    public void setFeelsLike(Double feelsLike) {
        this.feelsLike = feelsLike;
    }

    public Integer getPrecipitationProbability() {
        return precipitationProbability;
    }

    public void setPrecipitationProbability(Integer precipitationProbability) {
        this.precipitationProbability = precipitationProbability;
    }

    public Integer getUvIndex() {
        return uvIndex;
    }

    public void setUvIndex(Integer uvIndex) {
        this.uvIndex = uvIndex;
    }

    public String getSourceName() {
        return sourceName;
    }

    public void setSourceName(String sourceName) {
        this.sourceName = sourceName;
    }

    public String getSourceTimestamp() {
        return sourceTimestamp;
    }

    public void setSourceTimestamp(String sourceTimestamp) {
        this.sourceTimestamp = sourceTimestamp;
    }

    public String getAccuracyClass() {
        return accuracyClass;
    }

    public void setAccuracyClass(String accuracyClass) {
        this.accuracyClass = accuracyClass;
    }

    public Double getConfidence() {
        return confidence;
    }

    public void setConfidence(Double confidence) {
        this.confidence = confidence;
    }

    public String getVerificationStatus() {
        return verificationStatus;
    }

    public void setVerificationStatus(String verificationStatus) {
        this.verificationStatus = verificationStatus;
    }

    // ─── Transient header helpers ──────────────────────────────────────────

    public boolean isStale() {
        return stale;
    }

    public void setStale(boolean stale) {
        this.stale = stale;
    }

    public String getResponseSource() {
        return responseSource;
    }

    public void setResponseSource(String responseSource) {
        this.responseSource = responseSource;
    }

    public Instant getCachedAt() {
        return cachedAt;
    }

    public void setCachedAt(Instant cachedAt) {
        this.cachedAt = cachedAt;
    }

    public Instant getFreshUntil() {
        return freshUntil;
    }

    public void setFreshUntil(Instant freshUntil) {
        this.freshUntil = freshUntil;
    }
}
