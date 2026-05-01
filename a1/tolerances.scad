$fn = 60;


tolerances();
translate([15,0,0])   rectangular_hole_test();
translate([0, 32, 0])   circular_hole_test();
translate([50,0,0])    rotate(90)  diameter();
translate([0,48,0])    Overhang();
translate([0,65,0])    bridge();




//--------- 1st -------------

module tolerances(){
    difference(){
    cube([10,20,1]);
    translate([5, 18]) cube([5,0.45,5]);
    translate([5, 14]) cube([10,0.40,5]);
    translate([5, 10]) cube([10,0.35,5]);
    translate([5, 6]) cube([10,0.30,5]);
    translate([5, 2]) cube([10,0.25,5]);
    }
}



// ---------- 2nd ----------

// ---------- Rectangular hole test ----------
module rectangular_hole_test() {
    difference() {
        // base plate
        cube([23, 28, 1]);

        // rectangular holes: [width, length]
        translate([3, 4, -1])
            cube([2, 20, 3]);

        translate([8, 4, -1])
            cube([3.5, 20, 3]);

        translate([14.5, 4, -1])
            cube([5, 20, 3]);
    }
}


// ---------- Circular hole test ----------
module circular_hole_test() {
    difference() {
        // base plate
        cube([24, 11, 1]);

        // circular holes: radius 2, 3, 4 mm
        translate([3, 6, -1])
            cylinder(h = 3, r = 2);

        translate([10, 6, -1])
            cylinder(h = 3, r = 3);

        translate([19, 6, -1])
            cylinder(h = 3, r = 4);
    }
}


//----------------- 3rd ---------------------

wall_thickness = 1;
radii = [0.25, 0.5, 0.75, 1, 2.25, 3.5];

// ---------- Diameter / thin circle test ----------
module diameter() {

    // base plate
    cube([60, 10, 1]);

    // circular walls
    for (i = [0 : len(radii)-1]) {
        x = 4 + i * 10;

        translate([x, 5, 1])
            ring_wall(radii[i]);
    }
}

// ---------- Ring wall ----------
module ring_wall(inner_radius) {
    difference() {
        cylinder(
            h = 4,
            r = inner_radius + wall_thickness
        );

        translate([0, 0, -1])
            cylinder(
                h = 6,
                r = inner_radius
            );
    }
}


//------------------- 4th -------------

module Overhang(){
    cube([30,10,5]);
    translate([0,0,5])cube([5,10,30]);
    translate([0,0,35]) rotate([0,10,0]) cube([5,10,5]);
    translate([0.8,0,39.7]) rotate([0,20,0]) cube([5,10,5]);
    translate([2.3,0,43.9]) rotate([0,30,0]) cube([5,10,5]);
    translate([4.55,0,47.9]) rotate([0,40,0]) cube([5,10,5]);
    translate([7.6,0,51.58]) rotate([0,50,0]) cube([5,10,5]);
    translate([11.4,0,54.8]) rotate([0,60,0]) cube([5,10,5]);
    translate([15.7,0,57.3]) rotate([0,70,0]) cube([5,10,5]);
    translate([20.3,0,59]) rotate([0,80,0]) cube([5,10,5]);
}


//------------------ 5th -----------------
module bridge(){
    bridge_lengths = [2.5, 5, 10, 15, 20, 25];
    width = 2;
    height = 2;
    place_between = 6;
    cube([33,42, 1]);
    for(i=[0:len(bridge_lengths)-1]){
        translate([0, i*7+2, 1])
            bridge_builder(bridge_lengths[i],height,width);
    }
}

module bridge_builder(length,height,width){
    cube([width, width, height]);
    translate([0,0,height]) cube([length+(2*width), width, 2]);
    translate([length+width ,0,0]) cube([width, width, height]);
    }







