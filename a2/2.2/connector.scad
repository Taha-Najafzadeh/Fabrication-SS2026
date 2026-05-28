// connector_combined.scad
// Combined snap buckle connector.
// Includes:
// - male connector with side arms and half-circle locking heads
// - female receiver with strap holder, center rail, and side locking holes

$fn = 60;


// ============================================================
// Preview layout
// ============================================================

preview_gap = 25;


// ============================================================
// Shared helper module
// ============================================================

module rounded_box(size=[10,10,4], r=1) {
    hull() {
        translate([r, r, 0])
            cylinder(h=size[2], r=r);

        translate([size[0]-r, r, 0])
            cylinder(h=size[2], r=r);

        translate([r, size[1]-r, 0])
            cylinder(h=size[2], r=r);

        translate([size[0]-r, size[1]-r, 0])
            cylinder(h=size[2], r=r);
    }
}


// ============================================================
// Male connector parameters
// ============================================================

male_thickness = 5;

male_base_width  = 30;
male_base_depth  = 8;


// ------------------------------------------------------------
// Male strap holder base
// ------------------------------------------------------------

male_strap_base_width = 30;
male_strap_base_height = 13;
male_strap_base_depth = 5;

male_strap_slot_width = 22;
male_strap_slot_height = 3.2;
male_strap_bar_height = 3;


// ------------------------------------------------------------
// Male side arms
// ------------------------------------------------------------

male_arm_width = 5;
male_arm_total_length = 34;


// ------------------------------------------------------------
// Male half-circle locking heads
// ------------------------------------------------------------

male_head_length = 6;
male_head_height = 8;

male_arm_body_length = male_arm_total_length - male_head_height;

male_head_overlap = 1.0;


// ------------------------------------------------------------
// Male center guide
// ------------------------------------------------------------

male_center_width = 8;
male_center_length = 35;

male_slot_width = 2;
male_slot_margin_bottom = 5;


// ------------------------------------------------------------
// Male general settings
// ------------------------------------------------------------

male_arm_overlap_into_base = 1.5;
male_rounding = 1.2;


// ============================================================
// Male locking head modules
// ============================================================

module left_half_circle_head_2d(length, height) {
    union() {
        // Flat part
        translate([-length, -height / 2])
            square([length, height]);

        // Rounded outside end
        translate([-length, 0])
            circle(d = height);
    }
}


module right_half_circle_head_2d(length, height) {
    union() {
        // Flat part
        translate([0, -height / 2])
            square([length, height]);

        // Rounded outside end
        translate([length, 0])
            circle(d = height);
    }
}


module left_half_circle_head(length, height, thickness) {
    linear_extrude(height = thickness)
        left_half_circle_head_2d(length, height);
}


module right_half_circle_head(length, height, thickness) {
    linear_extrude(height = thickness)
        right_half_circle_head_2d(length, height);
}


// ============================================================
// Male connector
// ============================================================

module male_connector() {

    difference() {

        union() {

            // Bag-style strap holder base
            difference() {
                translate([-male_strap_base_width / 2, -male_strap_base_height, 0])
                    rounded_box(
                        [
                            male_strap_base_width,
                            male_strap_base_height,
                            male_strap_base_depth
                        ],
                        r = male_rounding
                    );

                // First strap slot
                translate([
                    -male_strap_slot_width / 2,
                    -male_strap_base_height + 2,
                    -0.1
                ])
                    cube([
                        male_strap_slot_width,
                        male_strap_slot_height,
                        male_strap_base_depth + 0.2
                    ]);

                // Second strap slot
                translate([
                    -male_strap_slot_width / 2,
                    -male_strap_base_height + 2 + male_strap_slot_height + male_strap_bar_height,
                    -0.1
                ])
                    cube([
                        male_strap_slot_width,
                        male_strap_slot_height,
                        male_strap_base_depth + 0.2
                    ]);
            }


            // Front base bridge
            translate([-male_base_width / 2, 0, 0])
                rounded_box(
                    [
                        male_base_width,
                        male_base_depth,
                        male_thickness
                    ],
                    r = male_rounding
                );


            // Left flexible arm
            translate([
                -male_base_width / 2,
                male_base_depth - male_arm_overlap_into_base,
                0
            ])
                cube([
                    male_arm_width,
                    male_arm_body_length + male_arm_overlap_into_base,
                    male_thickness
                ]);


            // Right flexible arm
            translate([
                male_base_width / 2 - male_arm_width,
                male_base_depth - male_arm_overlap_into_base,
                0
            ])
                cube([
                    male_arm_width,
                    male_arm_body_length + male_arm_overlap_into_base,
                    male_thickness
                ]);


            // Left half-circle locking head
            translate([
                -male_base_width / 2 + male_arm_width,
                male_base_depth + male_arm_body_length - male_head_overlap + male_head_height / 2,
                0
            ])
                left_half_circle_head(
                    male_head_length,
                    male_head_height,
                    male_thickness
                );


            // Right half-circle locking head
            translate([
                male_base_width / 2 - male_arm_width,
                male_base_depth + male_arm_body_length - male_head_overlap + male_head_height / 2,
                0
            ])
                right_half_circle_head(
                    male_head_length,
                    male_head_height,
                    male_thickness
                );


            // Center guide
            translate([
                -male_center_width / 2,
                male_base_depth - male_arm_overlap_into_base,
                0
            ])
                rounded_box(
                    [
                        male_center_width,
                        male_center_length + male_arm_overlap_into_base,
                        male_thickness
                    ],
                    r = 1
                );
        }


        // Open-top straight slot in center guide
        translate([
            -male_slot_width / 2,
            male_base_depth + male_slot_margin_bottom,
            -0.1
        ])
            cube([
                male_slot_width,
                male_center_length + 5,
                male_thickness + 0.2
            ]);
    }
}


