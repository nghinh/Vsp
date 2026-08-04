package vnpt.vsp.module.course.dto;

/**
 * Request DTO for updating a tee set (partial update).
 * Per Story 8.1 AC-2: all fields optional for PATCH semantics.
 */
public class TeeSetUpdateRequest {

    private String name;
    private Integer totalPar;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Integer getTotalPar() { return totalPar; }
    public void setTotalPar(Integer totalPar) { this.totalPar = totalPar; }
}
