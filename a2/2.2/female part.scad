// connector_female.scad
// Female receiver part for the snap buckle connector.
// This part has:
// - a bag-style strap holder base
// - a rectangular receiver body
// - an internal cutout where the male part slides in
// - side openings for the male locking heads
// - a center guide rail that matches the slot in the male part

$fn = 60;


// ------------------------------------------------------------
// Main receiver body
// ------------------------------------------------------------

// Outer size of the female receiver body.
main_width = 32.6;     // X direction
main_height = 35.1;    // Y direction
main_depth = 7.1;      // Z direction


// ------------------------------------------------------------
// Internal receiver cutout
// ------------------------------------------------------------

// This cutout creates the internal space where the male part slides in.
cut_width = 30.6;      // X direction
cut_height = 35.1;     // Y direction
cut_depth = 5.1;       // Z direction


// ------------------------------------------------------------
// Center guide rail
// ------------------------------------------------------------

// This rail keeps the male connector moving straight.
// It matches the open slot in the male center guide.
line_width = 1.9;      // X direction
line_height = 29.9;    // Y direction
line_depth = 7.1;      // Z direction


// ------------------------------------------------------------
// Bag-style strap holder base
// ------------------------------------------------------------

// Base block behind the receiver body.
base_width = 32.6;     // X direction
base_height = 13;      // Y direction
base_depth = 7.1;      // Z direction

// Two strap slots are cut through the base.
strap_slot_width = 24;
strap_slot_height = 3.2;

// Solid material between the two strap slots.
strap_bar_height = 3;


// ------------------------------------------------------------
// Side locking openings
// ------------------------------------------------------------

// These holes allow the male locking heads to snap into place
// and also make it possible to press/release the connector.
side_hole_width = 5;       // X direction, how far the hole cuts into the side
side_hole_height = 9.8;   // Y direction
side_hole_depth = 5.2;     // Z direction


// ------------------------------------------------------------
// Final model
// ------------------------------------------------------------

union() {

    // --------------------------------------------------------
    // Strap holder base
    // --------------------------------------------------------

    difference() {

        // Solid base block behind the receiver
        translate([0, -base_height, 0])
            cube([
                base_width,
                base_height,
                base_depth
            ]);


        // First strap slot
        translate([
            (base_width - strap_slot_width) / 2,
            -base_height + 2,
            -0.1
        ])
            cube([
                strap_slot_width,
                strap_slot_height,
                base_depth + 0.2
            ]);


        // Second strap slot
        translate([
            (base_width - strap_slot_width) / 2,
            -base_height + 2 + strap_slot_height + strap_bar_height,
            -0.1
        ])
            cube([
                strap_slot_width,
                strap_slot_height,
                base_depth + 0.2
            ]);
    }


    // --------------------------------------------------------
    // Female receiver body
    // --------------------------------------------------------

    difference() {

        // Outer receiver block
        cube([
            main_width,
            main_height,
            main_depth
        ]);


        // Main internal cutout
        // This creates the tunnel for the male connector.
        translate([
            (main_width - cut_width) / 2,
            (main_height - cut_height) / 2,
            (main_depth - cut_depth) / 2
        ])
            cube([
                cut_width,
                cut_height,
                cut_depth + 0.1
            ]);


        // Left side locking opening
        // Starts at the entrance side of the receiver.
        translate([
            -0.1,
            0,
            (main_depth - side_hole_depth) / 2
        ])
            cube([
                side_hole_width + 0.1,
                side_hole_height,
                side_hole_depth
            ]);


        // Right side locking opening
        // Starts at the entrance side of the receiver.
        translate([
            main_width - side_hole_width,
            0,
            (main_depth - side_hole_depth) / 2
        ])
            cube([
                side_hole_width + 0.1,
                side_hole_height,
                side_hole_depth
            ]);
    }


    // --------------------------------------------------------
    // Center guide rail
    // --------------------------------------------------------

    // This rail fits into the slot of the male connector.
    translate([
        (main_width - line_width) / 2,
        0,
        0
    ])
        cube([
            line_width,
            line_height,
            line_depth
        ]);
}