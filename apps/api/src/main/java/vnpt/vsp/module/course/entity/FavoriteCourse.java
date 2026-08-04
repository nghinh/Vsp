package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * User favorited course association.
 * Per Story 3.2 SD-BACK-1: supports AC-1 (search + favorites + recent).
 */
@Entity
@Table(name = "favorite_courses",
    uniqueConstraints = @UniqueConstraint(name = "uq_favorite_user_course",
        columnNames = {"user_id", "course_id"}))
@vnpt.vsp.module.course.CourseModule
public class FavoriteCourse {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
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

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }
}
