package vnpt.vsp.module.course.dto;

/**
 * One đường of a facility, as offered to a golfer setting up a round.
 *
 * <p>A club may hold several. Long Biên has đường A, B and C of nine holes
 * each and a round there is a pairing chosen on the day; Kings Island has
 * three full eighteens, each a round on its own. Both need the same answer to
 * the same question — what can I play here — so the course detail carries the
 * whole facility's list, the selected đường included.
 */
public class FacilityCourseDto {

    private Long courseId;
    private String name;
    private Integer holesCount;
    private Integer parTotal;

    public FacilityCourseDto() {}

    public FacilityCourseDto(Long courseId, String name, Integer holesCount, Integer parTotal) {
        this.courseId = courseId;
        this.name = name;
        this.holesCount = holesCount;
        this.parTotal = parTotal;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Integer getHolesCount() {
        return holesCount;
    }

    public void setHolesCount(Integer holesCount) {
        this.holesCount = holesCount;
    }

    public Integer getParTotal() {
        return parTotal;
    }

    public void setParTotal(Integer parTotal) {
        this.parTotal = parTotal;
    }
}
