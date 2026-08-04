package vnpt.vsp.module.course.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request DTO for creating a new tee set.
 * Per Story 8.1 AC-2: validation prevents incomplete required data from publication.
 */
public class TeeSetCreateRequest {

    @NotBlank(message = "name is required")
    private String name;

    private Integer totalPar;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Integer getTotalPar() { return totalPar; }
    public void setTotalPar(Integer totalPar) { this.totalPar = totalPar; }
}
