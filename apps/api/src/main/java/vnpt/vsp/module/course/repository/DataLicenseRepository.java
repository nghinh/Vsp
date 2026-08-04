package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.DataLicense;

import java.util.List;

@Repository("courseDataLicenseRepository")
public interface DataLicenseRepository extends JpaRepository<DataLicense, Long> {

    List<DataLicense> findByDataVersionId(Long dataVersionId);
}
