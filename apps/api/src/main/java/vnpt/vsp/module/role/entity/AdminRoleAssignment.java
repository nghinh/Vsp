package vnpt.vsp.module.role.entity;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * JPA entity representing an admin's assignment to a specific role.
 * Join table: AdminAccount → Role.
 * Per Story 2.5 AC-1: RBAC with 6 role types.
 */
@Entity
@Table(name = "admin_role_assignments",
        uniqueConstraints = @UniqueConstraint(columnNames = {"admin_account_id", "role_name"}))
@vnpt.vsp.module.role.RoleModule
public class AdminRoleAssignment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "admin_account_id", nullable = false)
    private AdminAccount adminAccount;

    @Enumerated(EnumType.STRING)
    @Column(name = "role_name", length = 50, nullable = false)
    private RoleName roleName;

    @Column(name = "assigned_at", nullable = false)
    private Instant assignedAt;

    @Column(name = "assigned_by")
    private Long assignedBy;  // AdminAccount ID of the assigner

    @PrePersist
    protected void onCreate() {
        if (assignedAt == null) {
            assignedAt = Instant.now();
        }
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public AdminAccount getAdminAccount() {
        return adminAccount;
    }

    public void setAdminAccount(AdminAccount adminAccount) {
        this.adminAccount = adminAccount;
    }

    public RoleName getRoleName() {
        return roleName;
    }

    public void setRoleName(RoleName roleName) {
        this.roleName = roleName;
    }

    public Instant getAssignedAt() {
        return assignedAt;
    }

    public void setAssignedAt(Instant assignedAt) {
        this.assignedAt = assignedAt;
    }

    public Long getAssignedBy() {
        return assignedBy;
    }

    public void setAssignedBy(Long assignedBy) {
        this.assignedBy = assignedBy;
    }
}
