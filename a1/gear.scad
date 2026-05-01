

$fn = 100;

translate([8,109,0])    rotate($t * 360 * 1.88)  linear_extrude(2) gear(20, true, false);
translate([71.8,109,0])  rotate(-$t * 360) linear_extrude(2) gear(40, true, false);
translate([0,160,0]) mounting_plate();

//-------- self evaluation ------------
r1 = 50;
r2 = 20;
 
translate ([100,20])
gear(radius = r1-r2, hole = true, inverse = false); 
 
translate ([95,-35])
gear(radius = r2, hole = false, inverse = false); 
 
gear(radius = r1, hole = false, inverse = true);



//---------  Mounting Plate ------
module mounting_plate(){
    cube([80,17,3]);
    translate([8,9,3])    linear_extrude(10) circle(3.8);
    translate([71.8,9,3])    linear_extrude(10) circle(3.8);
}


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
                circle(radius+2*tooth_height);
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

