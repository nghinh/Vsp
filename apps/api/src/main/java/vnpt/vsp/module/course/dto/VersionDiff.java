package vnpt.vsp.module.course.dto;

import java.util.ArrayList;
import java.util.List;

/**
 * Differences between a draft version and the latest published version.
 * Per Story 8.3 AC-2.
 */
public class VersionDiff {

    private Long draftVersionId;
    private Long publishedVersionId; // null if no published version
    private List<VersionDiffEntry> added = new ArrayList<>();
    private List<VersionDiffEntry> removed = new ArrayList<>();
    private List<VersionDiffEntry> changed = new ArrayList<>();

    public VersionDiff() {}

    public VersionDiff(Long draftVersionId, Long publishedVersionId) {
        this.draftVersionId = draftVersionId;
        this.publishedVersionId = publishedVersionId;
    }

    public Long getDraftVersionId() { return draftVersionId; }
    public void setDraftVersionId(Long draftVersionId) { this.draftVersionId = draftVersionId; }
    public Long getPublishedVersionId() { return publishedVersionId; }
    public void setPublishedVersionId(Long publishedVersionId) { this.publishedVersionId = publishedVersionId; }
    public List<VersionDiffEntry> getAdded() { return added; }
    public void setAdded(List<VersionDiffEntry> added) { this.added = added; }
    public List<VersionDiffEntry> getRemoved() { return removed; }
    public void setRemoved(List<VersionDiffEntry> removed) { this.removed = removed; }
    public List<VersionDiffEntry> getChanged() { return changed; }
    public void setChanged(List<VersionDiffEntry> changed) { this.changed = changed; }

    public void addAdded(VersionDiffEntry entry) { this.added.add(entry); }
    public void addRemoved(VersionDiffEntry entry) { this.removed.add(entry); }
    public void addChanged(VersionDiffEntry entry) { this.changed.add(entry); }
}
