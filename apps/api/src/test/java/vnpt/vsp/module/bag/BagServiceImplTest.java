package vnpt.vsp.module.bag;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.bag.dto.*;
import vnpt.vsp.module.bag.entity.Club;
import vnpt.vsp.module.bag.entity.GolfBag;
import vnpt.vsp.module.bag.repository.ClubRepository;
import vnpt.vsp.module.bag.repository.GolfBagRepository;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link BagServiceImpl}.
 * Tests: create bag, list bags, setActiveBag (only one active), cannot delete last bag,
 * create club with all fields, update club, delete club, minimum data threshold check.
 * Per Story 2.4 AC-1: club fields (clubType, loft, carryDistance, totalDistance, dispersion, shaft, useDate).
 * Per Story 2.4 AC-2: exactly one bag active at a time.
 * Per Story 2.4 AC-3: minimum data threshold check.
 */
@ExtendWith(MockitoExtension.class)
class BagServiceImplTest {

    @Mock
    private GolfBagRepository bagRepository;

    @Mock
    private ClubRepository clubRepository;

    @Mock
    private AuditService auditService;

    private BagServiceImpl bagService;

    @BeforeEach
    void setUp() {
        bagService = new BagServiceImpl(bagRepository, clubRepository, auditService);
    }

    // ─── Bag CRUD Tests ─────────────────────────────────────────────────────────

    @Test
    void getBags_returnsBags_whenBagsExist() {
        // Given
        Long accountId = 42L;
        GolfBag bag = createBag(1L, accountId, "My Bag", true);
        when(bagRepository.findByGolferAccountId(accountId)).thenReturn(List.of(bag));

        // When
        List<GolfBagResponse> bags = bagService.getBags(accountId);

        // Then
        assertEquals(1, bags.size());
        assertEquals("My Bag", bags.get(0).getName());
        assertTrue(bags.get(0).getIsActive());
        verify(bagRepository, never()).save(any());
    }

    @Test
    void getBags_createsDefaultBag_whenNoBagsExist() {
        // Given
        Long accountId = 99L;
        when(bagRepository.findByGolferAccountId(accountId)).thenReturn(List.of());
        when(bagRepository.save(any(GolfBag.class))).thenAnswer(invocation -> {
            GolfBag b = invocation.getArgument(0);
            b.setId(1L);
            b.setCreatedAt(Instant.now());
            b.setUpdatedAt(Instant.now());
            return b;
        });

        // When
        List<GolfBagResponse> bags = bagService.getBags(accountId);

        // Then
        assertEquals(1, bags.size());
        assertEquals("My Bag", bags.get(0).getName());
        assertTrue(bags.get(0).getIsActive());
        verify(bagRepository).save(any(GolfBag.class));
    }

