package vnpt.vsp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * VSP API — Vietnam Smart Golf Platform modular monolith.
 */
@SpringBootApplication
@EntityScan(basePackages = "vnpt.vsp.module")
@EnableJpaRepositories(basePackages = "vnpt.vsp.module")
@EnableCaching
public class VspApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(VspApiApplication.class, args);
    }
}
