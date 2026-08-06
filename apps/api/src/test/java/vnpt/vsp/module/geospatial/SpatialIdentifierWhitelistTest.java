package vnpt.vsp.module.geospatial;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.mockito.ArgumentCaptor;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * The table and column named by a spatial lookup reach SQL only if they are
 * whitelisted.
 *
 * <p>{@code findFeaturesWithinRadius} and {@code findNearestFeature} concatenate
 * both identifiers into the statement — they have to, since no database binds an
 * identifier as a parameter — and until now they concatenated whatever string
 * the caller passed. Nothing calls them, which is the only reason that was not a
 * live injection. These tests are what keeps it from becoming one the day
 * somebody wires a request parameter to either.
 */
class SpatialIdentifierWhitelistTest {

    private static final GeometryFactory GEOMETRY_FACTORY =
            new GeometryFactory(new PrecisionModel(), 4326);

    private EntityManager entityManager;
    private GeospatialServiceImpl geospatialService;
    private Query query;

    @BeforeEach
    void setUp() {
        entityManager = mock(EntityManager.class);
        query = mock(Query.class);
        when(entityManager.createNativeQuery(anyString())).thenReturn(query);
        when(query.setParameter(anyString(), org.mockito.ArgumentMatchers.any())).thenReturn(query);
        when(query.getResultList()).thenReturn(List.of());
        geospatialService = new GeospatialServiceImpl(entityManager);
    }

    private static Point point() {
        return GEOMETRY_FACTORY.createPoint(new Coordinate(105.8, 21.0));
    }

    /**
     * The payload is what an injection through this hole would actually look
     * like: the {@code FROM} clause is the caller's, and the query hands its
     * result set straight back.
     */
    private static final String INJECTION =
            "greens WHERE 1=1 UNION SELECT id, 0 FROM golfer_accounts --";

    @Test
    @DisplayName("A table name carrying a UNION never reaches the database")
    void injectedTableIsRefusedBeforeAnySqlIsBuilt() {
        assertThatThrownBy(() ->
                geospatialService.findFeaturesWithinRadius(point(), 500, INJECTION, "location"))
                .isInstanceOf(VspApiException.class)
                .extracting(e -> ((VspApiException) e).getErrorCode())
                .isEqualTo(VspErrorCode.VALIDATION_001);

        verifyNoInteractions(entityManager);
    }

    @Test
    @DisplayName("The same for the nearest-feature query")
    void injectedTableIsRefusedByNearestFeature() {
        assertThatThrownBy(() ->
                geospatialService.findNearestFeature(point(), INJECTION, "location"))
                .isInstanceOf(VspApiException.class);

        verifyNoInteractions(entityManager);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "greens; DROP TABLE golfer_accounts",
            "greens--",
            "pg_shadow",
            "GREENS",
            " greens",
            "greens ",
            "golfer_accounts"
    })
    @DisplayName("Neither case folding, trimming nor a plain unlisted table gets through")
    void nothingOutsideTheWhitelistIsAccepted(String table) {
        assertThatThrownBy(() -> geospatialService.findNearestFeature(point(), table, "location"))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("A whitelisted table with someone else's column is refused — the pair is what is listed")
    void columnIsWhitelistedTogetherWithItsTable() {
        assertThatThrownBy(() ->
                geospatialService.findNearestFeature(point(), "greens", "password_hash"))
                .isInstanceOf(VspApiException.class);

        assertThatThrownBy(() ->
                geospatialService.findNearestFeature(point(), "greens", "location, (SELECT 1)"))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("Nulls are refused rather than concatenated as \"null\"")
    void nullIdentifiersAreRefused() {
        assertThatThrownBy(() -> geospatialService.findNearestFeature(point(), null, "location"))
                .isInstanceOf(VspApiException.class);
        assertThatThrownBy(() -> geospatialService.findNearestFeature(point(), "greens", null))
                .isInstanceOf(VspApiException.class);
    }

    /**
     * The refusal happens before the null-point shortcut, so a caller cannot
     * learn that its injected table was "accepted" by passing no point.
     */
    @Test
    @DisplayName("A bad identifier is refused even when the query would have been skipped anyway")
    void identifiersAreCheckedBeforeTheNullPointShortcut() {
        assertThatThrownBy(() -> geospatialService.findNearestFeature(null, INJECTION, "location"))
                .isInstanceOf(VspApiException.class);
        assertThatThrownBy(() -> geospatialService.findFeaturesWithinRadius(null, 0, INJECTION, "location"))
                .isInstanceOf(VspApiException.class);
    }

    @Test
    @DisplayName("A whitelisted pair still runs, and the SQL names exactly it")
    void whitelistedPairStillQueries() {
        geospatialService.findFeaturesWithinRadius(point(), 500, "greens", "location");

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(entityManager).createNativeQuery(sql.capture());
        assertThat(sql.getValue()).contains("FROM greens");
        assertThat(sql.getValue()).doesNotContain("UNION");
    }

    @ParameterizedTest
    @EnumSource(SpatialFeature.class)
    @DisplayName("Every whitelisted pair resolves to itself and is a plain identifier")
    void everyWhitelistedPairResolves(SpatialFeature feature) {
        assertThat(SpatialFeature.of(feature.table(), feature.geometryColumn()))
                .contains(feature);
        assertThat(feature.table()).matches("^[a-z][a-z0-9_]*$");
        assertThat(feature.geometryColumn()).matches("^[a-z][a-z0-9_]*$");
    }
}
