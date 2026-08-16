package vnpt.vsp.module.pkg.storage;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;

@Service
public class LocalObjectStorageService implements ObjectStorageService {

    /**
     * Where package files are written.
     *
     * <p>The same property {@code PackageFileController} reads them back
     * from. This class used to hard-code the temp directory while the
     * controller honoured configuration, so pointing the deployment at a
     * mounted volume moved the reader and left the writer behind: every
     * download 404'd on a file the manifest swore was there.
     *
     * <p>The default is still the temp directory, which is fine for a test
     * and wrong for a deployment — a path inside the container does not
     * survive the next {@code --build}, and the manifests in Postgres do.
     */
    private final Path storageRoot;

    public LocalObjectStorageService(
            @Value("${vsp.packages.storage-root:${java.io.tmpdir}/vsp-packages}")
            String storageRoot) {
        this.storageRoot = Path.of(storageRoot).toAbsolutePath().normalize();
    }

    @Override
    public String uploadFile(byte[] data, Long courseId, String manifestVersion,
                             ContentType contentType, String filename) {
        Path target = resolvePackagePath(courseId, manifestVersion)
                .resolve(contentType.name().toLowerCase())
                .resolve(filename)
                .normalize();
        requireWithinStorageRoot(target);
        try {
            Files.createDirectories(target.getParent());
            Files.write(target, data);
            return target.toUri().toString();
        } catch (IOException exception) {
            throw new UncheckedIOException("Unable to store package file", exception);
        }
    }

    @Override
    public void deletePackage(Long courseId, String manifestVersion) {
        Path packagePath = resolvePackagePath(courseId, manifestVersion);
        if (!Files.exists(packagePath)) {
            return;
        }
        try (var paths = Files.walk(packagePath)) {
            paths.sorted(Comparator.reverseOrder()).forEach(path -> {
                try {
                    Files.delete(path);
                } catch (IOException exception) {
                    throw new UncheckedIOException(exception);
                }
            });
        } catch (IOException exception) {
            throw new UncheckedIOException("Unable to delete package files", exception);
        }
    }

    private Path resolvePackagePath(Long courseId, String manifestVersion) {
        if (courseId == null || manifestVersion == null || manifestVersion.isBlank()) {
            throw new IllegalArgumentException("Course ID and manifest version are required");
        }
        Path path = storageRoot.resolve(courseId.toString()).resolve(manifestVersion).normalize();
        requireWithinStorageRoot(path);
        return path;
    }

    private void requireWithinStorageRoot(Path path) {
        if (!path.startsWith(storageRoot)) {
            throw new IllegalArgumentException("Invalid package storage path");
        }
    }
}
