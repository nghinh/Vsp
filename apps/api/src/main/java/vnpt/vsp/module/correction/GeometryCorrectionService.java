package vnpt.vsp.module.correction;

import vnpt.vsp.module.correction.dto.GeometryCorrectionRequest;
import vnpt.vsp.module.correction.dto.GeometryCorrectionResponse;

/**
 * Golfer-facing half of the correction workflow: reporting that a hole's
 * geometry is wrong, from inside the app, while standing on the course.
 *
 * <p>The admin-facing half — queue, review, resolution — lives on
 * {@link CorrectionService}. Both persist into {@code course_corrections}.</p>
 */
public interface GeometryCorrectionService {

    /**
     * Records a golfer's geometry correction and folds it into any existing
     * cluster of matching reports.
     *
     * <p>The row is stored as unverified community data (accuracy class D) and
     * stays that way until enough independent reports agree. Nothing here can
     * mark data VERIFIED — corroboration only raises a cluster to
     * PENDING_REVIEW so a human sees it.</p>
     *
     * @param courseId   course the hole belongs to
     * @param reporterId authenticated golfer's account ID
     * @param request    layer, proposed shape, GPS accuracy and optional note
     * @return the stored correction plus its corroboration outcome
     */
    GeometryCorrectionResponse submitGeometryCorrection(Long courseId,
                                                        Long reporterId,
                                                        GeometryCorrectionRequest request);
}
