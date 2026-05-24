// ============================================================
// 4x6 Labyrinth Maze
// Simple Flat Ramp Per Cell
// Corrected polyhedron face order
// ============================================================


// ------------------------------------------------------------
// Input data
// ------------------------------------------------------------



rows = 5;
cols = 5;
target_row = 4;
target_col = 3;

cell_size = 12.0;
wall_thickness = 1.4;
wall_height = 7.0;
ball_diameter = 6.35;
target_hole_diameter = 7.5;

walls_south = [
   [ 0, 1, 0, 1, 0 ],
   [ 1, 0, 0, 0, 1 ],
   [ 0, 1, 1, 0, 0 ],
   [ 0, 0, 1, 1, 0 ],
   [ 1, 1, 1, 1, 1 ]
];

walls_east = [
   [ 0, 0, 1, 0, 1 ],
   [ 1, 0, 1, 0, 1 ],
   [ 0, 1, 0, 1, 1 ],
   [ 1, 0, 0, 0, 1 ],
   [ 0, 0, 0, 0, 1 ]
];

distance_map = [
   [ 9, 8, 7, 8, 7 ],
   [ 10, 7, 6, 5, 6 ],
   [ 5, 6, 5, 4, 3 ],
   [ 4, 3, 4, 3, 2 ],
   [ 3, 2, 1, 0, 1 ]
];

height_map = [
   [ 7.500, 6.800, 6.100, 6.800, 6.100 ],
   [ 8.200, 6.100, 5.400, 4.700, 5.400 ],
   [ 4.700, 5.400, 4.700, 4.000, 3.300 ],
   [ 4.000, 3.300, 4.000, 3.300, 2.600 ],
   [ 3.300, 2.600, 1.900, 1.200, 1.900 ]
];

flow_direction = [
   [ "E", "E", "S", "E", "S" ],
   [ "N", "S", "S", "S", "W" ],
   [ "S", "W", "E", "S", "S" ],
   [ "S", "S", "W", "E", "S" ],
   [ "E", "E", "E", "T", "W" ]
];




// ------------------------------------------------------------
// Model settings
// ------------------------------------------------------------

$fn = 80;

bottom_thickness = 1.2;
eps = 0.03;

// For testing flat cells, set this to 0.
// For real slope, use 0.40 or 0.50.
slope_strength = 0.35;

// Keep zero. Overlap causes intersection artifacts.
floor_overlap = 0;

show_direction_colors = true;


// ------------------------------------------------------------
// Helper functions
// ------------------------------------------------------------

function x_pos(c) = c * cell_size;
function y_pos(r) = r * cell_size;

// For testing all cells same flat height, use:
// function h(r, c) = 1.2;

// For real maze height map, use:
function h(r, c) = height_map[r][c];

function dir(r, c) = flow_direction[r][c];

function dir_color(d) =
    d == "N" ? "lightskyblue" :
    d == "S" ? "lightgreen" :
    d == "E" ? "orange" :
    d == "W" ? "violet" :
    d == "T" ? "red" :
    "lightgray";


// ------------------------------------------------------------
// Direction-based flat ramp
// ------------------------------------------------------------

/*
Corner order:

ch[0] = northwest
ch[1] = northeast
ch[2] = southwest
ch[3] = southeast
*/

function corner_heights_by_flow(r, c) =
    let(
        center_h = h(r, c),
        high_h = center_h + slope_strength,
        low_h  = center_h - slope_strength,
        d = dir(r, c)
    )

    d == "E" ? [
        high_h, low_h,
        high_h, low_h
    ] :

    d == "W" ? [
        low_h, high_h,
        low_h, high_h
    ] :

    d == "S" ? [
        high_h, high_h,
        low_h, low_h
    ] :

    d == "N" ? [
        low_h, low_h,
        high_h, high_h
    ] :

    [
        center_h, center_h,
        center_h, center_h
    ];


// ------------------------------------------------------------
// One sloped floor cell
// ------------------------------------------------------------

