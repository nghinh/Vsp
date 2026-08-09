package vnpt.vsp.contracts;

import org.junit.jupiter.api.DynamicTest;
import org.junit.jupiter.api.TestFactory;
import org.yaml.snakeyaml.Yaml;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Keeps packages/contracts/schemas honest about the DTOs it names.
 *
 * <p>Nothing generates code from those schemas — no OpenAPI generator is wired
 * anywhere in the build, and both clients are written by hand. That is exactly
 * why this test exists rather than why it does not. A contract that a compiler
 * checks cannot drift far; a contract that only people read can drift all the
 * way to describing a different API, and the drift is invisible because
 * everything still builds and every test still passes.</p>
 *
 * <p>It had drifted that far. {@code PublishRequest} in admin.yaml required
 * {@code courseId} and {@code version} in the body — both are path segments —
 * and never mentioned {@code publishNote}, which is mandatory and rejected
 * under ten characters. Anyone building a client from that text could not have
 * published a course, and the 400 they got back would have named a field the
 * document did not contain.</p>
 *
 * <p>Reflection, not parsing: an earlier pass at this compared the YAML against
 * the Java <em>source text</em> and reported fields like {@code "10"}, scraped
 * out of {@code @Size(min = 10)}. Reading the loaded class removes that whole
 * class of phantom.</p>
 */
class ContractSchemaMatchesDtoTest {

    /** The contract lives outside this module; Maven runs us from apps/api. */
    private static final Path SCHEMA_DIR =
            Path.of("..", "..", "packages", "contracts", "schemas");

    /**
     * Schema names that deliberately do not mirror a wire DTO.
     *
     * <p>Every entry needs a reason. An exemption is a claim that the mismatch
     * is intended, and a claim nobody wrote down is indistinguishable from a
     * bug someone gave up on.</p>
     */
    private static final Map<String, String> EXEMPT = Map.of(
            // Reserved for schemas that describe an aggregate or a view rather
            // than one serialised type. Empty on purpose: the list should stay
            // hard to add to.
    );

    /**
     * Where wire DTOs live. Anything outside these is an entity or an internal
     * type that happens to share a name, and comparing against it is noise.
     */
    private static boolean isWireDto(Class<?> c) {
        String pkg = c.getPackageName();
        String name = c.getSimpleName();
        boolean placed = pkg.contains(".dto") || pkg.endsWith(".dtos");
        boolean named = name.endsWith("Request") || name.endsWith("Response") || name.endsWith("Dto");
        return (placed || named)
                && !c.isInterface()
                && !c.isEnum()
                && !Modifier.isAbstract(c.getModifiers())
                && c.getEnclosingClass() == null;
    }

    @TestFactory
    Stream<DynamicTest> everySchemaNamingADtoDescribesThatDto() {
        Map<String, List<Class<?>>> dtos = scanWireDtos();
        assertThat(dtos)
                .as("no DTOs found — the scan is broken, and an empty scan would pass everything")
                .isNotEmpty();

        List<DynamicTest> tests = new ArrayList<>();
        for (Path file : schemaFiles()) {
            Map<String, Set<String>> schemas = schemaProperties(file);
            for (var entry : schemas.entrySet()) {
                String name = entry.getKey();
                List<Class<?>> candidates = dtos.get(name);
                if (candidates == null || EXEMPT.containsKey(name)) continue;

                Set<String> documented = entry.getValue();
                String label = file.getFileName() + " » " + name;

                tests.add(DynamicTest.dynamicTest(label, () -> {
                    // A simple name can belong to more than one DTO — the repo
                    // has two GolferProfileResponse, in identity and profile.
                    // Matching any of them is the honest bar; picking one by
                    // scan order would fail the schema for not resembling a
                    // class it was never about.
                    for (Class<?> candidate : candidates) {
                        if (propertiesOf(candidate).equals(documented)) return;
                    }

                    Class<?> best = candidates.get(0);
                    int bestOverlap = -1;
                    for (Class<?> c : candidates) {
                        Set<String> p = new TreeSet<>(propertiesOf(c));
                        p.retainAll(documented);
                        if (p.size() > bestOverlap) { bestOverlap = p.size(); best = c; }
                    }
                    Set<String> actual = propertiesOf(best);

                    Set<String> invented = new TreeSet<>(documented);
                    invented.removeAll(actual);
                    Set<String> undocumented = new TreeSet<>(actual);
                    undocumented.removeAll(documented);

                    assertThat(invented)
                            .as("%s documents fields %s does not have", label, best.getName())
                            .isEmpty();
                    assertThat(undocumented)
                            .as("%s omits fields %s actually carries", label, best.getName())
                            .isEmpty();
                }));
            }
        }

        assertThat(tests)
                .as("no schema matched any DTO by name — the comparison found nothing to do")
                .isNotEmpty();
        return tests.stream();
    }

