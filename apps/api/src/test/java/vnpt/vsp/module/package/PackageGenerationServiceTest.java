package vnpt.vsp.module.pkg;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.test.util.ReflectionTestUtils;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.operations.OperationsService;
import vnpt.vsp.module.pkg.entity.CoursePackageManifest;
import vnpt.vsp.module.pkg.entity.PackageBuildJob;
import vnpt.vsp.module.pkg.entity.PackageBuildStatus;
import vnpt.vsp.module.pkg.entity.PackageFileEntry;
import vnpt.vsp.module.pkg.repository.PackageBuildJobRepository;
import vnpt.vsp.module.pkg.repository.PackageManifestRepository;
import vnpt.vsp.module.pkg.storage.ObjectStorageService;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tests for the package build pipeline.
 *
 * <p>There were none, which is most of why the following was true for every
 * course in the database: a build ran all six stages, reported
 * {@code COMPLETED}, and produced a package with no course in it. Nothing
 * checked that a finished build had built anything.</p>
 *
 * <p>Two failures conspired. Geometry was never assembled — the manifest
 * advertised a {@code geometry.geojson} that no stage wrote. And the version
 * was a pure function of the data version, so {@code persistManifest} found its
 * own seeded placeholder already sitting on that version and returned early;
 * every rebuild of a course, forever, was a no-op that reported success.</p>
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PackageGenerationServiceTest {

    @Mock private PackageBuildJobRepository jobRepository;
    @Mock private PackageManifestRepository manifestRepository;
    @Mock private ObjectStorageService storageService;
    @Mock private OperationsService operationsService;
    @Mock private CourseRepository courseRepository;
    @Mock private HoleGeometryAssembler holeGeometryAssembler;

    private PackageGenerationService service;
    private PackageBuildJob job;

    private static final Long COURSE_ID = 8L;
    private static final Long DATA_VERSION_ID = 8L;

    @BeforeEach
    void setUp() {
        service = new PackageGenerationService(
                jobRepository, manifestRepository, storageService, operationsService,
                courseRepository, holeGeometryAssembler, "http://localhost:8080/packages");

        job = new PackageBuildJob(COURSE_ID, DATA_VERSION_ID, "admin@vsp");
        ReflectionTestUtils.setField(job, "id", UUID.randomUUID());

        when(jobRepository.findById(job.getId())).thenReturn(Optional.of(job));
        when(courseRepository.existsById(COURSE_ID)).thenReturn(true);
        when(operationsService.getAllPinPositions(anyLong(), any())).thenReturn(List.of());
        when(operationsService.getAllGreenConditions(anyLong(), any())).thenReturn(List.of());
        when(operationsService.getCourseConditions(anyLong(), any())).thenReturn(List.of());
        when(manifestRepository.findByCourseIdOrderByVersionDesc(anyLong())).thenReturn(List.of());
        when(manifestRepository.findByCourseIdAndVersion(anyLong(), anyString()))
                .thenReturn(Optional.empty());
        when(storageService.uploadFile(any(), anyLong(), anyString(), any(), anyString()))
                .thenReturn("file:///tmp/x");

        holesAvailable(1, 2, 3);
    }

    private void holesAvailable(int... numbers) {
        var documents = java.util.Arrays.stream(numbers)
                .mapToObj(n -> new HoleGeometryAssembler.HoleGeometryDocument(
                        n,
                        "hole_" + n + ".geojson",
                        Map.of("holeId", String.valueOf(n), "holeNumber", n)))
                .toList();
        when(holeGeometryAssembler.assemble(COURSE_ID)).thenReturn(documents);
    }

    private CoursePackageManifest persistedManifest() {
        ArgumentCaptor<CoursePackageManifest> captor =
                ArgumentCaptor.forClass(CoursePackageManifest.class);
        verify(manifestRepository).save(captor.capture());
        return captor.getValue();
    }

    // ─── A build that produced nothing must not report success ─────────────

    @Test
    void aCourseWithNoPackageableGeometryFailsTheBuild() {
        when(holeGeometryAssembler.assemble(COURSE_ID)).thenReturn(List.of());

        service.processBuildJob(job.getId());

        // This is the whole point. An empty package that reports COMPLETED
        // leaves nobody — not the job list, not the manifest, not the app — able
        // to tell a built course from an unbuilt one.
        assertThat(job.getStatus()).isEqualTo(PackageBuildStatus.FAILED);
        assertThat(job.getErrorCode()).isEqualTo("GEOMETRY_INCOMPLETE");
        verify(manifestRepository, never()).save(any());
    }

    @Test
    void aFailedBuildPublishesNothingToStorage() {
        when(holeGeometryAssembler.assemble(COURSE_ID)).thenReturn(List.of());

        service.processBuildJob(job.getId());

        verify(storageService, never()).uploadFile(any(), anyLong(), anyString(), any(), anyString());
    }

    // ─── The geometry ──────────────────────────────────────────────────────

    @Test
    void everyHoleIsUploadedAsItsOwnGeometryFile() {
        service.processBuildJob(job.getId());

        for (int hole = 1; hole <= 3; hole++) {
            verify(storageService).uploadFile(
                    any(), eq(COURSE_ID), anyString(),
                    eq(ObjectStorageService.ContentType.GEOMETRY),
                    eq("hole_" + hole + ".geojson"));
        }
    }

    @Test
    void theManifestRecordsGeometryFilesAtThePathStorageActuallyUses() {
        service.processBuildJob(job.getId());

        assertThat(persistedManifest().getFiles())
                .extracting(PackageFileEntry::getPath)
                // The client fetches {base}/packages/{course}/{version}/{path}
                // verbatim. A bare "hole_1.geojson" resolves one directory above
                // the file and 404s on every download.
                .contains("geometry/hole_1.geojson", "conditions/conditions.json");
    }

    @Test
    void aBuiltPackageHasBytesBehindIt() {
        service.processBuildJob(job.getId());

        // `hasDownloadablePackage` refuses to advertise Download for a manifest
        // with zero bytes, which is how the seeded placeholders were caught.
        assertThat(persistedManifest().getPackageSizeBytes()).isGreaterThan(0L);
        assertThat(job.getStatus()).isEqualTo(PackageBuildStatus.COMPLETED);
    }

    @Test
    void theAdvertisedGeometryUrlIsNotAFileThatWasNeverWritten() {
        service.processBuildJob(job.getId());

        // Geometry is one document per hole. The old value named a single
        // geometry.geojson that no stage has ever produced.
        assertThat(persistedManifest().getGeoJsonUrl()).doesNotContain("geometry.geojson");
    }

    // ─── Rebuilding ────────────────────────────────────────────────────────

    @Test
    void aRebuildLandsOnAVersionTheCourseDoesNotAlreadyHave() {
        CoursePackageManifest existing = org.mockito.Mockito.mock(CoursePackageManifest.class);
        when(manifestRepository.findByCourseIdOrderByVersionDesc(COURSE_ID))
                .thenReturn(List.of(existing));

        String version = service.computeManifestVersion(job);

        // Constant versions were the reason a course seeded with an empty
        // manifest could never be given a real one.
        assertThat(version).isEqualTo("1.8.2");
    }

    @Test
    void aVersionCollisionIsSteppedOverRatherThanReused() {
        when(manifestRepository.findByCourseIdAndVersion(COURSE_ID, "1.8.1"))
                .thenReturn(Optional.of(org.mockito.Mockito.mock(CoursePackageManifest.class)));

        assertThat(service.computeManifestVersion(job)).isEqualTo("1.8.2");
    }

    @Test
    void twoConsecutiveBuildsDoNotProduceTheSameVersion() {
        String first = service.computeManifestVersion(job);

        CoursePackageManifest published = org.mockito.Mockito.mock(CoursePackageManifest.class);
        when(manifestRepository.findByCourseIdOrderByVersionDesc(COURSE_ID))
                .thenReturn(List.of(published));

        assertThat(service.computeManifestVersion(job)).isNotEqualTo(first);
    }

    // ─── Inputs ────────────────────────────────────────────────────────────

    @Test
    void aBuildForACourseThatDoesNotExistFails() {
        when(courseRepository.existsById(COURSE_ID)).thenReturn(false);

        service.processBuildJob(job.getId());

        assertThat(job.getStatus()).isEqualTo(PackageBuildStatus.FAILED);
        verify(holeGeometryAssembler, never()).assemble(any());
    }
}
