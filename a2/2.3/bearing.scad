$fn = 128;

part = "all";
// "all", "assembly", "inner", "outer_top", "outer_bottom", "cage", "balls", "print_layout"

size_index = 1;
// 0 = 10mm, 1 = 30mm, 2 = 50mm

sizes = [10, 30, 50];

ball_diameter = 6.35;
ball_radius = ball_diameter / 2;

height = 10;
half_height = height / 2;

ring_wall = 4;
ball_count = 6;

// tolerance
race_clearance = 0.12;
cage_clearance = 0.20;

// screws 
screw_radius = 1.4;     // ca. M2.5
screw_count = 4;


// basic forms 
module ring(outer_r, inner_r, h) {
    difference() {
        cylinder(r = outer_r, h = h, center = true);
        cylinder(r = inner_r, h = h + 0.5, center = true);
    }
}

module groove(radius_pos, groove_radius) {
    rotate_extrude()
        translate([radius_pos, 0, 0])
            circle(r = groove_radius);
}


// dimensions 
function track_radius(inner_radius) =
    inner_radius + ring_wall + ball_radius;

function inner_outer_radius(inner_radius) =
    track_radius(inner_radius) - ball_radius * 0.35;

function outer_inner_radius(inner_radius) =
    track_radius(inner_radius) + ball_radius * 0.35;

function outer_radius(inner_radius) =
    outer_inner_radius(inner_radius) + ring_wall + 2;


// inner ring
module inner_ring(inner_radius) {
    tr = track_radius(inner_radius);
    gr = ball_radius + race_clearance;

    difference() {
        ring(inner_outer_radius(inner_radius), inner_radius, height);
        groove(tr, gr);
    }
}


// whole outer ring
module outer_ring_complete(inner_radius) {
    tr = track_radius(inner_radius);
    gr = ball_radius + race_clearance;

    difference() {
        ring(outer_radius(inner_radius), outer_inner_radius(inner_radius), height);
        groove(tr, gr);
    }
}


// vertical screw holes
module vertical_screw_holes(inner_radius, with_head=false) {
    or = outer_radius(inner_radius);
    screw_r = or - ring_wall / 2;

    for (i = [0:screw_count-1]) {
        a = 360 / screw_count * i + 45;

        translate([
            screw_r * cos(a),
            screw_r * sin(a),
            0
        ]) {
            cylinder(r = screw_radius, h = height + 4, center = true);
        }
    }
}


// outer ring top
module outer_top(inner_radius) {
    difference() {
        intersection() {
            outer_ring_complete(inner_radius);

            translate([0,0,half_height/2])
                cube([
                    outer_radius(inner_radius) * 3,
                    outer_radius(inner_radius) * 3,
                    half_height
                ], center = true);
        }

        vertical_screw_holes(inner_radius, true);
    }
}


// outer ring bottom
module outer_bottom(inner_radius) {
    difference() {
        intersection() {
            outer_ring_complete(inner_radius);

            translate([0,0,-half_height/2])
                cube([
                    outer_radius(inner_radius) * 3,
                    outer_radius(inner_radius) * 3,
                    half_height
                ], center = true);
        }

        vertical_screw_holes(inner_radius, false);
    }
}


// balls just for illustrative purposes
module balls(inner_radius, rotation_angle = 0) {
    tr = track_radius(inner_radius);

    for (i = [0:ball_count-1]) {
        a = i * 360 / ball_count + rotation_angle;

        translate([
            tr * cos(a),
            tr * sin(a),
            0
        ])
        sphere(r = ball_radius);
    }
}
// cage
//An attempt at a cage with pockets. It was not used further because no satisfactory result was found.
module cage(inner_radius, rotation_angle = 0) {

    tr = track_radius(inner_radius);

    cage_height = height * 0.55;
    cage_thickness = 1.5;

    cage_outer = tr + cage_thickness / 2;
    cage_inner = tr - cage_thickness / 2;

    pocket_r = 3.1;          // exakt 6.35 mm Kugel
    pocket_open_width = 4.0;   // Öffnung nach oben
    slot_width = 0.8;          // kleine Schlitze neben Tasche
    slot_depth = 1.4;

    rotate([0,0,rotation_angle])
    difference() {

        // dünner geschlossener Ring
        ring(cage_outer, cage_inner, cage_height);

        for (i = [0:ball_count-1]) {
            a = i * 360 / ball_count;

            rotate([0,0,a]) {

                // runde Kugeltasche als Halbkreis nach außen offen
                translate([tr, 0, cage_height * 0.18])
                    sphere(r = pocket_r);

                // Öffnung nach oben/außen, damit Kugel eingesetzt werden kann
                translate([tr, 0, cage_height * 0.55])
                    cube([
                        pocket_open_width,
                        cage_thickness + 3,
                        cage_height
                    ], center = true);

                // kleiner Schlitz links neben der Tasche
                translate([tr - pocket_r * 0.75, 0, cage_height * 0.45])
                    cube([
                        slot_width,
                        cage_thickness + 3,
                        slot_depth
                    ], center = true);

                // kleiner Schlitz rechts neben der Tasche
                translate([tr + pocket_r * 0.75, 0, cage_height * 0.45])
                    cube([
                        slot_width,
                        cage_thickness + 3,
                        slot_depth
                    ], center = true);
            }
        }
    }
}
// old cage
module old_cage(inner_radius, rotation_angle=0) {

    track_radius = inner_radius + ring_wall + ball_radius;

    cage_outer = track_radius + ball_radius * 0.65;
    cage_inner = track_radius - ball_radius * 0.65;
    cage_height = height * 0.35;

    rotate([0,0,rotation_angle])
    difference() {

        ring(cage_outer, cage_inner, cage_height);

        for (i=[0:ball_count-1]) {

            a = i * 360 / ball_count;

            translate([
                track_radius*cos(a),
                track_radius*sin(a),
                0
            ])
            sphere(r=ball_radius + 0.25);
        }
    }
}


// assembly
module assembly(inner_radius) {
    color("silver")
    outer_bottom(inner_radius);

    color("silver")
    outer_top(inner_radius);

    rotate([0,0,$t*360])
    color("lightgray")
    inner_ring(inner_radius);

    color("gray")
    balls(inner_radius, $t*180);

    color([0.9,0.9,0.9,0.7])
    cage(inner_radius, $t*180);
}


// print layout
module print_layout(inner_radius) {
    spacing = outer_radius(inner_radius) * 2.6;

    translate([-spacing, 0, 0])
        inner_ring(inner_radius);

    translate([0, spacing/2, 0])
        outer_top(inner_radius);

    translate([0, -spacing/2, 0])
        outer_bottom(inner_radius);

    translate([spacing, 0, 0])
        cage(inner_radius);
}


// output 
if (part == "all") {
    translate([-90,0,0]) assembly(sizes[0]);
    translate([60,0,0]) assembly(sizes[1]);
    translate([260,0,0]) assembly(sizes[2]);
}

if (part == "assembly") assembly(sizes[size_index]);
if (part == "inner") inner_ring(sizes[size_index]);
if (part == "outer_top") outer_top(sizes[size_index]);
if (part == "outer_bottom") outer_bottom(sizes[size_index]);
if (part == "cage") cage(sizes[size_index]);
if (part == "old_cage") old_cage(sizes[size_index]);
if (part == "balls") balls(sizes[size_index]);
if (part == "print_layout") print_layout(sizes[size_index]);