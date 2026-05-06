$fn = 128;

part = "all";
// "all", "assembly", "inner", "outer_left", "outer_right", "cage"

size_index = 0;
// 0 = 10mm, 1 = 30mm, 2 = 50mm

sizes = [10, 30, 50];

ball_diameter = 6.35;
ball_radius = ball_diameter / 2;

height = 10;
clearance = 0.35;
ring_wall = 4;
ball_count = 6;

lug_length = 8;
lug_width = 4.5;
split_gap = 3;
screw_radius = 1.4;

module ring(outer_r, inner_r, h) {
    difference() {
        cylinder(r=outer_r, h=h, center=true);
        cylinder(r=inner_r, h=h+0.5, center=true);
    }
}

module groove(radius_pos, groove_radius) {
    rotate_extrude()
        translate([radius_pos, 0, 0])
            circle(r=groove_radius);
}

module inner_ring(inner_radius) {
    track_radius = inner_radius + ring_wall + ball_radius;
    groove_radius = ball_radius + clearance;
    inner_outer_radius = track_radius - ball_radius * 0.35;

    difference() {
        ring(inner_outer_radius, inner_radius, height);
        groove(track_radius, groove_radius);
    }
}

module lug_block(xpos, ypos, outer_radius) {
    hull() {
        translate([xpos, ypos, 0])
            cylinder(r = lug_width/2, h = height, center = true);
        translate([xpos, ypos + sign(ypos) * lug_length, 0])
            cylinder(r = lug_width/2, h = height, center = true);
    }
}

module outer_ring_complete(inner_radius) {
    track_radius = inner_radius + ring_wall + ball_radius;
    groove_radius = ball_radius + clearance;

    outer_inner_radius = track_radius + ball_radius * 0.35;
    outer_radius = outer_inner_radius + ring_wall;

    difference() {
        ring(outer_radius, outer_inner_radius, height);
        groove(track_radius, groove_radius);
    }
}

module outer_left(inner_radius) {
    track_radius = inner_radius + ring_wall + ball_radius;
    outer_inner_radius = track_radius + ball_radius * 0.35;
    outer_radius = outer_inner_radius + ring_wall;

    lug_x = -split_gap/2 - lug_width/2;

    difference() {
        union() {
            intersection() {
                outer_ring_complete(inner_radius);

                translate([-outer_radius/2 - split_gap/2, 0, 0])
                    cube([outer_radius, outer_radius*3, height+2], center=true);
            }

            lug_block(lug_x,  outer_radius, outer_radius);
            lug_block(lug_x, -outer_radius, outer_radius);
        }

        translate([0,  outer_radius + lug_length/2, 0])
            rotate([0,90,0])
            cylinder(r=screw_radius, h=40, center=true);

        translate([0, -outer_radius - lug_length/2, 0])
            rotate([0,90,0])
            cylinder(r=screw_radius, h=40, center=true);
    }
}

module outer_right(inner_radius) {
    track_radius = inner_radius + ring_wall + ball_radius;
    outer_inner_radius = track_radius + ball_radius * 0.35;
    outer_radius = outer_inner_radius + ring_wall;

    lug_x = split_gap/2 + lug_width/2;

    difference() {
        union() {
            intersection() {
                outer_ring_complete(inner_radius);

                translate([outer_radius/2 + split_gap/2, 0, 0])
                    cube([outer_radius, outer_radius*3, height+2], center=true);
            }

            lug_block(lug_x,  outer_radius, outer_radius);
            lug_block(lug_x, -outer_radius, outer_radius);
        }

        translate([0,  outer_radius + lug_length/2, 0])
            rotate([0,90,0])
            cylinder(r=screw_radius, h=40, center=true);

        translate([0, -outer_radius - lug_length/2, 0])
            rotate([0,90,0])
            cylinder(r=screw_radius, h=40, center=true);
    }
}

module balls(inner_radius, rotation_angle=0) {
    track_radius = inner_radius + ring_wall + ball_radius;

    for (i=[0:ball_count-1]) {
        a = i * 360 / ball_count + rotation_angle;

        translate([
            track_radius*cos(a),
            track_radius*sin(a),
            0
        ])
        sphere(r=ball_radius);
    }
}

module cage(inner_radius, rotation_angle=0) {
    track_radius = inner_radius + ring_wall + ball_radius;

    cage_outer = track_radius + ball_radius * 0.55;
    cage_inner = track_radius - ball_radius * 0.55;
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
            sphere(r=ball_radius + 0.8);
        }
    }
}

module assembly(inner_radius) {
    color("silver") outer_left(inner_radius);
    color("silver") outer_right(inner_radius);

    rotate([0,0,$t*360])
    color("lightgray")
    inner_ring(inner_radius);

    color("gray")
    balls(inner_radius, $t*180);

    color([0.9,0.9,0.9,0.7])
    cage(inner_radius, $t*180);
}

if (part == "all") {
    translate([-80,0,0]) assembly(sizes[0]);
    translate([40,0,0]) assembly(sizes[1]);
    translate([220,0,0]) assembly(sizes[2]);
}

if (part == "assembly") assembly(sizes[size_index]);
if (part == "inner") inner_ring(sizes[size_index]);
if (part == "outer_left") outer_left(sizes[size_index]);
if (part == "outer_right") outer_right(sizes[size_index]);
if (part == "cage") cage(sizes[size_index]);