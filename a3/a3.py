from __future__ import annotations
import os
import sys
import trimesh
from trimesh import transformations
import shapely
import shapely.affinity
from shapely.plotting import plot_polygon
import numpy as np
import matplotlib.pyplot as plt
from tqdm import tqdm
import argparse

# -----------------------------------------------------------
# SETTINGS (units in mm or mm/min)

BED_SIZE_X = 320
BED_SIZE_Y = 350
BED_SIZE_Z = 330
BASE_Z_OFFSET = 0.2
LAYER_HEIGHT = 0.24
FEEDRATE_OUTER = 900
FEEDRATE_INNER = 1200
FEEDRATE_INFILL = 3000
FEEDRATE_MOVE = 1440

NOZZLE_DIAMETER = 0.4
FILAMENT_DIAMETER = 1.75
INNER_WALLS = 1
INFILL_DENSITY = 0.25

NOZZLE_TEMPERATURE = 200
BED_TEMPERATURE = 60

# E is used in absolute mode, therefore we keep track of the current E value.
CURRENT_E = 0.0

"""argument parsing"""
def parse_args(): # this is an example configuration. feel free to adjust 
    parser = argparse.ArgumentParser(description="slice an stl model.")
    parser.add_argument('filename', help="path to stl model.")
    parser.add_argument("-a","--adhesion", default="none", help="Bed adhesion type.", choices=['none', 'skirt', 'brim'])
    parser.add_argument("-i","--infill", default="none", help="Infill type.", choices=['none', 'basic', 'advanced1', 'advanced2', 'freestyle'])
    parser.add_argument("-d","--density", default=10, type=int, help="_infill Density in percent.")
    parser.add_argument('-r', '--reduce_size', action='store_true')
    parser.add_argument('-s', '--supports', action='store_true')
    args = parser.parse_args()
    return args

# -----------------------------------------------------------
# 3D mesh helpers (feel free to adapt, change or add functions)

"""" helper to load mesh file (.stl or .obj etc) from disk which can be visualized with .show() """
def load_mesh_from_file(filename: str) -> trimesh.Trimesh:
    print(f'Loading {filename}...')
    mesh = trimesh.load(filename)
    return mesh

""" helper to slice given mesh with the xy-plane at a height along the z-axis, returns a list of shapely polygons """
def slice_mesh_along_z_axis(mesh: trimesh.Trimesh, z_height: float) -> list[shapely.Polygon]:
    slice = mesh.section_multiplane(plane_origin=[0,0,0], plane_normal=[0, 0, 1], heights=[z_height])[0]
    return slice.simplify().polygons_full if slice else []

# -----------------------------------------------------------
# 2D shape helpers (feel free to adapt, change or add functions)

""" helper to write svg file from shapely shape for debugging """
def write_svg(shape, filename: str) -> None:
    with open(os.path.splitext(filename)[0] + '.svg', 'w') as f:
        f.write(shape._repr_svg_())

""" helper to show a polygon or multipolygon from shapely for debugging """
def show_polygon(shape, bounds, label="plot") -> None:
    if type(shape) is shapely.MultiPolygon:
        for p in shape.geoms:
            plot_polygon(p)
        plt.ylim(bounds[0][1],bounds[1][1])
        plt.xlim(bounds[0][0],bounds[1][0])
        plt.title(label)
        plt.show()
    elif type(shape) is shapely.Polygon:
        plot_polygon(shape)
        plt.ylim(bounds[0][1],bounds[1][1])
        plt.xlim(bounds[0][0],bounds[1][0])
        plt.title(label)
        plt.show()
    elif type(shape) is list or type(shape) is np.ndarray:
        for p in shape:
            if type(p) is shapely.MultiPolygon:
                for p1 in p.geoms:
                    plot_polygon(p1)
            else:
                plot_polygon(p)
        plt.ylim(bounds[0][1],bounds[1][1])
        plt.xlim(bounds[0][0],bounds[1][0])
        plt.title(label)
        plt.show()
    else:
        raise TypeError(f'Unsupported shape type: {type(shape)}! Shape: {shape}')

""" helper to instersect a shapely shape with a shapely line, returns a list of shapely lines """
def intersect_line(shape, line: shapely.LineString) -> list[shapely.LineString]:
    with np.errstate(invalid="ignore"): # avoid annoying error messages
        if type(shape) is shapely.LineString:
            return [shapely.intersection(shapely.Polygon(shape), line)] # ensure result is line, not points
        if type(shape) is shapely.MultiLineString:
            return [shapely.intersection(shapely.Polygon(geom), line) for geom in shape.geoms]
        elif type(shape) is shapely.Polygon:
            return [shapely.intersection(shape, line)]
        elif type(shape) is shapely.MultiPolygon:
            return [shapely.intersection(shape, line)]
        else:
            raise TypeError(f'Unsupported shape type: {type(shape)}! Shape: {shape}')

""" helper to union a layer slice with another layer slice, returns a list of shapely polygons/multipolygons """
def union_layer(shape1, shape2) -> list[shapely.Polygon]:
    union = None
    with np.errstate(invalid="ignore"): # avoid annoying error messages
        for p in shape1:
            if union is None:
                union = p
            else:
                union = shapely.union(union,p)
        for p in shape2:
            if union is None:
                union = p
            else:
                union = shapely.union(union,p)
        return [union]

