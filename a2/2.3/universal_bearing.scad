$fn = 120;


// EXPORT OPTIONS
// "race"        = regular bowl
// "race_male"   = bowl with a peg
// "roller"      = single roll
// "rollers"     = rolls to print (for bowl)
// "preview"     = full preview
//

part = "preview";

// PARAMETER

inner_r = 10;
outer_r = 36;
h = 11;

roller_count = 14;

roller_r = 4.8;
roller_len = 8;

roller_circle_r = 22;

v_half = 7;
v_depth = 7;

bevel = 0.6;

// Plug-in system
peg_r = inner_r - 0.25;
peg_h = 18;
peg_hole_r = 4;

// REGULAR BOWL

module race_half() {

    difference() {

        cylinder(h=h, r=outer_r);

        // V-groove
        rotate_extrude()
        polygon([
            [roller_circle_r - v_half, h + 1],
            [roller_circle_r,          h - v_depth],
            [roller_circle_r + v_half, h + 1],
            [roller_circle_r + v_half, h + 3],
            [roller_circle_r - v_half, h + 3]
        ]);

        // center hole
        translate([0,0,-1])
            cylinder(h=h+2, r=inner_r);
    }
}

// BOWL WITHOUT A CENTER HOLE

module race_half_no_center_hole() {

    difference() {

        cylinder(h=h, r=outer_r);

        rotate_extrude()
        polygon([
            [roller_circle_r - v_half, h + 1],
            [roller_circle_r,          h - v_depth],
            [roller_circle_r + v_half, h + 1],
            [roller_circle_r + v_half, h + 3],
            [roller_circle_r - v_half, h + 3]
        ]);
    }
}

// BOWL WITH PIN

module race_half_male() {

    difference() {

        union() {

            race_half_no_center_hole();

            // connected peg
            cylinder(h=peg_h, r=peg_r);
        }

        // hole through the peg
        translate([0,0,-1])
            cylinder(h=peg_h+2, r=peg_hole_r);
    }
}

// BEVELED ROLL

module beveled_roller() {

    r = roller_r;
    l = roller_len;
    b = bevel;

    rotate_extrude()
    polygon([
        [0, -l/2],
        [r-b, -l/2],
        [r, -l/2+b],
        [r,  l/2-b],
        [r-b,  l/2],
        [0,  l/2]
    ]);
}

// rolls for printing

module roller_array() {

    for(i=[0:roller_count-1]) {

        a = i * 360 / roller_count;

        rotate([0,0,a])

        translate([roller_circle_r,0,0])

            beveled_roller();
    }
}

// ROLL PREVIEW IN GROOVE

module rollers_preview() {

    for(i=[0:roller_count-1]) {

        a = i * 360 / roller_count;

        // alternately inward / outward
        tilt = (i % 2 == 0) ? 45 : -45;

        rotate([0,0,a])
        translate([roller_circle_r,0,h - 0.2])

        rotate([0,tilt,0])

        rotate([0,90,0])

            beveled_roller();
    }
}

// EXPORTS

if (part == "race") {

    color("lightgray")
        race_half();
}

else if (part == "race_male") {

    color("orange")
        race_half_male();
}

else if (part == "roller") {

    color("gold")
        beveled_roller();
}

else if (part == "rollers") {

    color("gold")
        roller_array();
}

else if (part == "preview") {

    // lower bowl with a peg
    color("orange")
        race_half_male();

    // rolls
    color("silver")
        rollers_preview();

    // normal bowl
    translate([0,0,22])
    mirror([0,0,1])

    color([0.8,0.8,0.8,0.7])
        race_half();
}