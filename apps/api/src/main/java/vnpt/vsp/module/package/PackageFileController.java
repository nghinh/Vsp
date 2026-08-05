package vnpt.vsp.module.pkg;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.HandlerMapping;

import jakarta.servlet.http.HttpServletRequest;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Serves course package files.
 *
 * Packages are written to object storage by the build pipeline. In environments
 * with a CDN in front, {@code vsp.packages.base-url} points at it and this
 * controller is unused. Where there is no CDN (local development), the API
 * serves the bytes itself so downloads actually work end to end instead of
 * pointing the app at a host that does not resolve.
 */
@RestController
@RequestMapping("/packages")
public class PackageFileController {

    private static final Logger log = LoggerFactory.getLogger(PackageFileController.class);

    private final Path storageRoot;

    public PackageFileController(
            @Value("${vsp.packages.storage-root:${java.io.tmpdir}/vsp-packages}") String storageRoot) {
        this.storageRoot = Path.of(storageRoot).toAbsolutePath().normalize();
    }

    /**
     * Stream one file out of a package, e.g.
     * {@code GET /packages/1/1.0.1/geometry/geometry.geojson}.
     *
     * @param courseId the course the package belongs to
     * @param version  the package (manifest) version
     * @param request  used to read the wildcard remainder of the path
     * @return 200 with the bytes, or 404 when the package or file is absent
     */
    @GetMapping("/{courseId}/{version}/**")
    public ResponseEntity<Resource> getPackageFile(
            @PathVariable Long courseId,
            @PathVariable String version,
            HttpServletRequest request) {

        String fullPath = (String) request.getAttribute(
                HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE);
        String prefix = "/packages/" + courseId + "/" + version + "/";
        if (fullPath == null || !fullPath.startsWith(prefix)) {
            return ResponseEntity.notFound().build();
        }
        String relative = fullPath.substring(prefix.length());

        Path target = storageRoot
                .resolve(String.valueOf(courseId))
                .resolve(version)
                .resolve(relative)
                .normalize();

        // Never serve outside the storage root: the remainder of the path comes
        // straight from the request, so `..` segments must not escape.
        if (!target.startsWith(storageRoot) || !Files.isRegularFile(target)) {
            return ResponseEntity.notFound().build();
        }

        MediaType contentType = MediaType.APPLICATION_OCTET_STREAM;
        try {
            String probed = Files.probeContentType(target);
            if (relative.endsWith(".geojson") || relative.endsWith(".json")) {
                contentType = MediaType.APPLICATION_JSON;
            } else if (probed != null) {
                contentType = MediaType.parseMediaType(probed);
            }
        } catch (IOException | IllegalArgumentException exception) {
            log.debug("Could not probe content type for {}", target, exception);
        }

        long size;
        try {
            size = Files.size(target);
        } catch (IOException exception) {
            log.warn("Package file unreadable: {}", target, exception);
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok()
                .contentType(contentType)
                .contentLength(size)
                .header(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable")
                .body(new FileSystemResource(target));
    }
}
