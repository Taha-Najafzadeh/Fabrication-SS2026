// Increase the resolution of cylinders/circles
$fn = 60;


// =====================================================
// Groundplate
// =====================================================
// This thin base plate is used so elephant foot affects
// the groundplate instead of the actual test parts.
cube([60, 100, 1]);

// Place all test models on top of the groundplate
translate([0, 2, 1])
    complete_tolerance_test();



// =====================================================
// Final combined print
// =====================================================
// This module combines all separate tests into one model.
module complete_tolerance_test() {

    // Test 1: wall clearance tolerance
    translate([5, 0, 0])
        wall_clearance_test();

    // Test 2a: rectangular hole accuracy
    translate([20, 0, 0])
        rectangular_hole_test();

    // Test 2b: circular hole accuracy
    translate([10, 32, 0])
        circular_hole_test();

    // Test 3: small circular wall / diameter test
    translate([56, 0, 0])
        rotate(90)
            circular_wall_test();

    // Test 4: overhang angle test
    translate([5, 48, 0])
        overhang_test();

    // Test 5: bridge length test
    translate([50, 65, 0])
        rotate(90)
            bridge_test();
}



// =====================================================
// Test 1: Wall clearance tolerance
// =====================================================
// This test checks how small the distance between two
// walls can be before the printer melts them together.
//
// Tested gaps:
// 0.25 mm, 0.30 mm, 0.35 mm, 0.40 mm, 0.45 mm
module wall_clearance_test() {

    difference() {

        // Main test block
        cube([10, 20, 1]);

        // Clearance slots with different widths
        translate([5, 18, 0])
            cube([5, 0.45, 5]);

        translate([5, 14, 0])
            cube([10, 0.40, 5]);

        translate([5, 10, 0])
            cube([10, 0.35, 5]);

        translate([5, 6, 0])
            cube([10, 0.30, 5]);

        translate([5, 2, 0])
            cube([10, 0.25, 5]);
    }
}



// =====================================================
// Test 2a: Rectangular hole accuracy
// =====================================================
// This test checks how accurately rectangular holes are
// printed compared to their intended dimensions.
//
// Tested hole sizes:
// [2 mm, 20 mm], [3.5 mm, 20 mm], [5 mm, 20 mm]
module rectangular_hole_test() {

    difference() {

        // Base for the rectangular hole test
        cube([23, 28, 1]);

        // Rectangular hole: 2 mm x 20 mm
        translate([3, 4, -1])
            cube([2, 20, 3]);

        // Rectangular hole: 3.5 mm x 20 mm
        translate([8, 4, -1])
            cube([3.5, 20, 3]);

        // Rectangular hole: 5 mm x 20 mm
        translate([14.5, 4, -1])
            cube([5, 20, 3]);
    }
}



// =====================================================
// Test 2b: Circular hole accuracy
// =====================================================
// This test checks how accurately circular holes are
// printed compared to their intended radius.
//
// Tested radii:
// 2 mm, 3 mm, 4 mm
module circular_hole_test() {

    difference() {

        // Base for the circular hole test
        cube([24, 11, 1]);

        // Circular hole with radius 2 mm
        translate([3, 6, -1])
            cylinder(h = 3, r = 2);

        // Circular hole with radius 3 mm
        translate([10, 6, -1])
            cylinder(h = 3, r = 3);

        // Circular hole with radius 4 mm
        translate([19, 6, -1])
            cylinder(h = 3, r = 4);
    }
}



// =====================================================
// Test 3: Circular wall / diameter test
// =====================================================
// This test checks how small circular walls can be printed.
// Each circle has a wall thickness of 1 mm.
//
// Tested inner radii:
// 0.25 mm, 0.5 mm, 0.75 mm, 1 mm, 2.25 mm, 3.5 mm
wall_thickness = 1;
test_radii = [0.25, 0.5, 0.75, 1, 2.25, 3.5];

module circular_wall_test() {

    // Base for the circular wall test
    cube([60, 10, 1]);

    // Generate one circular wall for each tested radius
    for (i = [0 : len(test_radii) - 1]) {

        x_position = 4 + i * 10;

        translate([x_position, 5, 1])
            ring_wall(test_radii[i]);
    }
}



// Creates one circular wall with a given inner radius
module ring_wall(inner_radius) {

    difference() {

        // Outer cylinder
        cylinder(
            h = 4,
            r = inner_radius + wall_thickness
        );

        // Inner cutout
        translate([0, 0, -1])
            cylinder(
                h = 6,
                r = inner_radius
            );
    }
}



// =====================================================
// Test 4: Overhang angle test
// =====================================================
// This test checks which overhang angle can still be
// printed without support structures.
//
// The wall starts vertical and then increases the angle
// by 10 degrees per step.
module overhang_test() {

    // Base for the overhang test
    cube([30, 10, 1]);

    // Vertical starting wall
    translate([0, 0, 1])
        cube([5, 10, 10]);

    // Overhang steps from 10° to 80°
    translate([0, 0, 11])
        rotate([0, 10, 0])
            cube([5, 10, 5]);

    translate([0.8, 0, 15.7])
        rotate([0, 20, 0])
            cube([5, 10, 5]);

    translate([2.3, 0, 19.9])
        rotate([0, 30, 0])
            cube([5, 10, 5]);

    translate([4.55, 0, 23.9])
        rotate([0, 40, 0])
            cube([5, 10, 5]);

    translate([7.6, 0, 27.58])
        rotate([0, 50, 0])
            cube([5, 10, 5]);

    translate([11.4, 0, 30.8])
        rotate([0, 60, 0])
            cube([5, 10, 5]);

    translate([15.7, 0, 33.3])
        rotate([0, 70, 0])
            cube([5, 10, 5]);

    translate([20.3, 0, 35])
        rotate([0, 80, 0])
            cube([5, 10, 5]);
}



// =====================================================
// Test 5: Bridge length test
// =====================================================
// This test checks how long a bridge can be printed
// before the print becomes inaccurate or starts sagging.
//
// Bridge width: 2 mm
// Bridge height: 2 mm
//
// Tested bridge lengths:
// 2.5 mm, 5 mm, 10 mm, 15 mm, 20 mm, 25 mm
module bridge_test() {

    bridge_lengths = [2.5, 5, 10, 15, 20, 25];
    bridge_width = 2;
    bridge_height = 2;

    // Base for the bridge test
    cube([33, 42, 1]);

    // Generate bridges with different lengths
    for (i = [0 : len(bridge_lengths) - 1]) {

        translate([0, i * 7 + 2, 1])
            bridge_structure(
                bridge_lengths[i],
                bridge_height,
                bridge_width
            );
    }
}



// Creates one bridge with two pillars and a horizontal span
module bridge_structure(length, height, width) {

    // Left support pillar
    cube([width, width, height]);

    // Horizontal bridge part
    translate([0, 0, height])
        cube([length + (2 * width), width, 2]);

    // Right support pillar
    translate([length + width, 0, 0])
        cube([width, width, height]);
}