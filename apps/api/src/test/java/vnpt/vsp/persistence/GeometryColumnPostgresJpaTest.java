package vnpt.vsp.persistence;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import vnpt.vsp.module.course.entity.Bunker;
import vnpt.vsp.module.course.entity.CartPath;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.FairwaySegment;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.entity.Green;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.entity.Landmark;
import vnpt.vsp.module.course.entity.OutOfBounds;
import vnpt.vsp.module.course.entity.PenaltyArea;
import vnpt.vsp.module.course.entity.PinPosition;
import vnpt.vsp.module.course.entity.TeeBox;
import vnpt.vsp.module.course.entity.WaterHazard;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Proves — against a real PostgreSQL/PostGIS database, not H2 — that every
 * entity owning a {@code geometry} column can actually be INSERTed through JPA.
 *
 * <p>This is the test that was missing. A geometry column mapped as a plain
 * Java {@code String} is bound by pgjdbc as {@code varchar}, which PostgreSQL
 * rejects while parsing the statement ("column is of type geometry but
 * expression is of type character varying") — before it ever looks at the
 * value, so even a NULL geometry fails. H2 converts a varchar to GEOMETRY
 * happily, so the whole H2-backed suite passed while not one of these rows
 * could be written to production. The rows that do exist in these tables were
 * inserted by raw SQL from the data pipeline, which is why nobody noticed.</p>
 *
 * <p>Every assertion here therefore has to run against PostGIS to mean
 * anything. When no PostgreSQL is reachable the whole class is skipped rather
 * than silently passing against a substitute database — a skipped test is
 * honest, a green H2 test would be a lie. Point it at another database with
 * {@code POSTGRES_HOST}/{@code POSTGRES_PORT}/{@code POSTGRES_DB}/
 * {@code POSTGRES_USER}/{@code POSTGRES_PASSWORD}; it defaults to the local dev
 * stack.</p>
 *
 * <p>{@code ddl-auto} is pinned to {@code none} — this test must never touch
 * the schema of the database it is pointed at — and every test rolls back.</p>
 *
 * @see WktGeometryType
 */
@DataJpaTest(properties = {
        "spring.datasource.url=jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DB:vsp}",
        "spring.datasource.username=${POSTGRES_USER:vsp}",
        "spring.datasource.password=${POSTGRES_PASSWORD:vsp_dev_password}",
        "spring.datasource.driver-class-name=org.postgresql.Driver",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.flyway.enabled=false",
        "spring.sql.init.mode=never"
})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@EnabledIf("postgisAvailable")
class GeometryColumnPostgresJpaTest {

    /**
     * Evaluated before the Spring context is built, so an absent database skips
     * instead of failing.
     */
    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    // ─── Fixture ──────────────────────────────────────────────────────────────

    // Written the way PostGIS prints them back, so the round-trip comparison is
    // about the shape rather than about decimal formatting.
    private static final String POLYGON =
            "POLYGON((106 10,106.001 10,106.001 10.001,106 10.001,106 10))";
    private static final String LINESTRING = "LINESTRING(106 10,106.001 10.001)";
    private static final String POINT = "POINT(106.0005 10.0005)";

    @Autowired
    private EntityManager em;

    private Hole hole;

    private Hole hole() {
        if (hole == null) {
            GolfFacility facility = new GolfFacility();
            facility.setName("Geometry insert probe facility");
            facility.setLocation(POINT);
            stamp(facility.getMetadata());
            em.persist(facility);

            Course course = new Course();
            course.setFacility(facility);
            course.setName("Geometry insert probe course");
            course.setHolesCount(18);
            course.setParTotal(72);
            course.setLocation(POLYGON);
            stamp(course.getMetadata());
            em.persist(course);

            Hole h = new Hole();
            h.setCourse(course);
            h.setHoleNumber(1);
            h.setPar(4);
            h.setTeeingGroundLocation(POINT);
            h.setGreenLocation(POINT);
            stamp(h.getMetadata());
            em.persist(h);
            em.flush();
            hole = h;
        }
        return hole;
    }

    private static void stamp(vnpt.vsp.module.course.entity.DataQualityMetadata m) {
        m.setPublisher("geometry-insert-test");
        m.setEffectiveDate(LocalDate.now());
        m.setConfidence(BigDecimal.ZERO);
    }

    /**
     * Reads the column back through PostGIS. A geometry that survived the INSERT
     * has a real shape and SRID 4326; a varchar bind would never have got here.
     */
    private void assertStored(String table, Long id, String column, String expectedWkt) {
        Object[] row = (Object[]) em.createNativeQuery(
                        "SELECT ST_AsText(" + column + "), ST_SRID(" + column + ") FROM " + table + " WHERE id = :id")
                .setParameter("id", id)
                .getSingleResult();
        assertNotNull(row[0], column + " on " + table + " was stored as NULL");
        assertEquals(4326, ((Number) row[1]).intValue(), "SRID on " + table + "." + column);
        assertEquals(normalise(expectedWkt), normalise((String) row[0]), "shape on " + table + "." + column);
    }

    /** PostGIS varies the spacing it prints; nothing else about the text may differ. */
    private static String normalise(String wkt) {
        return wkt.replaceAll("\\s+", "").toUpperCase();
    }

    // ─── The write paths ──────────────────────────────────────────────────────

    @Test
    @DisplayName("Hole: both geometry columns insert (admin hole create/update path)")
    void holeInserts() {
        Hole h = hole();
        assertStored("holes", h.getId(), "teeing_ground_location", POINT);
        assertStored("holes", h.getId(), "green_location", POINT);
    }

    @Test
    @DisplayName("Course and GolfFacility: geometry inserts (admin course/facility create path)")
    void courseAndFacilityInsert() {
        Course course = hole().getCourse();
        assertStored("courses", course.getId(), "location", POLYGON);
        assertStored("golf_facilities", course.getFacility().getId(), "location", POINT);
    }

    @Test
    @DisplayName("Green: geometry insert (GeoJSON import path)")
    void greenInserts() {
        Green g = new Green();
        g.setHole(hole());
        g.setLocation(POLYGON);
        stamp(g.getMetadata());
        em.persist(g);
        em.flush();
        assertStored("greens", g.getId(), "location", POLYGON);
    }

    @Test
    @DisplayName("Bunker: geometry insert (GeoJSON import path)")
    void bunkerInserts() {
        Bunker b = new Bunker();
        b.setHole(hole());
        b.setLocation(POLYGON);
        stamp(b.getMetadata());
        em.persist(b);
        em.flush();
        assertStored("bunkers", b.getId(), "location", POLYGON);
    }

    @Test
    @DisplayName("FairwaySegment: geometry insert (GeoJSON import path)")
    void fairwaySegmentInserts() {
        FairwaySegment f = new FairwaySegment();
        f.setHole(hole());
        f.setLocation(POLYGON);
        stamp(f.getMetadata());
        em.persist(f);
        em.flush();
        assertStored("fairway_segments", f.getId(), "location", POLYGON);
    }

    @Test
    @DisplayName("WaterHazard: geometry insert (GeoJSON import path)")
    void waterHazardInserts() {
        WaterHazard w = new WaterHazard();
        w.setHole(hole());
        w.setLocation(POLYGON);
        w.setHazardType("WATER");
        stamp(w.getMetadata());
        em.persist(w);
        em.flush();
        assertStored("water_hazards", w.getId(), "location", POLYGON);
    }

    @Test
    @DisplayName("OutOfBounds: geometry insert (GeoJSON import path)")
    void outOfBoundsInserts() {
        OutOfBounds ob = new OutOfBounds();
        ob.setHole(hole());
        ob.setLocation(POLYGON);
        stamp(ob.getMetadata());
        em.persist(ob);
        em.flush();
        assertStored("out_of_bounds", ob.getId(), "location", POLYGON);
    }

    @Test
    @DisplayName("PenaltyArea: geometry insert (GeoJSON import path)")
    void penaltyAreaInserts() {
        PenaltyArea pa = new PenaltyArea();
        pa.setHole(hole());
        pa.setLocation(POLYGON);
        stamp(pa.getMetadata());
        em.persist(pa);
        em.flush();
        assertStored("penalty_areas", pa.getId(), "location", POLYGON);
    }

    @Test
    @DisplayName("TeeBox: geometry insert (GeoJSON import path)")
    void teeBoxInserts() {
        TeeBox t = new TeeBox();
        t.setHole(hole());
        t.setLocation(POLYGON);
        stamp(t.getMetadata());
        em.persist(t);
        em.flush();
        assertStored("tee_boxes", t.getId(), "location", POLYGON);
    }

    @Test
    @DisplayName("CartPath: LineString geometry insert (GeoJSON import path)")
    void cartPathInserts() {
        CartPath cp = new CartPath();
        cp.setHole(hole());
        cp.setLocation(LINESTRING);
        cp.setPathType("MAIN");
        stamp(cp.getMetadata());
        em.persist(cp);
        em.flush();
        assertStored("cart_paths", cp.getId(), "location", LINESTRING);
    }

    @Test
    @DisplayName("Landmark: geometry insert (GeoJSON import path)")
    void landmarkInserts() {
        Landmark lm = new Landmark();
        lm.setHole(hole());
        lm.setLocation(POINT);
        lm.setLandmarkType("TREE");
        lm.setName("Probe landmark");
        stamp(lm.getMetadata());
        em.persist(lm);
        em.flush();
        assertStored("landmarks", lm.getId(), "location", POINT);
    }

    @Test
    @DisplayName("PinPosition (course): geometry insert (GeoJSON import path)")
    void coursePinPositionInserts() {
        PinPosition pp = new PinPosition();
        pp.setHole(hole());
        pp.setLocation(POINT);
        pp.setPinPositionType("CURRENT");
        pp.setEffectiveDate(LocalDate.now());
        stamp(pp.getMetadata());
        em.persist(pp);
        em.flush();
        assertStored("pin_positions", pp.getId(), "location", POINT);
    }

    @Test
    @DisplayName("PinPosition (operations): geometry insert (greenkeeper pin rotation path)")
    void operationsPinPositionInserts() {
        vnpt.vsp.module.operations.entity.PinPosition pin =
                new vnpt.vsp.module.operations.entity.PinPosition();
        pin.setHole(hole());
        pin.setLocation(POINT);
        pin.setPinPositionType("CURRENT");
        pin.setEffectiveFrom(Instant.now());
        pin.setPublishedBy("geometry-insert-test");
        stamp(pin.getMetadata());
        em.persist(pin);
        em.flush();
        assertStored("pin_positions_ops", pin.getId(), "location", POINT);
    }

    // ─── The read side ────────────────────────────────────────────────────────

    @Test
    @DisplayName("A geometry column read through the entity is EWKB hex, not WKT — ST_AsText is the only way back")
    void readingAGeometryColumnGivesEwkbHexNotWkt() {
        Green g = new Green();
        g.setHole(hole());
        g.setLocation(POLYGON);
        stamp(g.getMetadata());
        em.persist(g);
        em.flush();
        Long id = g.getId();
        em.clear();

        String asMapped = em.find(Green.class, id).getLocation();
        String asText = (String) em.createNativeQuery(
                        "SELECT ST_AsText(location) FROM greens WHERE id = :id")
                .setParameter("id", id)
                .getSingleResult();

        // This is why any response field documented as WKT has to come from
        // ST_AsText rather than from the mapped entity field.
        assertTrue(asMapped.matches("(?i)[0-9a-f]+"),
                "expected EWKB hex from the mapped field but got: " + asMapped);
        assertEquals(normalise(POLYGON), normalise(asText));

        // …and the hex a read produced still round-trips back into the column.
        Green reloaded = em.find(Green.class, id);
        reloaded.getMetadata().setPublisher("geometry-insert-test-2");
        em.flush();
        assertStored("greens", id, "location", POLYGON);
    }

    @Test
    @DisplayName("A NULL geometry inserts too — the varchar bind failed even on NULL")
    void nullGeometryInserts() {
        GolfFacility facility = new GolfFacility();
        facility.setName("Geometry insert probe facility (no location)");
        facility.setLocation(null);
        stamp(facility.getMetadata());
        em.persist(facility);
        em.flush();

        Object stored = em.createNativeQuery(
                        "SELECT ST_AsText(location) FROM golf_facilities WHERE id = :id")
                .setParameter("id", facility.getId())
                .getSingleResult();
        assertEquals(null, stored, "location should be NULL, and the INSERT should still have succeeded");
    }
}