module floor_tile(r, c) {
    x = x_pos(c);
    y = y_pos(r);

    ch = corner_heights_by_flow(r, c);

    color(show_direction_colors ? dir_color(dir(r,c)) : "lightgray")
    polyhedron(
        points = [
            // bottom points
            [x,             y,             0], // 0 NW bottom
            [x + cell_size, y,             0], // 1 NE bottom
            [x,             y + cell_size, 0], // 2 SW bottom
            [x + cell_size, y + cell_size, 0], // 3 SE bottom

            // top points
            [x,             y,             bottom_thickness + ch[0]], // 4 NW top
            [x + cell_size, y,             bottom_thickness + ch[1]], // 5 NE top
            [x,             y + cell_size, bottom_thickness + ch[2]], // 6 SW top
            [x + cell_size, y + cell_size, bottom_thickness + ch[3]]  // 7 SE top
        ],

        faces = [
            // bottom face
            [0, 1, 3, 2],

            // top face, correct order around rectangle
            [4, 6, 7, 5],

            // side faces
            [0, 4, 5, 1], // north side
            [1, 5, 7, 3], // east side
            [3, 7, 6, 2], // south side
            [2, 6, 4, 0]  // west side
        ]
    );
}


module all_floor_tiles() {
    for (r = [0 : rows - 1]) {
        for (c = [0 : cols - 1]) {
            floor_tile(r, c);
        }
    }
}


// ------------------------------------------------------------
// Walls
// ------------------------------------------------------------

module south_wall(r, c) {
    x = x_pos(c);
    y = y_pos(r + 1) - wall_thickness / 2;

    translate([x - eps, y, 0])
    cube([
        cell_size + 2 * eps,
        wall_thickness,
        wall_height + bottom_thickness + h(r,c) + slope_strength
    ]);
}


module east_wall(r, c) {
    x = x_pos(c + 1) - wall_thickness / 2;
    y = y_pos(r);

    translate([x, y - eps, 0])
    cube([
        wall_thickness,
        cell_size + 2 * eps,
        wall_height + bottom_thickness + h(r,c) + slope_strength
    ]);
}


module north_boundary_wall(c) {
    x = x_pos(c);
    y = -wall_thickness / 2;

    translate([x - eps, y, 0])
    cube([
        cell_size + 2 * eps,
        wall_thickness,
        wall_height + bottom_thickness + h(0,c) + slope_strength
    ]);
}


module west_boundary_wall(r) {
    x = -wall_thickness / 2;
    y = y_pos(r);

    translate([x, y - eps, 0])
    cube([
        wall_thickness,
        cell_size + 2 * eps,
        wall_height + bottom_thickness + h(r,0) + slope_strength
    ]);
}


module all_walls() {
    color("dimgray") {
        // implicit north boundary
        for (c = [0 : cols - 1]) {
            north_boundary_wall(c);
        }

        // implicit west boundary
        for (r = [0 : rows - 1]) {
            west_boundary_wall(r);
        }

        // explicit south and east walls
        for (r = [0 : rows - 1]) {
            for (c = [0 : cols - 1]) {
                if (walls_south[r][c] == 1) {
                    south_wall(r, c);
                }

                if (walls_east[r][c] == 1) {
                    east_wall(r, c);
                }
            }
        }
    }
}


// ------------------------------------------------------------
// Target hole
// ------------------------------------------------------------

module target_hole_cut() {
    x = x_pos(target_col) + cell_size / 2;
    y = y_pos(target_row) + cell_size / 2;

    translate([x, y, -eps])
    cylinder(
        h = wall_height + bottom_thickness + 40,
        d = target_hole_diameter
    );
}


// ------------------------------------------------------------
// Complete labyrinth
// ------------------------------------------------------------

module labyrinth() {
    difference() {
        union() {
            all_floor_tiles();
            all_walls();
        }

        target_hole_cut();
    }
}


// ------------------------------------------------------------
// Render
// ------------------------------------------------------------

labyrinth();