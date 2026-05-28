// connector_male.scad
// Male connector with side arms and half-circle locking heads

$fn = 60;


// ------------------------------------------------------------
// Main dimensions
// ------------------------------------------------------------

thickness = 5;

base_width  = 30;
base_depth  = 8;


// ------------------------------------------------------------
// Strap holder base
// ------------------------------------------------------------

strap_base_width = 30;
strap_base_height = 13;
strap_base_depth = 5;

strap_slot_width = 22;
strap_slot_height = 3.2;
strap_bar_height = 3;


// ------------------------------------------------------------
// Side arms
// ------------------------------------------------------------

arm_width = 5;
arm_total_length = 34;


// ------------------------------------------------------------
// Half-circle locking heads
// ------------------------------------------------------------

// Horizontal distance that the locking head goes outward.
head_length = 6;

// Vertical size of the locking head.
// This should match the female side holes.
head_height = 8;

// Straight part of arm before the head starts.
arm_body_length = arm_total_length - head_height;

// Small overlap between arm and head.
head_overlap = 1.0;


// ------------------------------------------------------------
// Center guide
// ------------------------------------------------------------

center_width = 8;
center_length = 35;

slot_width = 2;
slot_margin_bottom = 5;


// ------------------------------------------------------------
// General settings
// ------------------------------------------------------------

arm_overlap_into_base = 1.5;
rounding = 1.2;


// ------------------------------------------------------------
// Helper modules
// ------------------------------------------------------------

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


// Left locking head.
// Shape: flat tab going left, then half-circle outside.
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


// Right locking head.
// Shape: flat tab going right, then half-circle outside.
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


// ------------------------------------------------------------
// Male connector
// ------------------------------------------------------------

module male_connector() {

    difference() {

        union() {

            // Bag-style strap holder base
            difference() {
                translate([-strap_base_width / 2, -strap_base_height, 0])
                    rounded_box(
                        [strap_base_width, strap_base_height, strap_base_depth],
                        r = rounding
                    );

                // First strap slot
                translate([
                    -strap_slot_width / 2,
                    -strap_base_height + 2,
                    -0.1
                ])
                    cube([
                        strap_slot_width,
                        strap_slot_height,
                        strap_base_depth + 0.2
                    ]);

                // Second strap slot
                translate([
                    -strap_slot_width / 2,
                    -strap_base_height + 2 + strap_slot_height + strap_bar_height,
                    -0.1
                ])
                    cube([
                        strap_slot_width,
                        strap_slot_height,
                        strap_base_depth + 0.2
                    ]);
            }


            // Front base bridge
            translate([-base_width / 2, 0, 0])
                rounded_box(
                    [base_width, base_depth, thickness],
                    r = rounding
                );


            // Left flexible arm
            translate([
                -base_width / 2,
                base_depth - arm_overlap_into_base,
                0
            ])
                cube([
                    arm_width,
                    arm_body_length + arm_overlap_into_base,
                    thickness
                ]);


            // Right flexible arm
            translate([
                base_width / 2 - arm_width,
                base_depth - arm_overlap_into_base,
                0
            ])
                cube([
                    arm_width,
                    arm_body_length + arm_overlap_into_base,
                    thickness
                ]);


            // Left half-circle locking head
            translate([
                -base_width / 2 + arm_width,
                base_depth + arm_body_length - head_overlap + head_height / 2,
                0
            ])
                left_half_circle_head(
                    head_length,
                    head_height,
                    thickness
                );


            // Right half-circle locking head
            translate([
                base_width / 2 - arm_width,
                base_depth + arm_body_length - head_overlap + head_height / 2,
                0
            ])
                right_half_circle_head(
                    head_length,
                    head_height,
                    thickness
                );


            // Center guide
            translate([
                -center_width / 2,
                base_depth - arm_overlap_into_base,
                0
            ])
                rounded_box(
                    [
                        center_width,
                        center_length + arm_overlap_into_base,
                        thickness
                    ],
                    r = 1
                );
        }


        // Open-top straight slot in center guide
        translate([
            -slot_width / 2,
            base_depth + slot_margin_bottom,
            -0.1
        ])
            cube([
                slot_width,
                center_length + 5,
                thickness + 0.2
            ]);
    }
}


// ------------------------------------------------------------
// Show model
// ------------------------------------------------------------

male_connector();