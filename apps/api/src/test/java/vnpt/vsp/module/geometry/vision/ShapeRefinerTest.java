package vnpt.vsp.module.geometry.vision;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Taking a shape's edge from the picture rather than from the model.
 *
 * <p>The pictures here are synthetic on purpose: a known blob in a known
 * place, so "did the refined outline land on it" is a question with an
 * answer. Satellite imagery would make this a test of the weather.
 */
class ShapeRefinerTest {

    /// A dark ellipse on grass — a pond, near enough for the flood.
    private static BufferedImage pondImage() {
        var image = new BufferedImage(400, 400, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = image.createGraphics();
        g.setColor(new Color(70, 120, 60));      // grass
        g.fillRect(0, 0, 400, 400);
        g.setColor(new Color(20, 40, 70));       // water
        g.fillOval(120, 160, 160, 80);           // wide, not round
        g.dispose();
        return image;
    }

    /// The model's guess: a circle of about the right size, in about the
    /// right place, and the wrong shape — which is what they all look like.
    private static List<double[]> seedOver(double cx, double cy, double r) {
        var ring = new java.util.ArrayList<double[]>();
        for (int i = 0; i < 8; i++) {
            double a = 2 * Math.PI * i / 8;
            ring.add(new double[]{cx + Math.cos(a) * r, cy + Math.sin(a) * r});
        }
        ring.add(new double[]{ring.get(0)[0], ring.get(0)[1]});
        return ring;
    }

    @Test
    @DisplayName("the refined outline follows the pond, not the guess")
    void followsThePixels() {
        var image = pondImage();
        // Pond spans x 120–280, y 160–240 of 400. Seed is a circle over it.
        var seed = seedOver(0.5, 0.5, 0.12);

        var refined = ShapeRefiner.refine(image, seed);

        assertThat(refined).isNotNull();
        double minX = refined.stream().mapToDouble(p -> p[0]).min().orElseThrow();
        double maxX = refined.stream().mapToDouble(p -> p[0]).max().orElseThrow();
        double minY = refined.stream().mapToDouble(p -> p[1]).min().orElseThrow();
        double maxY = refined.stream().mapToDouble(p -> p[1]).max().orElseThrow();

        // It found the ellipse's own extent: wide and flat, which the round
        // seed was not.
        assertThat(minX).isBetween(0.28, 0.32);
        assertThat(maxX).isBetween(0.68, 0.72);
        assertThat(minY).isBetween(0.38, 0.42);
        assertThat(maxY).isBetween(0.58, 0.62);
        assertThat(maxX - minX).isGreaterThan((maxY - minY) * 1.5);
    }

    @Test
    @DisplayName("a seed on plain grass refines to nothing and keeps the guess")
    void keepsTheSeedWhereThereIsNothingToFind() {
        var image = pondImage();
        // Far from the pond: the flood fills grass until it hits its bound,
        // which is the "escaped" case.
        var refined = ShapeRefiner.refine(image, seedOver(0.15, 0.85, 0.05));

        assertThat(refined).isNull();
    }

    @Test
    @DisplayName("a seed too small to be anything is refused")
    void refusesATinySeed() {
        assertThat(ShapeRefiner.refine(pondImage(), seedOver(0.5, 0.5, 0.001)))
                .isNull();
    }

    @Test
    @DisplayName("a ring that is not a ring is refused")
    void refusesRubbish() {
        assertThat(ShapeRefiner.refine(pondImage(), List.of())).isNull();
        assertThat(ShapeRefiner.refine(null, seedOver(0.5, 0.5, 0.1))).isNull();
    }

    /// A bunker beside a pond must not flood into it, and vice versa.
    @Test
    @DisplayName("the flood stops at the feature's own colour")
    void staysWithinOneFeature() {
        var image = new BufferedImage(400, 400, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = image.createGraphics();
        g.setColor(new Color(70, 120, 60));
        g.fillRect(0, 0, 400, 400);
        g.setColor(new Color(214, 198, 160));    // sand
        g.fillOval(100, 180, 60, 40);
        g.setColor(new Color(20, 40, 70));       // water, right beside it
        g.fillOval(170, 180, 90, 40);
        g.dispose();

        var refined = ShapeRefiner.refine(image, seedOver(0.325, 0.5, 0.06));

        assertThat(refined).isNotNull();
        double maxX = refined.stream().mapToDouble(p -> p[0]).max().orElseThrow();
        // The sand ends at x=160/400 = 0.40. The water beyond it is not sand.
        assertThat(maxX).isLessThan(0.45);
    }

    @Test
    @DisplayName("the outline closes")
    void closesTheRing() {
        var refined = ShapeRefiner.refine(pondImage(), seedOver(0.5, 0.5, 0.12));

        assertThat(refined.get(0)).isEqualTo(refined.get(refined.size() - 1));
        assertThat(refined.size()).isGreaterThan(20);
    }
}
