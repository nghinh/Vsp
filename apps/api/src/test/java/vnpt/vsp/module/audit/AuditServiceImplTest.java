package vnpt.vsp.module.audit;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * What happens when an audit row cannot be written.
 *
 * <p>The write is {@code @Async} in its own transaction, so by the time it
 * fails the business operation has committed and answered. Abandoning a round
 * against a database whose {@code audit_entries_action_check} predated
 * ROUND_ABANDON therefore succeeded, told the golfer it succeeded, and left no
 * trace in a table retained seven years for compliance — the only evidence
 * being one log line among the DEBUG traffic.</p>
 *
 * <p>Not propagating is still right: there is no caller left to fail. Being
 * quiet about it is not, so these tests pin the failure counter that makes a
 * lost entry alertable.</p>
 */
@ExtendWith(MockitoExtension.class)
class AuditServiceImplTest {

    @Mock private EntityManager entityManager;

    private MeterRegistry meterRegistry;
    private AuditServiceImpl auditService;

    @BeforeEach
    void setUp() {
        meterRegistry = new SimpleMeterRegistry();
        auditService = new AuditServiceImpl(meterRegistry);
        ReflectionTestUtils.setField(auditService, "entityManager", entityManager);
    }

    private double failures(AuditAction action) {
        var counter = meterRegistry.find(AuditServiceImpl.WRITE_FAILURES_METRIC)
                .tag("action", action.name())
                .counter();
        return counter == null ? 0.0 : counter.count();
    }

    @Test
    @DisplayName("A successful write records no failure")
    void successfulWriteRecordsNoFailure() {
        auditService.log(AuditAction.ROUND_ABANDON, "round", "1", null, null, null);

        verify(entityManager).persist(any(AuditEntry.class));
        verify(entityManager).flush();
        assertEquals(0.0, failures(AuditAction.ROUND_ABANDON));
    }

    @Test
    @DisplayName("A rejected row is counted against the action that was lost")
    void rejectedRowIsCounted() {
        doThrow(new PersistenceException("violates check constraint \"audit_entries_action_check\""))
                .when(entityManager).flush();

        auditService.log(AuditAction.ROUND_ABANDON, "round", "1", null, null, null);

        assertEquals(1.0, failures(AuditAction.ROUND_ABANDON),
                "a lost audit entry must be visible in the metrics, not only in the logs");
        assertEquals(0.0, failures(AuditAction.ROUND_COMPLETE),
                "the counter must name the action that was lost");
    }

    @Test
    @DisplayName("A failed write does not propagate — the business operation has already committed")
    void failureDoesNotPropagate() {
        doThrow(new PersistenceException("database is down")).when(entityManager).flush();

        assertDoesNotThrow(() ->
                auditService.log(AuditAction.COURSE_PUBLISH, "course", "7", null, null, null));
    }
}
