package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * User recently viewed course association.
 * Capped at 10 per user — enforced at repository layer.
 * Per Story 3.2 SD-BACK-1: supports AC-1 (search + favorites + recent).
 */
@Entity
@Table(name = "recent_courses",
    uniqueConstraints = @UniqueConstraint(name = "uq_recent_user_course",
        columnNames = {"user_id", "course_id"}))
@vnpt.vsp.module.course.CourseModule
public class RecentCourse {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Column(name = "viewed_at", nullable = false)
    private Instant viewedAt;

    @PrePersist
    protected void onCreate() {
        viewedAt = Instant.now();
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public Course getCourse() {
        return course;
    }

    public void setCourse(Course course) {
        this.course = course;
    }

    public Instant getViewedAt() {
        return viewedAt;
    }

    public void setViewedAt(Instant viewedAt) {
        this.viewedAt = viewedAt;
    }
}
