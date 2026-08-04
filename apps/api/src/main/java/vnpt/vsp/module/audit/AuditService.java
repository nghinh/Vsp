package vnpt.vsp.module.audit;

/**
 * Audit module public service interface.
 * Exposes audit logging and version history operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 */
public interface AuditService {

    /**
     * Writes an append-only audit entry for the given mutation.
     * <p>
     * The entry is written to the {@code audit_entries} table and also emitted
     * as a structured log with the request correlation ID from MDC, satisfying
     * the tracing requirement in §13 Observability Architecture.
     * <p>
     * This method is non-blocking: the write is performed asynchronously via an
     * internal thread pool so it never increases request latency.
     *
     * @param action      the type of auditable action (must not be null)
     * @param objectType  the type of entity being mutated (e.g. "Course", "Pin")
     * @param objectId    the identifier of the mutated entity (may be null)
     * @param beforeJson JSON snapshot of the entity <em>before</em> the mutation
     *                    (nullable; omit if not meaningful)
     * @param afterJson  JSON snapshot of the entity <em>after</em> the mutation
     *                   (nullable; omit if not meaningful)
     * @param metadataJson extra context as JSON: IP address, user-agent, reason, etc.
     *                     (nullable)
     */
    void log(AuditAction action,
             String objectType,
             String objectId,
             String beforeJson,
             String afterJson,
             String metadataJson);
}
