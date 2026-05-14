// =====================================================
// Gear exercise
// =====================================================
// This file creates:
// 1. Two animated gears with different radii
// 2. A mounting plate for the gears
// 3. The self-evaluation example with inverse gear
// =====================================================

$fn = 100;


// =====================================================
// Animated gear pair
// =====================================================
// The two gears are placed so their teeth interleave.
// The smaller gear rotates faster because it has a smaller radius.

translate([8, 109, 0])
    rotate($t * 100 * 2.04)
        linear_extrude(2)
            gear(radius = 20, hole = true, inverse = false);

translate([71.8, 109, 0])
    rotate(-$t * 100)
        linear_extrude(2)
            gear(radius = 40, hole = true, inverse = false);


// =====================================================
// Mounting plate
// =====================================================
// The plate has two pins that fit into the center holes
// of the two printed gears.

translate([0, 160, 0])
    mounting_plate();



// =====================================================
// Self-evaluation example
// =====================================================
// This example shows:
// - one normal gear
// - one smaller normal gear
// - one inverse gear with teeth pointing inward

r1 = 50;
r2 = 20;

translate([100, 20])
    gear(radius = r1 - r2, hole = true, inverse = false);

translate([95, -35])
    gear(radius = r2, hole = false, inverse = false);

gear(radius = r1, hole = false, inverse = true);



// =====================================================
// Mounting plate module
// =====================================================
// Creates a rectangular base plate with two cylindrical
// mounting pins. The pin radius is slightly smaller than
// the gear hole radius to allow the gears to rotate.

module mounting_plate() {

    // Rectangular base plate
    cube([80, 17, 3]);

    // Left mounting pin
    translate([8, 9, 3])
        linear_extrude(10)
            circle(3.8);

    // Right mounting pin
    translate([71.8, 9, 3])
        linear_extrude(10)
            circle(3.8);
}



// =====================================================
// Gear module
// =====================================================
// Creates a 2D gear.
//
// Parameters:
// radius  = base radius of the gear
// hole    = true creates a center mounting hole
// inverse = false creates a normal gear with outside teeth
// inverse = true creates a ring gear with inside teeth

module gear(radius, hole = false, inverse = false) {

    tooth_height = 3;
    tooth_width = 6;

    // Number of teeth is calculated from the circumference
    teeth = floor(radius * PI * 2 / tooth_width);


    // -------------------------------------------------
    // Normal gear
    // -------------------------------------------------
    // A normal gear consists of a circle and teeth that
    // point outward.
    if (inverse == false) {

        if (hole == true) {

            difference() {

                union() {

                    // Main circular body
                    circle(radius);

                    // Add all teeth around the circle
                    for (i = [0 : teeth - 1]) {
                        rotate(i * 360 / teeth)
                            gear_tooth(
                                radius = radius,
                                tooth_width = tooth_width,
                                tooth_height = tooth_height,
                                inverse = inverse
                            );
                    }
                }

                // Center mounting hole
                circle(4);
            }
        }


        if (hole == false) {

            union() {

                // Main circular body
                circle(radius);

                // Add all teeth around the circle
                for (i = [0 : teeth - 1]) {
                    rotate(i * 360 / teeth)
                        gear_tooth(
                            radius = radius,
                            tooth_width = tooth_width,
                            tooth_height = tooth_height,
                            inverse = inverse
                        );
                }
            }
        }
    }


    // -------------------------------------------------
    // Inverse gear
    // -------------------------------------------------
    // An inverse gear is a ring with teeth pointing
    // towards the inside.
    if (inverse == true) {

        union() {

            // Outer ring body
            difference() {
                circle(radius + 2 * tooth_height);
                circle(radius + tooth_height);
            }

            // Add inward-facing teeth
            for (i = [0 : teeth - 1]) {
                rotate(i * 360 / teeth)
                    gear_tooth(
                        radius = radius,
                        tooth_width = tooth_width,
                        tooth_height = tooth_height,
                        inverse = inverse
                    );
            }
        }
    }
}



// =====================================================
// Gear tooth module
// =====================================================
// Creates one tooth of the gear.
// The tooth is drawn as a polygon and then rotated around
// the center by the gear module.

module gear_tooth(radius, tooth_width, tooth_height, inverse) {

    // -------------------------------------------------
    // Tooth for normal outside gear
    // -------------------------------------------------
    if (inverse == false) {

        polygon(points = [
            [radius - 0.3,          -tooth_width / 2],
            [radius + tooth_height, -0.7],
            [radius + tooth_height,  0.7],
            [radius - 0.3,           tooth_width / 2]
        ]);
    }


    // -------------------------------------------------
    // Tooth for inverse inside gear
    // -------------------------------------------------
    if (inverse == true) {

        polygon(points = [
            [radius + tooth_height, -tooth_width / 2],
            [radius,                -0.7],
            [radius,                 0.7],
            [radius + tooth_height,  tooth_width / 2]
        ]);
    }
}