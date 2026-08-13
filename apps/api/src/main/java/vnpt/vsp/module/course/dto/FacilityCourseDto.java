package vnpt.vsp.module.course.dto;

/**
 * One đường of a facility, as offered to a golfer setting up a round.
 *
 * <p>A club may hold several. Long Biên has đường A, B and C of nine holes
 * each and a round there is a pairing chosen on the day; Kings Island has
 * three full eighteens, each a round on its own. Both need the same answer to
 * the same question — what can I play here — so the course detail carries the
 * whole facility's list, the selected đường included.
 *
 * <p>The list is not filtered, and {@link #isPlayable()} is why. Two screens
 * read it and they want opposite things. Round setup wants only what can be
 * played: an đường with no hole rows has no pars, and offering it sends the
 * golfer to an empty scorecard. Scorecard submission wants all of them,
 * including — especially — the empty ones, because that screen is where a
 * golfer says which đường the card in their hand was printed for, and it is
 * the only way an đường ever stops being empty. Filtering here would leave the
 * two nines that need a card unable to receive one.
 */
public class FacilityCourseDto {

    private Long courseId;
    private String name;
    private Integer holesCount;
    private Integer parTotal;
    private boolean playable;

    public FacilityCourseDto() {}

    public FacilityCourseDto(
            Long courseId, String name, Integer holesCount, Integer parTotal, boolean playable) {
        this.courseId = courseId;
        this.name = name;
        this.holesCount = holesCount;
        this.parTotal = parTotal;
        this.playable = playable;
    }

    /**
     * Whether this đường has hole rows behind it — pars, and so a scorecard a
     * round can be scored against.
     *
     * <p>False means the club's structure is known and its card is not: the
     * name came from the club, the pars are waiting on a golfer to photograph
     * what is printed at the first tee.
     */
    public boolean isPlayable() {
        return playable;
    }

    public void setPlayable(boolean playable) {
        this.playable = playable;
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
