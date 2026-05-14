// =====================================================
// Spirograph exercise
// =====================================================
// This file contains:
// 1. A gear module from the previous exercise
// 2. An animated spirograph visualization
// 3. A printable spirograph module
//
// The animation can show both:
// - hypotrochoids: inner gear rolls inside the outer gear
// - epitrochoids: inner gear rolls outside the outer gear
// =====================================================

$fn = 80;



// =====================================================
// Printable examples
// =====================================================
// Uncomment one of these lines to export printable models.

// Outer radius: 60 mm
// Inner radius: 40 mm
// Pen distances: 0, 10, 20, 30 mm
 
// linear_extrude(2)
//     spirograph(60, 40, [0, 10, 20, 30]);

// Outer radius: 50 mm
// Inner radius: 20 mm
// Pen distances: 0, 5, 10, 15 mm

// linear_extrude(2)
//     spirograph(50, 20, [0, 5, 10, 15]);



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
    // Normal gear with outside teeth
    // -------------------------------------------------
    if (inverse == false) {

        if (hole == true) {

            difference() {

                union() {

                    // Main circular body of the gear
                    circle(radius);

                    // Add teeth around the outside
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

                // Main circular body of the gear
                circle(radius);

                // Add teeth around the outside
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
    // Inverse gear with inside teeth
    // -------------------------------------------------
    // This is used as the outer fixed gear of the
    // printable spirograph.
    if (inverse == true) {

        union() {

            // Ring-shaped body
            difference() {
                circle(radius + 4 * tooth_height);
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
// Creates one tooth as a polygon.
// The gear module rotates this tooth around the gear.

module gear_tooth(radius, tooth_width, tooth_height, inverse) {

    // Tooth for a normal outside gear
    if (inverse == false) {

        polygon(points = [
            [radius - 0.3,          -tooth_width / 2],
            [radius + tooth_height, -0.7],
            [radius + tooth_height,  0.7],
            [radius - 0.3,           tooth_width / 2]
        ]);
    }


    // Tooth for an inverse inside gear
    if (inverse == true) {

        polygon(points = [
            [radius + tooth_height, -tooth_width / 2],
            [radius,                -0.7],
            [radius,                 0.7],
            [radius + tooth_height,  tooth_width / 2]
        ]);
    }
}



// =====================================================
// Animation settings
// =====================================================
// These values control the animated spirograph preview.

R = 60;          // radius of the fixed outer gear
r = 40;          // radius of the moving inner gear
d = 20;          // distance of the pen from the inner gear center

inside = true;   // true = hypotrochoid, false = epitrochoid

steps = 200;     // number of curve segments
line_width = 0.8;

// Current animation progress.
// $t is an OpenSCAD animation variable between 0 and 1.
current_step = floor($t * steps);



// =====================================================
// Animated spirograph preview
// =====================================================
// This line shows the animated model.
// Comment it out when you only want to export the
// printable spirograph.

spirograph_animated(R, r, d, inside);



// =====================================================
// Spirograph animation module
// =====================================================
// Visualizes:
// - the fixed outer gear
// - the moving inner gear
// - the pen position
// - the complete target curve
// - the partially drawn curve up to the current frame

module spirograph_animated(R, r, d, inside = true) {

    // Fixed outer gear, simplified as a ring
    color("black")
        ring(radius = R, thickness = 1.5);

    // Complete final drawing
    color("lightgray")
        draw_curve(
            R = R,
            r = r,
            d = d,
            inside = inside,
            n = steps
        );

    // Partial drawing up to current animation frame
    color("yellow")
        draw_curve(
            R = R,
            r = r,
            d = d,
            inside = inside,
            n = current_step
        );

    // Calculate current center position of the moving gear
    center_position = moving_gear_center(
        R = R,
        r = r,
        t = current_animation_angle(),
        inside = inside
    );

    // Moving gear, simplified as a ring
    color("teal")
        translate(center_position)
            ring(radius = r, thickness = 1.5);

    // Calculate current pen position
    pen_position = spirograph_point(
        R = R,
        r = r,
        d = d,
        t = current_animation_angle(),
        inside = inside
    );

    // Pen position
    color("red")
        translate(pen_position)
            circle(r = 2);
}



// =====================================================
// Current animation angle
// =====================================================
// The factor 3 makes the curve rotate several times
// during one full OpenSCAD animation cycle.

function current_animation_angle() =
    360 * 3 * $t;



// =====================================================
// Spirograph point function
// =====================================================
// Calculates one point on the drawn curve.
//
// For inside = true:
// The function creates a hypotrochoid.
//
// For inside = false:
// The function creates an epitrochoid.

function spirograph_point(R, r, d, t, inside = true) =
    inside
    ? [
        (R - r) * cos(t) + d * cos(((R - r) / r) * t),
        (R - r) * sin(t) - d * sin(((R - r) / r) * t)
      ]
    : [
        (R + r) * cos(t) - d * cos(((R + r) / r) * t),
        (R + r) * sin(t) - d * sin(((R + r) / r) * t)
      ];



// =====================================================
// Moving gear center function
// =====================================================
// Calculates the current center point of the moving gear.

function moving_gear_center(R, r, t, inside = true) =
    inside
    ? [
        (R - r) * cos(t),
        (R - r) * sin(t)
      ]
    : [
        (R + r) * cos(t),
        (R + r) * sin(t)
      ];



// =====================================================
// Draw curve module
// =====================================================
// Draws the curve by connecting many calculated points.
// Each small curve segment is created using hull() between
// two circles, which creates a smooth thick line.

module draw_curve(R, r, d, inside = true, n = 100) {

    for (i = [0 : n - 1]) {

        t1 = 360 * 3 * i / steps;
        t2 = 360 * 3 * (i + 1) / steps;

        p1 = spirograph_point(R, r, d, t1, inside);
        p2 = spirograph_point(R, r, d, t2, inside);

        hull() {
            translate(p1)
                circle(r = line_width);

            translate(p2)
                circle(r = line_width);
        }
    }
}



// =====================================================
// Ring helper module
// =====================================================
// Creates a simple 2D ring.
// This is used only for the animation visualization.

module ring(radius, thickness) {

    difference() {
        circle(r = radius);
        circle(r = radius - thickness);
    }
}



// =====================================================
// Printable spirograph module
// =====================================================
// Creates a printable spirograph using the gear module.
//
// Parameters:
// R = radius of the outer stationary inverse gear
// r = radius of the inner rotating gear
// d = list of pen distances from the center of the inner gear
//
// Example:
// spirograph(60, 40, [0, 10, 20, 30]);

module spirograph(R, r, d = []) {

    // Outer stationary gear with inward-facing teeth
    gear(radius = R, hole = false, inverse = true);

    // Inner rotating gear with pen holes
    difference() {

        // Inner normal gear
        gear(radius = r, hole = false, inverse = false);

        // Pen holes at the selected distances from center
        for (i = [0 : len(d) - 1]) {
            translate([d[i], 0, 0])
                circle(1);
        }
    }
}

// =====================================================
// Challenge: Approximation of a hypocycloid
// =====================================================
// A perfect hypocycloid needs the pen point to be exactly
// on the circumference of the rolling circle.
//
// In a real printed spirograph, the pen hole cannot be
// exactly on the outer edge because the gear needs material
// around the hole. Therefore, the pen distance is placed
// slightly outside/near the edge to get as close as possible.
//
// Inner gear radius: 20 mm
// Pen distance: 21.8 mm
// =====================================================

/*
linear_extrude(2)
    translate([25, 25, 1])
        hypocycloid_challenge_gear(
            radius = 20,
            pen_distances = [20 + 1.8]
        );

*/

// =====================================================
// Hypocycloid challenge gear
// =====================================================
// Creates only the inner rotating gear with a pen hole.
// The pen hole is placed close to the gear circumference
// to approximate a hypocycloid.

module hypocycloid_challenge_gear(radius, pen_distances = []) {

    difference() {

        // Inner normal gear
        gear(radius = radius, hole = false, inverse = false);

        // Pen holes at the selected distances from center
        for (i = [0 : len(pen_distances) - 1]) {
            translate([pen_distances[i], 0, 0])
                circle(1);
        }
    }
}