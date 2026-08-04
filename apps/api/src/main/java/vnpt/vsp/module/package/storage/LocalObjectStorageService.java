package vnpt.vsp.module.pkg.storage;

import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;

@Service
public class LocalObjectStorageService implements ObjectStorageService {

    private final Path storageRoot = Path.of(System.getProperty("java.io.tmpdir"), "vsp-packages").toAbsolutePath().normalize();

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