    @Test
    void createBag_setsBagFields() {
        // Given
        Long accountId = 42L;
        when(bagRepository.save(any(GolfBag.class))).thenAnswer(invocation -> {
            GolfBag b = invocation.getArgument(0);
            b.setId(1L);
            b.setCreatedAt(Instant.now());
            b.setUpdatedAt(Instant.now());
            return b;
        });

        CreateGolfBagRequest request = new CreateGolfBagRequest("New Driver Bag");

        // When
        GolfBagResponse response = bagService.createBag(accountId, request);

        // Then
        assertEquals("New Driver Bag", response.getName());
        assertFalse(response.getIsActive());
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.BAG_CREATE),
                eq("GolfBag"),
                anyString(),
                isNull(),
                anyString(),
                isNull()
        );
    }

    @Test
    void updateBag_updatesName() {
        // Given
        Long accountId = 42L;
        Long bagId = 1L;
        GolfBag bag = createBag(bagId, accountId, "Old Name", false);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(bagRepository.save(any(GolfBag.class))).thenAnswer(invocation -> {
            GolfBag b = invocation.getArgument(0);
            b.setUpdatedAt(Instant.now());
            return b;
        });

        UpdateGolfBagRequest request = new UpdateGolfBagRequest();
        request.setName("Updated Name");

        // When
        GolfBagResponse response = bagService.updateBag(accountId, bagId, request);

        // Then
        assertEquals("Updated Name", response.getName());
    }

    // ─── AC-2: Exactly one active bag ─────────────────────────────────────────

    @Test
    void setActiveBag_deactivatesOthers_andActivatesTarget() {
        // Given
        Long accountId = 42L;
        Long bagId = 2L;
        GolfBag otherBag = createBag(1L, accountId, "Other Bag", true);
        GolfBag targetBag = createBag(bagId, accountId, "Target Bag", false);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(targetBag));
        when(bagRepository.save(any(GolfBag.class))).thenAnswer(invocation -> invocation.getArgument(0));

        // When
        GolfBagResponse response = bagService.setActiveBag(accountId, bagId);

        // Then
        verify(bagRepository).deactivateAllForAccount(accountId);
        assertTrue(response.getIsActive());
    }

    @Test
    void setActiveBag_throws_whenBagNotFound() {
        // Given
        Long accountId = 42L;
        Long bagId = 999L;
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.empty());

        // When/Then
        VspApiException exception = assertThrows(
                VspApiException.class,
                () -> bagService.setActiveBag(accountId, bagId)
        );
        assertEquals("VSP-ERR-BAG-001", exception.getErrorCode().getCode());
    }

    @Test
    void updateBag_withIsActiveTrue_deactivatesOthers() {
        // Given
        Long accountId = 42L;
        Long bagId = 2L;
        GolfBag targetBag = createBag(bagId, accountId, "Target Bag", false);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(targetBag));
        when(bagRepository.save(any(GolfBag.class))).thenAnswer(invocation -> invocation.getArgument(0));

        UpdateGolfBagRequest request = new UpdateGolfBagRequest();
        request.setIsActive(true);

        // When
        bagService.updateBag(accountId, bagId, request);

        // Then
        verify(bagRepository).deactivateAllForAccount(accountId);
    }

    // ─── AC-2: Cannot delete last bag ─────────────────────────────────────────

    @Test
    void deleteBag_throwsBAG_002_whenLastBag() {
        // Given
        Long accountId = 42L;
        Long bagId = 1L;
        GolfBag bag = createBag(bagId, accountId, "Only Bag", false);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(bagRepository.countByGolferAccountId(accountId)).thenReturn(1L);

        // When/Then
        VspApiException exception = assertThrows(
                VspApiException.class,
                () -> bagService.deleteBag(accountId, bagId)
        );
        assertEquals("VSP-ERR-BAG-002", exception.getErrorCode().getCode());
    }

    @Test
    void deleteBag_succeeds_whenNotLastBag() {
        // Given
        Long accountId = 42L;
        Long bagId = 2L;
        GolfBag bag = createBag(bagId, accountId, "Second Bag", false);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(bagRepository.countByGolferAccountId(accountId)).thenReturn(2L);
        doNothing().when(bagRepository).delete(bag);

        // When
        bagService.deleteBag(accountId, bagId);

        // Then
        verify(bagRepository).delete(bag);
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.BAG_DELETE),
                eq("GolfBag"),
                eq("2"),
                anyString(),
                isNull(),
                isNull()
        );
    }

    // ─── Club CRUD Tests ───────────────────────────────────────────────────────

    @Test
    void createClub_setsAllFields() {
        // Given
        Long accountId = 42L;
        Long bagId = 1L;
        GolfBag bag = createBag(bagId, accountId, "My Bag", false);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(clubRepository.save(any(Club.class))).thenAnswer(invocation -> {
            Club c = invocation.getArgument(0);
            c.setId(1L);
            c.setCreatedAt(Instant.now());
            c.setUpdatedAt(Instant.now());
            return c;
        });

        CreateClubRequest request = new CreateClubRequest();
        request.setClubType("DRIVER");
        request.setLoft(10.5);
        request.setCarryDistance(220.0);
        request.setTotalDistance(235.0);
        request.setDispersion(5.2);
        request.setShaft("Graphite, Regular Flex");
        request.setUseDate("2026-01-15");

        // When
        ClubResponse response = bagService.createClub(accountId, bagId, request);

        // Then
        assertEquals("DRIVER", response.getClubType());
        assertEquals(10.5, response.getLoft());
        assertEquals(220.0, response.getCarryDistance());
        assertEquals(235.0, response.getTotalDistance());
        assertEquals(5.2, response.getDispersion());
        assertEquals("Graphite, Regular Flex", response.getShaft());
        assertEquals(LocalDate.of(2026, 1, 15), response.getUseDate());
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.CLUB_CREATE),
                eq("Club"),
                anyString(),
                isNull(),
                anyString(),
                isNull()
        );
    }

    @Test
    void updateClub_updatesOnlyProvidedFields() {
        // Given
        Long accountId = 42L;
        Long bagId = 1L;
        Long clubId = 1L;
        GolfBag bag = createBag(bagId, accountId, "My Bag", false);
        Club existingClub = createClub(clubId, bag, "DRIVER", 10.5, 220.0, 235.0, 5.2);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(clubRepository.findByIdAndGolfBagId(clubId, bagId)).thenReturn(Optional.of(existingClub));
        when(clubRepository.save(any(Club.class))).thenAnswer(invocation -> {
            Club c = invocation.getArgument(0);
            c.setUpdatedAt(Instant.now());
            return c;
        });

        UpdateClubRequest request = new UpdateClubRequest();
        request.setLoft(11.0); // only loft changed
        request.setCarryDistance(null); // should stay unchanged

        // When
        ClubResponse response = bagService.updateClub(accountId, bagId, clubId, request);

        // Then
        assertEquals(11.0, response.getLoft()); // changed
        assertEquals(220.0, response.getCarryDistance()); // unchanged
    }

    @Test
    void deleteClub_deletesAndAudits() {
        // Given
        Long accountId = 42L;
        Long bagId = 1L;
        Long clubId = 1L;
        GolfBag bag = createBag(bagId, accountId, "My Bag", false);
        Club club = createClub(clubId, bag, "WEDGE", 52.0, 90.0, 95.0, 3.0);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(clubRepository.findByIdAndGolfBagId(clubId, bagId)).thenReturn(Optional.of(club));
        doNothing().when(clubRepository).delete(club);

        // When
        bagService.deleteClub(accountId, bagId, clubId);

        // Then
        verify(clubRepository).delete(club);
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.CLUB_DELETE),
                eq("Club"),
                eq("1"),
                anyString(),
                isNull(),
                isNull()
        );
    }

    @Test
    void createClub_throwsBAG_001_whenBagNotFound() {
        // Given
        Long accountId = 42L;
        Long bagId = 999L;
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.empty());

        CreateClubRequest request = new CreateClubRequest();
        request.setClubType("DRIVER");

        // When/Then
        VspApiException exception = assertThrows(
                VspApiException.class,
                () -> bagService.createClub(accountId, bagId, request)
        );
        assertEquals("VSP-ERR-BAG-001", exception.getErrorCode().getCode());
    }

    @Test
    void updateClub_throwsCLUB_001_whenClubNotFound() {
        // Given
        Long accountId = 42L;
        Long bagId = 1L;
        Long clubId = 999L;
        GolfBag bag = createBag(bagId, accountId, "My Bag", false);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(clubRepository.findByIdAndGolfBagId(clubId, bagId)).thenReturn(Optional.empty());

        UpdateClubRequest request = new UpdateClubRequest();
        request.setLoft(15.0);

        // When/Then
        VspApiException exception = assertThrows(
                VspApiException.class,
                () -> bagService.updateClub(accountId, bagId, clubId, request)
        );
        assertEquals("VSP-ERR-CLUB-001", exception.getErrorCode().getCode());
    }

    // ─── AC-3: Minimum data threshold ─────────────────────────────────────────

    @Test
    void hasMinimumClubData_returnsTrue_whenAtLeastOneClubHasCarryDistance() {
        // Given
        Long accountId = 42L;
        Long bagId = 1L;
        GolfBag bag = createBag(bagId, accountId, "My Bag", true);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(clubRepository.countByGolfBagIdAndCarryDistanceIsNotNull(bagId)).thenReturn(1L);

        // When
        boolean result = bagService.hasMinimumClubData(accountId, bagId);

        // Then
        assertTrue(result);
    }

    @Test
    void hasMinimumClubData_returnsFalse_whenNoClubsWithCarryDistance() {
        // Given
        Long accountId = 42L;
        Long bagId = 1L;
        GolfBag bag = createBag(bagId, accountId, "My Bag", true);
        when(bagRepository.findByIdAndGolferAccountId(bagId, accountId)).thenReturn(Optional.of(bag));
        when(clubRepository.countByGolfBagIdAndCarryDistanceIsNotNull(bagId)).thenReturn(0L);

        // When
        boolean result = bagService.hasMinimumClubData(accountId, bagId);

        // Then
        assertFalse(result);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private GolfBag createBag(Long id, Long accountId, String name, boolean isActive) {
        GolfBag bag = new GolfBag();
        bag.setId(id);
        bag.setGolferAccountId(accountId);
        bag.setName(name);
        bag.setIsActive(isActive);
        bag.setClubs(new ArrayList<>());
        bag.setCreatedAt(Instant.parse("2026-08-01T10:00:00Z"));
        bag.setUpdatedAt(Instant.parse("2026-08-01T10:00:00Z"));
        return bag;
    }

    private Club createClub(Long id, GolfBag bag, String clubType, Double loft,
                             Double carryDistance, Double totalDistance, Double dispersion) {
        Club club = new Club();
        club.setId(id);
        club.setGolfBag(bag);
        club.setClubType(Club.ClubType.valueOf(clubType));
        club.setLoft(loft);
        club.setCarryDistance(carryDistance);
        club.setTotalDistance(totalDistance);
        club.setDispersion(dispersion);
        club.setCreatedAt(Instant.parse("2026-08-01T10:00:00Z"));
        club.setUpdatedAt(Instant.parse("2026-08-01T10:00:00Z"));
        return club;
    }
}
