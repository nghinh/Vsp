package vnpt.vsp.module.market;

import java.util.Collections;
import java.util.List;

/**
 * Vietnam baseline defaults for all market configuration fields.
 *
 * All market configs start with these values and selectively override
 * only the fields that differ for their market.
 *
 * Story 12.4 — Slice 1: Vietnam Defaults
 */
public final class VietnamDefaults {

    VietnamDefaults() {} // Prevent instantiation

    /** Default locale for Vietnam. */
    public static final String LOCALE = "vi-VN";

    /** Default language code for Vietnam. */
    public static final String LANGUAGE = "vi";

    /** Default distance measurement unit for Vietnam. */
    public static final String MEASUREMENT_UNIT = "METRIC";

    /** Default timezone for Vietnam. */
    public static final String TIMEZONE = "Asia/Ho_Chi_Minh";

    /** Default currency code for Vietnam. */
    public static final String CURRENCY_CODE = "VND";

    /** Default date format for Vietnam. */
    public static final String DATE_FORMAT = "dd/MM/yyyy";

    /** Default data retention policy in days. */
    public static final int RETENTION_POLICY_DAYS = 365;

    /** Default fork GPS behavior for Vietnam (false = standard behavior). */
    public static final boolean FORK_GPS_BEHAVIOR = false;

    /** Default fork score behavior for Vietnam (false = standard behavior). */
    public static final boolean FORK_SCORE_BEHAVIOR = false;

    /** Default redistribution requires license flag for Vietnam. */
    public static final boolean REDISTRIBUTION_REQUIRES_LICENSE = false;

    /**
     * Default enabled provider IDs for Vietnam.
     * Empty list means all providers are enabled.
     */
    public static final List<String> ENABLED_PROVIDER_IDS = Collections.emptyList();

    /**
     * Default required license IDs for Vietnam.
     * Empty list means no specific licenses are required.
     */
    public static final List<String> REQUIRED_LICENSE_IDS = Collections.emptyList();
}