""" helper to compute the difference between two layers, returns a list of shapely polygons/multipolygons """
def difference_layer(shape1, shape2) -> list[shapely.Polygon]:
    union = None
    diff = None
    if len(shape1) == 0 or len(shape2) == 0:
        return shape1
    with np.errstate(invalid="ignore"): # avoid annoying error messages
        for p in shape1:
            if union is None:
                union = p
            else:
                union = shapely.union(union,p)
        for p in shape2:
            if diff is None:
                diff = shapely.difference(union,p)
            else:
                diff = shapely.difference(diff,p)
        return [diff]

# -----------------------------------------------------------
# G-Code helpers (feel free to adapt, change or add functions)

""" helper to convert a list of coordinates, i.e. a line, into a series of printer G0/G1 commands """
def coords_to_gcode(coords, z_height: float, feedrate: float, reduce_size = True):
    global CURRENT_E

    gcode = ''
    coords = list(coords)

    if len(coords) == 0:
        return gcode

    # Surface area of the filament: A = pi * r^2
    filament_radius = FILAMENT_DIAMETER / 2
    filament_area = np.pi * filament_radius ** 2

    # If reduce_size is enabled, the given 2D coordinates are interpreted
    # around the origin and shifted to the center of the print bed.
    def transform_coordinate(x, y):
        if reduce_size:
            return x + 60, y + 70
        return x, y

    # First coordinate: travel move without extrusion.
    start_x, start_y = transform_coordinate(coords[0][0], coords[0][1])
    gcode += f'G0 X{start_x:.3f} Y{start_y:.3f} Z{z_height:.3f} F{FEEDRATE_MOVE}\n'

    # Following coordinates: print moves with extrusion.
    for i in range(1, len(coords)):
        previous_x, previous_y = coords[i - 1]
        current_x, current_y = coords[i]

        dx = current_x - previous_x
        dy = current_y - previous_y
        segment_length = np.sqrt(dx ** 2 + dy ** 2)

        # Simplified model from the assignment:
        # line volume = segment length * nozzle diameter * layer height
        line_volume = segment_length * NOZZLE_DIAMETER * LAYER_HEIGHT
        extrusion_length = line_volume / filament_area

        # We use absolute E mode, so E must increase continuously.
        CURRENT_E += extrusion_length

        x, y = transform_coordinate(current_x, current_y)
        gcode += f'G1 X{x:.3f} Y{y:.3f} Z{z_height:.3f} E{CURRENT_E:.5f} F{feedrate}\n'

    return gcode


def reset_extrusion():
    global CURRENT_E
    CURRENT_E = 0.0
    return 'G92 E0\n'


def minimal_header_to_gcode():
    gcode = ''
    gcode += 'G90 ; absolute mode for X/Y/Z\n'
    gcode += 'M82 ; absolute mode for E axis\n'
    gcode += 'G21 ; units in millimeters\n'
    return gcode


def functional_header_to_gcode():
    gcode = ''
    gcode += minimal_header_to_gcode()
    gcode += f'M104 S{NOZZLE_TEMPERATURE} ; set nozzle temperature\n'
    gcode += f'M140 S{BED_TEMPERATURE} ; set bed temperature\n'
    gcode += 'G28 ; home print head\n'
    gcode += f'M109 S{NOZZLE_TEMPERATURE} ; wait for nozzle temperature\n'
    gcode += f'M190 S{BED_TEMPERATURE} ; wait for bed temperature\n'
    gcode += 'M106 S255 ; fan 100%\n'
    gcode += 'G1 Z5 F1440 ; lift nozzle before priming\n'
    gcode += 'G1 E5 F300 ; prepare nozzle by extruding filament\n'
    gcode += 'G92 E0 ; reset E axis 1\n'
    gcode += 'G92 E0 ; reset E axis 2\n'
    gcode += 'G92 E0 ; reset E axis 3\n'
    gcode += 'G1 E-2 F1800 ; retract filament\n'
    gcode += 'G0 Z5 F1440 ; move to safe Z height\n'
    gcode += 'G0 X10 Y10 F1440 ; safe starting position\n'
    gcode += reset_extrusion()
    return gcode


def footer_to_gcode():
    gcode = ''
    gcode += 'M107 ; turn off fan\n'
    gcode += 'M104 S0 ; turn off nozzle heating\n'
    gcode += 'M140 S0 ; turn off bed heating\n'
    gcode += 'G1 E-2 F1800 ; retract filament\n'
    gcode += f'G0 Z{BED_SIZE_Z} F{FEEDRATE_MOVE} ; move print head all the way up\n'
    gcode += f'G0 X0 Y{BED_SIZE_Y} F{FEEDRATE_MOVE} ; move head left and bed forward\n'
    return gcode


