package vnpt.vsp.module.course.repository;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.data.domain.PageRequest;
import jakarta.persistence.EntityManager;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.GolfFacility;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.persistence.PostgresTestSupport;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Finding a club by typing its name, however it gets typed.
 *
 * <p>Search matched {@code LOWER(name) LIKE '%query%'}, so "Long Biên" found
 * the club and "Long Bien" found nothing — the same club appearing and
 * disappearing depending on whether the golfer's keyboard put the diacritics
 * in. On a phone, most of the time, it does not.
 *
 * <p>Runs against Postgres and is skipped elsewhere. The query is native and
 * leans on {@code unaccent}, which H2 does not have — an H2 green here would
 * be a claim about a database nobody runs.
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
class CourseSearchPostgresTest {

    static boolean postgisAvailable() {
        return PostgresTestSupport.postgisAvailable();
    }

    @Autowired private CourseSearchRepository repository;
    @Autowired private EntityManager em;

    private static final String CLUB = "Cầu Giấy Sân Gôn Thử Nghiệm";

    @BeforeEach
    void setUp() {
        GolfFacility facility = new GolfFacility();
        facility.setName(CLUB);
        facility.setAddress("Phường Dịch Vọng, Hà Nội");
        stamp(facility.getMetadata());
        em.persist(facility);

        Course course = new Course();
        course.setFacility(facility);
        course.setName("Đường Sen");
        course.setHolesCount(9);
        course.setParTotal(36);
        stamp(course.getMetadata());
        em.persist(course);

        // Search only returns a course that has holes.
        Hole hole = new Hole();
        hole.setCourse(course);
        hole.setHoleNumber(1);
        hole.setPar(4);
        stamp(hole.getMetadata());
        em.persist(hole);
        em.flush();
    }

    private static void stamp(DataQualityMetadata metadata) {
        metadata.setPublisher("course-search-test");
        metadata.setEffectiveDate(LocalDate.now());
        metadata.setConfidence(BigDecimal.ZERO);
    }

    private List<String> find(String query) {
        return repository.searchByText(query, PageRequest.of(0, 20))
                .getContent().stream()
                .map(c -> c.getFacility().getName())
                .toList();
    }

    /// The bug, in one assertion: the same club, typed the way a phone types it.
    @Test
    @DisplayName("finds the club whether or not the diacritics were typed")
    void findsItWithoutDiacritics() {
        assertThat(find("Cầu Giấy")).contains(CLUB);
        assertThat(find("Cau Giay")).contains(CLUB);
        assertThat(find("cau giay")).contains(CLUB);
        assertThat(find("CAU GIAY")).contains(CLUB);
    }

    /// đ is a letter of its own, and an ASCII fold that does not know it turns
    /// "Đường" into "ường".
    @Test
    @DisplayName("folds đ to d, which a plain ASCII fold does not")
    void foldsTheVietnameseD() {
        assertThat(find("Duong Sen")).contains(CLUB);
        assertThat(find("đường sen")).contains(CLUB);
    }

    /// The old query needed the whole phrase as one substring, so a golfer who
    /// typed the words in a different order found nothing.
    @Test
    @DisplayName("matches the words in any order, and across name and course")
    void matchesWordByWord() {
        assertThat(find("giay cau")).contains(CLUB);
        assertThat(find("cau giay sen")).contains(CLUB);
        assertThat(find("san gon thu nghiem cau giay")).contains(CLUB);
    }

    @Test
    @DisplayName("finds a club by its address")
    void matchesTheAddress() {
        assertThat(find("Dich Vong")).contains(CLUB);
    }

    /// Every word has to appear. Without that, one matching word would drag in
    /// every club that happened to share it.
    @Test
    @DisplayName("refuses a query with a word the club does not have")
    void everyWordMustMatch() {
        assertThat(find("cau giay Đà Nẵng")).doesNotContain(CLUB);
    }

    /// What the app asks for when it opens the list.
    @Test
    @DisplayName("an empty query is everything, not nothing")
    void anEmptyQueryMatchesEverything() {
        assertThat(find("")).contains(CLUB);
        assertThat(find("   ")).contains(CLUB);
    }
}
