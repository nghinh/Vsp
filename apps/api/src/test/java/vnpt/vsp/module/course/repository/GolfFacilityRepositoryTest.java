package vnpt.vsp.module.course.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;
import vnpt.vsp.module.course.entity.GolfFacility;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Repository tests for {@link GolfFacilityRepository}.
 * Verifies CRUD operations and custom queries per Story 3.1 AC-1.
 */
@DataJpaTest
@ActiveProfiles("test")
class GolfFacilityRepositoryTest {

    @Autowired
    private GolfFacilityRepository repository;

    @Autowired
    private TestEntityManager em;

    @Test
    void save_andFindById_works() {
        GolfFacility facility = new GolfFacility();
        facility.getMetadata().setPublisher("TEST");
        facility.setName("Van Quan Golf Resort");
        facility.setAddress("Van Quan, Ha Dong, Hanoi");
        facility.setLocation("SRID=4326;POINT(105.785 20.968)");

        GolfFacility saved = repository.save(facility);
        em.flush();

        assertNotNull(saved.getId());
        assertEquals("Van Quan Golf Resort", saved.getName());

        Optional<GolfFacility> found = repository.findById(saved.getId());
        assertTrue(found.isPresent());
        assertEquals("Van Quan Golf Resort", found.get().getName());
    }

    @Test
    void findByName_usingContains() {
        GolfFacility facility = new GolfFacility();
        facility.getMetadata().setPublisher("TEST");
        facility.setName("Dalat Golf Club");
        repository.save(facility);
        em.flush();

        var results = repository.findByNameContainingIgnoreCase("dalat");
        assertEquals(1, results.size());
        assertEquals("Dalat Golf Club", results.get(0).getName());
    }

    @Test
    void findByName_usingExactMatch() {
        GolfFacility facility = new GolfFacility();
        facility.getMetadata().setPublisher("TEST");
        facility.setName("Truong Sa Golf");
        repository.save(facility);
        em.flush();

        Optional<GolfFacility> found = repository.findByName("Truong Sa Golf");
        assertTrue(found.isPresent());

        Optional<GolfFacility> notFound = repository.findByName("Non Existent");
        assertFalse(notFound.isPresent());
    }

    @Test
    void countCoursesByFacilityId_returnsZeroForNewFacility() {
        GolfFacility facility = new GolfFacility();
        facility.getMetadata().setPublisher("TEST");
        facility.setName("New Facility");
        GolfFacility saved = repository.save(facility);
        em.flush();

        long count = repository.countCoursesByFacilityId(saved.getId());
        assertEquals(0, count);
    }

    @Test
    void delete_removesFacility() {
        GolfFacility facility = new GolfFacility();
        facility.getMetadata().setPublisher("TEST");
        facility.setName("To Be Deleted");
        GolfFacility saved = repository.save(facility);
        em.flush();

        repository.delete(saved);
        em.flush();

        assertFalse(repository.findById(saved.getId()).isPresent());
    }
}
