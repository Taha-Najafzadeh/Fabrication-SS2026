module horse() {
    import("C:/Users/Marius/Downloads/horse.stl", convexity = 10);
}

// Slice boundaries

y0 = -23;
y1 = -9;
y2 = -5;
y3 = 0;
y4 = 5;
y5 = 25;

// Weight chamber

module weight_cut_area() {
    translate([20, -5.002, 1])
        cube([15, 10.01, 11]);
}

// Generic slice modules

module slice_y(y_start, y_end) {
    intersection() {
        children();

        translate([-100, y_start, -10])
            cube([200, y_end - y_start, 200]);
    }
}

module slice_z(z_start, z_end) {
    intersection() {
        children();

        translate([-100, -100, z_start])
            cube([200, 200, z_end - z_start]);
    }
}

module slice_x(x_start, x_end) {
    intersection() {
        children();

        translate([x_start, -100, -100])
            cube([x_end - x_start, 200, 200]);
    }
}

module rotated_slice(size=[200,200,200],
                     pos=[0,0,0],
                     rot=[0,0,0]) {

    intersection() {
        children();

        translate(pos)
            rotate(rot)
                cube(size);
    }
}

// Separate cut areas

module head_cut_area() {
    rotated_slice(
        size=[200,200,60],
        pos=[-30,-100,100],
        rot=[0,20,0]
    )
        slice_y(-10,10)
            horse();
}

// left head half
module head_left() {
    slice_y(-10, 0)
        head_cut_area();
}

// right head half
module head_right() {
    slice_y(0, 10)
        head_cut_area();
}

module tail_cut_area() {
    slice_x(33, 90)
        slice_z(20, 65)
            slice_y(-2, 1.5)
                horse();
}

module tail_left() {
    slice_y(-10, 0)
        tail_cut_area();
}

module tail_right() {
    slice_y(0, 10)
        tail_cut_area();
}

// Final parts

module part1() {
    difference() {
        slice_y(y0, y1) horse();
        head_cut_area();
        tail_cut_area();
    }
}

module part2() {
    difference() {
        slice_y(y0, y2) horse();

        head_cut_area();
        tail_cut_area();
        weight_cut_area();
    }
}

module part3() {
    difference() {
        slice_y(y2, y3) horse();

        head_cut_area();
        tail_cut_area();
        weight_cut_area();
    }
}

module part4() {
    difference() {
        slice_y(y3, y4) horse();

        head_cut_area();
        tail_cut_area();
        weight_cut_area();
    }
}

module part5() {
    difference() {
        slice_y(y4, y5) horse();

        head_cut_area();
        tail_cut_area();
        weight_cut_area();
    }
}

module head() {
    head_cut_area();
}

module tail() {
    tail_cut_area();
 }

// Selection
part = 5;   // choose 2, 3, 4, 5, or 6

debug = true;
explode = true;

// Debug view

if (debug && !explode) {
    %horse();

    color("green") part2();
    color("blue") part3();
    color("yellow") part4();
    color("purple") part5();
    color("orange") head();
}

// Exploded view

if (debug && explode) {
    translate([-50, 0, 0]) color("green") part2();
    translate([0, 0, 0]) color("blue") part3();
    translate([50, 0, 0]) color("yellow") part4();
    translate([100, 0, 0]) color("purple") part5();
    translate([150, 0, 0]) color("orange") head();
    translate([190, 0, 0]) color("red") tail();
    translate([230, 0, 0]) color("red") leg();
}

// Export mode

if (!debug) {
    if (part == 2) part2();
    if (part == 3) part3();
    if (part == 4) part4();
    if (part == 5) part5();
    if (part == 6) head();
    if (part== 7) tail();
    if (part == 8) head_left();
    if (part == 9) head_right();
    if (part == 10) tail_left();
    if (part == 11) tail_right();
}