    // ─── Reading the contract ───────────────────────────────────────────────

    private static List<Path> schemaFiles() {
        if (!Files.isDirectory(SCHEMA_DIR)) {
            throw new IllegalStateException(
                    "Contract schemas not found at " + SCHEMA_DIR.toAbsolutePath()
                            + " — this check is repo-relative; move the path if the layout moved.");
        }
        List<Path> files = new ArrayList<>();
        try (var s = Files.list(SCHEMA_DIR)) {
            s.filter(p -> p.toString().endsWith(".yaml") || p.toString().endsWith(".yml"))
                    .sorted()
                    .forEach(files::add);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        // openapi.yaml keeps its own components/schemas, a third home for names
        // that also live in admin.yaml and course.yaml. Leaving it out would
        // have meant checking two copies of PublishRequest and not the one an
        // OpenAPI reader actually lands on.
        Path openapi = SCHEMA_DIR.getParent().resolve("openapi.yaml");
        if (Files.isRegularFile(openapi)) files.add(openapi);
        return files;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Set<String>> schemaProperties(Path file) {
        Object loaded;
        try {
            loaded = new Yaml().load(Files.readString(file));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        Map<String, Set<String>> out = new HashMap<>();
        if (!(loaded instanceof Map<?, ?> root)) return out;

        // An OpenAPI document keeps its definitions one level down.
        if (root.get("components") instanceof Map<?, ?> components
                && components.get("schemas") instanceof Map<?, ?> nested) {
            root = nested;
        }

        for (var e : root.entrySet()) {
            if (!(e.getKey() instanceof String name)) continue;
            if (!(e.getValue() instanceof Map<?, ?> body)) continue;
            if (!(body.get("properties") instanceof Map<?, ?> props)) continue;
            Set<String> names = new LinkedHashSet<>();
            for (Object k : props.keySet()) if (k instanceof String s) names.add(s);
            if (!names.isEmpty()) out.put(name, names);
        }
        return out;
    }

    // ─── Reading the code ───────────────────────────────────────────────────

    private static Map<String, List<Class<?>>> scanWireDtos() {
        Map<String, List<Class<?>>> found = new HashMap<>();
        Path root = Path.of("src", "main", "java");
        try (var s = Files.walk(root)) {
            s.filter(p -> p.toString().endsWith(".java")).forEach(p -> {
                String fqn = root.relativize(p).toString()
                        .replace(".java", "")
                        .replace(java.io.File.separatorChar, '.');
                try {
                    Class<?> c = Class.forName(fqn, false, ContractSchemaMatchesDtoTest.class.getClassLoader());
                    if (isWireDto(c)) {
                        found.computeIfAbsent(c.getSimpleName(), k -> new ArrayList<>()).add(c);
                    }
                } catch (Throwable ignored) {
                    // Not every file is a loadable top-level class of that name.
                }
            });
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return found;
    }

    /**
     * The data a DTO carries.
     *
     * <p>Declared state, not accessors. Reading getters instead looked obvious
     * and was wrong: {@code CourseSearchRequest} answers {@code isNearbyOnly()},
     * {@code isTextOnly()} and {@code isCombined()} by inspecting the fields it
     * already has, and this test duly demanded the contract document three
     * things that never cross the wire as input. Fields cannot lie that way.</p>
     *
     * <p>The trade is that a class exposing data only through computed getters
     * goes unchecked. That is the safer direction to fail: a missed mismatch
     * costs a stale line of documentation, whereas a false one costs the next
     * person their afternoon and teaches them to distrust the check.</p>
     */
    private static Set<String> propertiesOf(Class<?> c) {
        Set<String> names = new LinkedHashSet<>();
        if (c.isRecord()) {
            for (var rc : c.getRecordComponents()) names.add(rc.getName());
            return names;
        }
        for (Field f : c.getDeclaredFields()) {
            if (Modifier.isStatic(f.getModifiers()) || f.isSynthetic()) continue;
            names.add(f.getName());
        }
        if (names.isEmpty()) {
            for (Method m : c.getMethods()) {
                if (m.getDeclaringClass() == Object.class || m.getParameterCount() != 0) continue;
                String n = m.getName();
                if (n.startsWith("get") && n.length() > 3) names.add(decap(n.substring(3)));
                else if (n.startsWith("is") && n.length() > 2 && m.getReturnType() == boolean.class) {
                    names.add(decap(n.substring(2)));
                }
            }
        }
        return names;
    }

    private static String decap(String s) {
        if (s.length() > 1 && Character.isUpperCase(s.charAt(1))) return s;
        return s.substring(0, 1).toLowerCase(Locale.ROOT) + s.substring(1);
    }
}
