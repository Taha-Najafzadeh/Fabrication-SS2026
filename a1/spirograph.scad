
$fn = 80;


//linear_extrude(2)    spirograph(60, 40, [0, 10, 20, 30]);
linear_extrude(2)    spirograph(50, 20, [0, 5, 10, 15]);


//--------- gear ----------------
module gear(radius, hole, inverse) {
    tooth_height = 3;
    tooth_width = 6;
    teeth = floor(radius*PI*2/tooth_width);
    
    if(inverse == false){
        if(hole == true){
            difference() {
                union() {
                    // main circle
                    circle(radius);

                    // teeth
                    for (i = [0 : teeth - 1]) {
                        rotate(i * 360 / teeth)
                            tooth(radius,tooth_width,tooth_height,inverse);
                    }
                }

                // center hole
                circle(4);
            }
        }
        
        if(hole == false){
            union() {
                // main circle
                circle(radius);

                // teeth
                for (i = [0 : teeth - 1]) {
                    rotate(i * 360 / teeth)
                        tooth(radius,tooth_width,tooth_height,inverse);
                }
            }
        }
    }
    
    if(inverse == true){
        union(){
            difference(){
                circle(radius+4*tooth_height);
                circle(radius + tooth_height);
            }
            for(i = [0 : teeth - 1]){
                rotate(i * 360 / teeth)
                    tooth(radius,tooth_width,tooth_height,inverse);
            }
        }
    }
}

module tooth(radius,tooth_width,tooth_height, inverse) {
    if(inverse == false){
        polygon(points = [
            [radius - 0.3, -tooth_width/2],
            [radius + tooth_height, -0.7],
            [radius + tooth_height, 0.7],
            [radius - 0.3, tooth_width/2]
        ]);
    }
    if(inverse == true){
        polygon(points = [
            [radius + tooth_height, -tooth_width/2],
            [radius, -0.7],
            [radius, 0.7],
            [radius + tooth_height, tooth_width/2]
            ]);
    }
}



// -------------------- Settings --------------------
R = 60;          // outer fixed gear radius
r = 40;          // inner moving gear radius
d = 10;          // pen distance from inner gear center

inside = true;   // true = hypotrochoid, false = epitrochoid

steps = 50;
line_width = 0.8;

// Animation progress
current_step = floor($t * steps);

// -------------------- Model --------------------
//spirograph_animated(R, r, d, inside);


// -------------------- Main module --------------------
module spirograph_animated(R, r, d, inside=true) {

    // fixed outer gear / circle
    color("black")
        ring(R, 1.5);

    // final complete drawing
    color("lightgray")
        draw_curve(R, r, d, inside, steps);

    // partial drawing up to current animation position
    color("yellow")
        draw_curve(R, r, d, inside, current_step);

    // moving inner gear
    c = gear_center(R, r, current_step_angle(), inside);

    color("teal")
        translate(c)
            ring(r, 1.5);

    // pen position
    p = spiro_point(R, r, d, current_step_angle(), inside);

    color("red")
        translate(p)
            circle(r = 2);
}


// -------------------- Angle --------------------
function current_step_angle() =
    360 * 3 *  $t;


// -------------------- Spirograph point --------------------
function spiro_point(R, r, d, t, inside=true) =
    inside
    ? [
        (R-r)*cos(t) + d*cos(((R-r)/r)*t),
        (R-r)*sin(t) - d*sin(((R-r)/r)*t)
      ]
    : [
        (R+r)*cos(t) - d*cos(((R+r)/r)*t),
        (R+r)*sin(t) - d*sin(((R+r)/r)*t)
      ];


// -------------------- Moving gear center --------------------
function gear_center(R, r, t, inside=true) =
    inside
    ? [
        (R-r)*cos(t),
        (R-r)*sin(t)
      ]
    : [
        (R+r)*cos(t),
        (R+r)*sin(t)
      ];


// -------------------- Draw curve --------------------
module draw_curve(R, r, d, inside=true, n=100) {
    for (i = [0 : n-1]) {
        t1 = 360 * 3 * i / steps;
        t2 = 360 * 3 * (i+1) / steps;

        p1 = spiro_point(R, r, d, t1, inside);
        p2 = spiro_point(R, r, d, t2, inside);

        hull() {
            translate(p1) circle(r = line_width);
            translate(p2) circle(r = line_width);
        }
    }
}


// -------------------- Ring helper --------------------
module ring(radius, thickness) {
    difference() {
        circle(r = radius);
        circle(r = radius - thickness);
    }
}





//------------------- spirograph --------------------
module spirograph(R, r, d=[]){
    gear(R, false, true);
    difference(){
        gear(r, false, false);
        for(i= [0: len(d)-1]){
            translate([d[i],0,0]) circle(1);
        }
    }
    
}