// ============================================================
// Female connector parameters
// ============================================================

female_main_width = 32.6;
female_main_height = 35.1;
female_main_depth = 7.1;


// ------------------------------------------------------------
// Female internal receiver cutout
// ------------------------------------------------------------

female_cut_width = 30.6;
female_cut_height = 35.1;
female_cut_depth = 5.1;


// ------------------------------------------------------------
// Female center guide rail
// ------------------------------------------------------------

female_line_width = 1.9;
female_line_height = 29.9;
female_line_depth = 7.1;


// ------------------------------------------------------------
// Female strap holder base
// ------------------------------------------------------------

female_base_width = 32.6;
female_base_height = 13;
female_base_depth = 7.1;

female_strap_slot_width = 24;
female_strap_slot_height = 3.2;
female_strap_bar_height = 3;


// ------------------------------------------------------------
// Female side locking openings
// ------------------------------------------------------------

female_side_hole_width = 5;
female_side_hole_height = 9.8;
female_side_hole_depth = 5.2;


// ============================================================
// Female connector
// ============================================================

module female_connector() {

    union() {

        // ----------------------------------------------------
        // Strap holder base
        // ----------------------------------------------------

        difference() {

            // Solid base block behind the receiver
            translate([0, -female_base_height, 0])
                cube([
                    female_base_width,
                    female_base_height,
                    female_base_depth
                ]);


            // First strap slot
            translate([
                (female_base_width - female_strap_slot_width) / 2,
                -female_base_height + 2,
                -0.1
            ])
                cube([
                    female_strap_slot_width,
                    female_strap_slot_height,
                    female_base_depth + 0.2
                ]);


            // Second strap slot
            translate([
                (female_base_width - female_strap_slot_width) / 2,
                -female_base_height + 2 + female_strap_slot_height + female_strap_bar_height,
                -0.1
            ])
                cube([
                    female_strap_slot_width,
                    female_strap_slot_height,
                    female_base_depth + 0.2
                ]);
        }


        // ----------------------------------------------------
        // Female receiver body
        // ----------------------------------------------------

        difference() {

            // Outer receiver block
            cube([
                female_main_width,
                female_main_height,
                female_main_depth
            ]);


            // Main internal cutout
            // This creates the tunnel for the male connector.
            translate([
                (female_main_width - female_cut_width) / 2,
                (female_main_height - female_cut_height) / 2,
                (female_main_depth - female_cut_depth) / 2
            ])
                cube([
                    female_cut_width,
                    female_cut_height,
                    female_cut_depth + 0.1
                ]);


            // Left side locking opening
            // Starts at the entrance side of the receiver.
            translate([
                -0.1,
                0,
                (female_main_depth - female_side_hole_depth) / 2
            ])
                cube([
                    female_side_hole_width + 0.1,
                    female_side_hole_height,
                    female_side_hole_depth
                ]);


            // Right side locking opening
            // Starts at the entrance side of the receiver.
            translate([
                female_main_width - female_side_hole_width,
                0,
                (female_main_depth - female_side_hole_depth) / 2
            ])
                cube([
                    female_side_hole_width + 0.1,
                    female_side_hole_height,
                    female_side_hole_depth
                ]);
        }


        // ----------------------------------------------------
        // Center guide rail
        // ----------------------------------------------------

        // This rail fits into the slot of the male connector.
        translate([
            (female_main_width - female_line_width) / 2,
            0,
            0
        ])
            cube([
                female_line_width,
                female_line_height,
                female_line_depth
            ]);
    }
}


// ============================================================
// Final layout
// ============================================================

// Male part on the left
translate([
    -male_base_width / 2 - female_main_width / 2 - preview_gap,
    0,
    0
])
    male_connector();


// Female part on the right
translate([
    female_main_width / 2,
    0,
    0
])
    female_connector();