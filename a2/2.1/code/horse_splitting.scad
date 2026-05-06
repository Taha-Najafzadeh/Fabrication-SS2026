module horse() {
    import("C:/Users/Marius/Downloads/horse.stl", convexity = 10);
}

/*
    Y-axis split points (adjust if needed):

    y0 = far left outer edge
    y1 = middle of left leg
    y2 = left inner body / tail area
    y3 = center
    y4 = right inner body / tail area
    y5 = far right outer edge
*/

y0 = -23.8;
y1 = -10;
y2 = -4;
y3 = 0;
y4 = 4;
y5 = 23.8;

module slice(y_start, y_end) {
    intersection() {
        horse();
        translate([-100, y_start, -10])
            cube([200, y_end - y_start, 200]);
    }
}

module part1() {
    slice(y0, y1);
}

module part2() {
    slice(y1, y2);
}

module part3() {
    slice(y2, y3);
}

module part4() {
    slice(y3, y4);
}

module part5() {
    slice(y4, y5);
}

part = 2;   // choose: 1, 2, 3, 4, or 5

debug = false;


// Debug visualization
if (debug) {
    %horse();

    color("red") part1();
    color("green") part2();
    color("blue") part3();
    color("yellow") part4();
    color("purple") part5();
}


// Export mode
if (!debug) {
    if (part == 1) part1();
    if (part == 2) part2();
    if (part == 3) part3();
    if (part == 4) part4();
    if (part == 5) part5();
}