def centered_square_to_gcode(size=40, functional_e_values=True):
    global CURRENT_E
    CURRENT_E = 0.0

    half = size / 2
    coords = [
        (-half, -half),
        ( half, -half),
        ( half,  half),
        (-half,  half),
        (-half, -half),
    ]

    if functional_e_values:
        return coords_to_gcode(coords, BASE_Z_OFFSET, FEEDRATE_OUTER, reduce_size=True)

    # For 3.1.1 the assignment explicitly allows E += 1 per printed side.
    gcode = ''
    start_x = 60 - half
    start_y = 70 - half
    gcode += f'G0 X{start_x:.3f} Y{start_y:.3f} Z{BASE_Z_OFFSET:.3f} F{FEEDRATE_MOVE}\n'

    e = 0
    for x, y in coords[1:]:
        e += 1
        gcode += f'G1 X{x + 60:.3f} Y{y + 70:.3f} Z{BASE_Z_OFFSET:.3f} E{e:.3f} F{FEEDRATE_OUTER}\n'

    return gcode

""" helper to streamline handling different types of shapely shapes and convert to coordinates """
def shape_to_gcode(shape, z_height: float, feedrate: float, reduce_size = True):
    if type(shape) is shapely.LineString:
        return coords_to_gcode(shape.coords, z_height, feedrate, reduce_size)
    elif type(shape) is shapely.Polygon:
        gcode = coords_to_gcode(shape.exterior.coords, z_height, feedrate, reduce_size)
        for interior in shape.interiors:
            gcode += coords_to_gcode(interior.coords, z_height, feedrate, reduce_size)
        return gcode
    elif type(shape) is shapely.LinearRing:
        return coords_to_gcode(shape.coords, z_height, feedrate, reduce_size)
    elif type(shape) is shapely.MultiLineString:
        return ''.join([coords_to_gcode(geom.coords, z_height, feedrate, reduce_size) for geom in shape.geoms])
    elif type(shape) is shapely.MultiPolygon:
        gcode = ''
        for geom in shape.geoms:
            gcode += coords_to_gcode(geom.exterior.coords, z_height, feedrate, reduce_size)
            for interior in geom.interiors:
                gcode += coords_to_gcode(interior.coords, z_height, feedrate, reduce_size) 
        return gcode 
    else:
        raise TypeError(f'Unsupported shape type: {type(shape)}! Shape: {shape}')

# -----------------------------------------------------------
# Main script

if __name__ == "__main__":
    args = parse_args()
    # load mesh from disk or create simple uv sphere
    filename = args.filename
    mesh = load_mesh_from_file(filename) if filename != "sphere.stl" else trimesh.creation.uv_sphere(radius=10)
    translation_mat = transformations.translation_matrix([0,0,-mesh.bounds[0][2]])
    mesh.apply_transform(translation_mat)

    np.set_printoptions(precision=5, suppress=True)
    print(f'vertices: {mesh.vertices.shape}')
    print(f'faces: {mesh.faces.shape}')
    print(f'lower bounds: {mesh.bounds[0]} / upper bounds: {mesh.bounds[1]}')
    print(f'centroid: {mesh.centroid}')
    #mesh.show()

    # Write G-code to file
    with open(os.path.basename(os.path.splitext(filename)[0] + '.gcode'), 'w') as file:

        # -----------------------------------------
        # write G-code header

        file.write(';Header start\n')
        file.write(functional_header_to_gcode())

        # -----------------------------------------
        # write layers to G-code

        file.write(';Layer 1 start\n')

        # Example for task 3.1.3: create an arbitrary 2D shape with shapely
        # and convert it to executable G-code.
        shape = shapely.Polygon([
            (-30, -20),
            (0, -45),
            (30, -20),
            (20, 30),
            (-20, 30),
        ])

        # Optional debug output: creates an SVG of the shape.
        write_svg(shape, 'shape_functional.svg')

        file.write(shape_to_gcode(shape, BASE_Z_OFFSET, FEEDRATE_OUTER, reduce_size=True))

        # -----------------------------------------
        # write G-code footer
        
        file.write(';Footer start\n')
        file.write(footer_to_gcode())

    # Additionally create the two square files required in task 3.1.1 and 3.1.2.
    with open('square_simple.gcode', 'w') as square_simple:
        square_simple.write(';Header start\n')
        square_simple.write(minimal_header_to_gcode())
        square_simple.write(';Square start\n')
        square_simple.write(centered_square_to_gcode(size=40, functional_e_values=False))

    with open('square_functional.gcode', 'w') as square_functional:
        square_functional.write(';Header start\n')
        square_functional.write(functional_header_to_gcode())
        square_functional.write(';Square start\n')
        square_functional.write(centered_square_to_gcode(size=40, functional_e_values=True))
        square_functional.write(';Footer start\n')
        square_functional.write(footer_to_gcode())

    with open('shape_functional.gcode', 'w') as shape_functional:
        shape_functional.write(';Header start\n')
        shape_functional.write(functional_header_to_gcode())
        shape_functional.write(';Shape start\n')
        shape_functional.write(shape_to_gcode(shape, BASE_Z_OFFSET, FEEDRATE_OUTER, reduce_size=True))
        shape_functional.write(';Footer start\n')
        shape_functional.write(footer_to_gcode())

    
    
    






        

        
