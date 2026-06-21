import os
import argparse
from scipy.spatial import Voronoi
import random
import numpy as np
import trimesh
from trimesh import transformations
import shapely
import shapely.affinity
from shapely.plotting import plot_polygon
import matplotlib.pyplot as plt

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
INNER_WALLS = 2
INFILL_DENSITY = 0.25

NOZZLE_TEMPERATURE = 200
BED_TEMPERATURE = 60

# -----------------------------------------------------------
# Global G-code state

current_e_position = 0.0
current_head_x = None
current_head_y = None

last_x = None
last_y = None
last_z = None
last_e = None
last_f = None

# -----------------------------------------------------------
# Argument parsing


def parse_args():
    parser = argparse.ArgumentParser(description="slice an stl model.")
    parser.add_argument(
        "filename",
        nargs="?",
        default="sphere.stl",
        help="path to stl model. If omitted, a sphere is generated.",
    )
    parser.add_argument(
        "-a",
        "--adhesion",
        default="none",
        choices=["none", "skirt", "brim"],
        help="Bed adhesion type.",
    )
    parser.add_argument(
        "-i",
        "--infill",
        default="none",
        choices=["none", "basic", "alternating", "quads", "freestyle"],
        help="Infill type.",
    )
    parser.add_argument("-d", "--density", default=25, type=int, help="Infill density in percent.")
    parser.add_argument("-r", "--reduce_size", action="store_true")
    parser.add_argument("-s", "--supports", action="store_true")
    parser.add_argument(
        "--generate",
        default="all",
        choices=[
            "all",
            "3.1",
            "3.2",
            "3.3",
            "3.4",
            "shell",
            "skirt",
            "brim",
            "full",
            "alternating",
            "quads",
            "freestyle",
            "annotated",
            "optimized",
        ],
        help="Which files to generate.",
    )
    return parser.parse_args()

# -----------------------------------------------------------
# 3D mesh helpers


def load_mesh_from_file(filename: str) -> trimesh.Trimesh:
    print(f"Loading {filename}...")
    return trimesh.load(filename)


def create_default_mesh() -> trimesh.Trimesh:
    return trimesh.creation.uv_sphere(radius=10)


def move_mesh_to_build_plate(mesh: trimesh.Trimesh) -> trimesh.Trimesh:
    translation_mat = transformations.translation_matrix([0, 0, -mesh.bounds[0][2]])
    mesh.apply_transform(translation_mat)
    return mesh


def slice_mesh_along_z_axis(mesh: trimesh.Trimesh, z_height: float) -> list[shapely.Polygon]:
    mesh_slice = mesh.section_multiplane(
        plane_origin=[0, 0, 0],
        plane_normal=[0, 0, 1],
        heights=[z_height],
    )[0]
    return mesh_slice.simplify().polygons_full if mesh_slice else []

# -----------------------------------------------------------
# 2D shape helpers


def write_svg(shape, filename: str) -> None:
    with open(os.path.splitext(filename)[0] + ".svg", "w") as f:
        f.write(shape._repr_svg_())


def show_polygon(shape, bounds, label="plot") -> None:
    if type(shape) is shapely.MultiPolygon:
        for p in shape.geoms:
            plot_polygon(p)
    elif type(shape) is shapely.Polygon:
        plot_polygon(shape)
    elif type(shape) is list or type(shape) is np.ndarray:
        for p in shape:
            if type(p) is shapely.MultiPolygon:
                for p1 in p.geoms:
                    plot_polygon(p1)
            else:
                plot_polygon(p)
    else:
        raise TypeError(f"Unsupported shape type: {type(shape)}! Shape: {shape}")

    plt.ylim(bounds[0][1], bounds[1][1])
    plt.xlim(bounds[0][0], bounds[1][0])
    plt.title(label)
    plt.show()


def extract_lines(geometry) -> list[shapely.LineString]:
    if geometry.is_empty:
        return []
    if type(geometry) is shapely.LineString:
        return [geometry]
    if type(geometry) is shapely.MultiLineString:
        return [line for line in geometry.geoms if not line.is_empty]
    if type(geometry) is shapely.GeometryCollection:
        result = []
        for geom in geometry.geoms:
            result.extend(extract_lines(geom))
        return result
    return []


def intersect_line(shape, line: shapely.LineString) -> list[shapely.LineString]:
    with np.errstate(invalid="ignore"):
        if type(shape) is shapely.LineString:
            return extract_lines(shapely.intersection(shapely.Polygon(shape), line))
        if type(shape) is shapely.MultiLineString:
            result = []
            for geom in shape.geoms:
                result.extend(extract_lines(shapely.intersection(shapely.Polygon(geom), line)))
            return result
        if type(shape) is shapely.Polygon:
            return extract_lines(shapely.intersection(shape, line))
        if type(shape) is shapely.MultiPolygon:
            return extract_lines(shapely.intersection(shape, line))
        raise TypeError(f"Unsupported shape type: {type(shape)}! Shape: {shape}")


def union_layer(shape1, shape2) -> list[shapely.Polygon]:
    union = None
    with np.errstate(invalid="ignore"):
        for p in shape1:
            union = p if union is None else shapely.union(union, p)
        for p in shape2:
            union = p if union is None else shapely.union(union, p)
    return [union] if union is not None else []


def difference_layer(shape1, shape2) -> list[shapely.Polygon]:
    union = None
    diff = None

    if len(shape1) == 0 or len(shape2) == 0:
        return shape1

    with np.errstate(invalid="ignore"):
        for p in shape1:
            union = p if union is None else shapely.union(union, p)
        for p in shape2:
            diff = shapely.difference(union, p) if diff is None else shapely.difference(diff, p)
    return [diff] if diff is not None else []


def get_layer_union(layer_shapes):
    result = None
    for shape in layer_shapes:
        result = shape if result is None else shapely.union(result, shape)
    return result

# -----------------------------------------------------------
# G-code state and formatting helpers


def reset_gcode_state() -> None:
    global current_e_position, current_head_x, current_head_y
    global last_x, last_y, last_z, last_e, last_f

    current_e_position = 0.0
    current_head_x = None
    current_head_y = None

    last_x = None
    last_y = None
    last_z = None
    last_e = None
    last_f = None


def filament_cross_section_area() -> float:
    radius = FILAMENT_DIAMETER / 2
    return np.pi * radius**2


def extrusion_for_segment_length(segment_length: float) -> float:
    line_volume = segment_length * NOZZLE_DIAMETER * LAYER_HEIGHT
    return line_volume / filament_cross_section_area()


def format_gcode_command(command, x=None, y=None, z=None, e=None, f=None, optimize=False):
    global last_x, last_y, last_z, last_e, last_f

    parts = [command]

    if x is not None and (not optimize or last_x != x):
        parts.append(f"X{x:.3f}")
        last_x = x
    if y is not None and (not optimize or last_y != y):
        parts.append(f"Y{y:.3f}")
        last_y = y
    if z is not None and (not optimize or last_z != z):
        parts.append(f"Z{z:.3f}")
        last_z = z
    if e is not None and (not optimize or last_e != e):
        parts.append(f"E{e:.5f}")
        last_e = e
    if f is not None and (not optimize or last_f != f):
        parts.append(f"F{int(f)}")
        last_f = f

    return " ".join(parts) + "\n"


def distance_to_head(point) -> float:
    if current_head_x is None or current_head_y is None:
        return 0.0
    x, y = point
    return float(np.sqrt((x - current_head_x) ** 2 + (y - current_head_y) ** 2))


def set_virtual_head_position(x, y) -> None:
    global current_head_x, current_head_y
    current_head_x = x
    current_head_y = y


def optimize_line_direction(line: shapely.LineString) -> shapely.LineString:
    coords = list(line.coords)
    if len(coords) < 2:
        return line
    if distance_to_head(coords[-1]) < distance_to_head(coords[0]):
        return shapely.LineString(coords[::-1])
    return line


def rotate_ring_to_nearest_point(coords):
    coords = list(coords)
    if len(coords) <= 2:
        return coords
    if coords[0] == coords[-1]:
        coords = coords[:-1]

    best_index = 0
    best_distance = float("inf")
    for i, point in enumerate(coords):
        d = distance_to_head(point)
        if d < best_distance:
            best_distance = d
            best_index = i

    rotated = coords[best_index:] + coords[:best_index]
    rotated.append(rotated[0])
    return rotated


def sort_lines_by_distance(lines: list[shapely.LineString]) -> list[shapely.LineString]:
    sorted_lines = []
    remaining_lines = list(lines)

    while remaining_lines:
        best_index = 0
        best_distance = float("inf")
        best_reverse = False

        for i, line in enumerate(remaining_lines):
            coords = list(line.coords)
            if len(coords) < 2:
                continue

            start_distance = distance_to_head(coords[0])
            end_distance = distance_to_head(coords[-1])

            if start_distance < best_distance:
                best_distance = start_distance
                best_index = i
                best_reverse = False
            if end_distance < best_distance:
                best_distance = end_distance
                best_index = i
                best_reverse = True

        selected_line = remaining_lines.pop(best_index)
        if best_reverse:
            selected_line = shapely.LineString(list(selected_line.coords)[::-1])

        sorted_lines.append(selected_line)
        end_x, end_y = list(selected_line.coords)[-1]
        set_virtual_head_position(end_x, end_y)

    return sorted_lines

# -----------------------------------------------------------
# G-code conversion helpers


def coords_to_gcode(coords, z_height: float, feedrate: float, reduce_size=True, optimize=False):
    global current_e_position, current_head_x, current_head_y

    gcode = ""
    coords = list(coords)

    for i, (raw_x, raw_y) in enumerate(coords):
        x = raw_x + BED_SIZE_X / 2 if reduce_size else raw_x
        y = raw_y + BED_SIZE_Y / 2 if reduce_size else raw_y

        if i == 0:
            gcode += format_gcode_command("G0", x=x, y=y, z=z_height, f=FEEDRATE_MOVE, optimize=optimize)
        else:
            previous_raw_x, previous_raw_y = coords[i - 1]
            segment_length = np.sqrt((raw_x - previous_raw_x) ** 2 + (raw_y - previous_raw_y) ** 2)
            current_e_position += extrusion_for_segment_length(segment_length)
            gcode += format_gcode_command(
                "G1",
                x=x,
                y=y,
                z=z_height,
                e=current_e_position,
                f=feedrate,
                optimize=optimize,
            )

        current_head_x = raw_x
        current_head_y = raw_y

    return gcode


def shape_to_gcode(shape, z_height: float, feedrate: float, reduce_size=True, optimize=False):
    if shape.is_empty:
        return ""

    if type(shape) is shapely.LineString:
        line = optimize_line_direction(shape) if optimize else shape
        return coords_to_gcode(line.coords, z_height, feedrate, reduce_size, optimize)

    if type(shape) is shapely.Polygon:
        exterior_coords = rotate_ring_to_nearest_point(shape.exterior.coords) if optimize else shape.exterior.coords
        gcode = coords_to_gcode(exterior_coords, z_height, feedrate, reduce_size, optimize)

        for interior in shape.interiors:
            interior_coords = rotate_ring_to_nearest_point(interior.coords) if optimize else interior.coords
            gcode += coords_to_gcode(interior_coords, z_height, feedrate, reduce_size, optimize)
        return gcode

    if type(shape) is shapely.LinearRing:
        return coords_to_gcode(shape.coords, z_height, feedrate, reduce_size, optimize)

    if type(shape) is shapely.MultiLineString:
        lines = list(shape.geoms)
        if optimize:
            lines = sort_lines_by_distance(lines)
        return "".join(coords_to_gcode(line.coords, z_height, feedrate, reduce_size, optimize) for line in lines)

    if type(shape) is shapely.MultiPolygon:
        polygons = list(shape.geoms)
        if optimize:
            polygons.sort(key=lambda polygon: distance_to_head(polygon.exterior.coords[0]))

        gcode = ""
        for polygon in polygons:
            gcode += shape_to_gcode(polygon, z_height, feedrate, reduce_size, optimize)
        return gcode

    raise TypeError(f"Unsupported shape type: {type(shape)}! Shape: {shape}")

# -----------------------------------------------------------
# Header and footer helpers


def write_minimal_header(file) -> None:
    file.write(";Header start\n")
    file.write("G90 ; absolute mode for X, Y and Z axis\n")
    file.write("M82 ; absolute mode for E axis\n")
    file.write("G21 ; units in millimeters\n")


def write_functional_header(file) -> None:
    file.write(";Header start\n")
    file.write("G90 ; absolute mode for X, Y and Z axis\n")
    file.write("M82 ; absolute mode for E axis\n")
    file.write("G21 ; units in millimeters\n")
    file.write(f"M104 S{NOZZLE_TEMPERATURE} ; set nozzle temperature\n")
    file.write(f"M140 S{BED_TEMPERATURE} ; set bed temperature\n")
    file.write("G28 ; home print head\n")
    file.write(f"M109 S{NOZZLE_TEMPERATURE} ; wait for nozzle temperature\n")
    file.write(f"M190 S{BED_TEMPERATURE} ; wait for bed temperature\n")
    file.write("M106 S255 ; fan 100%\n")
    file.write("G92 E0 ; reset E axis\n")
    file.write("G1 E5 F300 ; prepare nozzle by extruding filament\n")
    file.write("G92 E0 ; reset E axis\n")
    file.write("G92 E0 ; reset E axis\n")
    file.write("G92 E0 ; reset E axis\n")
    file.write("G1 E-2 F1800 ; retract filament\n")
    file.write(f"G0 Z5.000 F{FEEDRATE_MOVE} ; move to safe Z height\n")
    file.write(f"G0 X10.000 Y10.000 F{FEEDRATE_MOVE} ; move to safe starting position\n")
    file.write("G92 E0 ; reset E axis after retract\n")


def write_footer(file, functional=False, optimize=False) -> None:
    global current_e_position

    file.write(";Footer start\n")
    file.write("M107 ; turn off fan\n")
    file.write("M104 S0 ; turn off nozzle heating\n")
    file.write("M140 S0 ; turn off bed heating\n")

    if functional:
        # Reset the E coordinate before retracting. This makes the retract explicit
        # and independent of whether the previous G-code was generated manually or
        # through coords_to_gcode(). We keep M82 absolute extrusion mode.
        file.write("G92 E0 ; reset E axis before retract\n")
        file.write("G1 E-2.00000 F1800 ; retract filament\n")
        file.write("G92 E0 ; reset E axis after retract\n")

        file.write(f"G0 Z{BED_SIZE_Z:.3f} F{FEEDRATE_MOVE} ; move print head all the way up\n")
        file.write(f"G0 X0.000 F{FEEDRATE_MOVE} ; move print head all the way left\n")
        file.write(f"G0 Y{BED_SIZE_Y:.3f} F{FEEDRATE_MOVE} ; move print bed all the way forward\n")

        current_e_position = 0.0

# -----------------------------------------------------------
# 3.1 Simple G-code


def write_square_simple_gcode(filename: str = "square_simple.gcode", square_size: float = 40.0) -> None:
    reset_gcode_state()

    center_x = BED_SIZE_X / 2
    center_y = BED_SIZE_Y / 2
    half = square_size / 2
    x_min, x_max = center_x - half, center_x + half
    y_min, y_max = center_y - half, center_y + half
    z = BASE_Z_OFFSET

    with open(filename, "w") as file:
        write_minimal_header(file)
        file.write(";Draw centered square\n")
        file.write(f"G0 X{x_min:.3f} Y{y_min:.3f} Z{z:.3f} F{FEEDRATE_MOVE}\n")
        file.write(f"G1 X{x_max:.3f} Y{y_min:.3f} Z{z:.3f} E1.000 F{FEEDRATE_OUTER}\n")
        file.write(f"G1 X{x_max:.3f} Y{y_max:.3f} Z{z:.3f} E2.000 F{FEEDRATE_OUTER}\n")
        file.write(f"G1 X{x_min:.3f} Y{y_max:.3f} Z{z:.3f} E3.000 F{FEEDRATE_OUTER}\n")
        file.write(f"G1 X{x_min:.3f} Y{y_min:.3f} Z{z:.3f} E4.000 F{FEEDRATE_OUTER}\n")
        file.write(";Footer start\n")


def write_square_functional_gcode(filename: str = "square_functional.gcode", square_size: float = 40.0) -> None:
    reset_gcode_state()

    center_x = BED_SIZE_X / 2
    center_y = BED_SIZE_Y / 2
    half = square_size / 2
    x_min, x_max = center_x - half, center_x + half
    y_min, y_max = center_y - half, center_y + half
    z = BASE_Z_OFFSET

    with open(filename, "w") as file:
        write_functional_header(file)
        file.write(";Draw centered square\n")
        file.write(f"G0 X{x_min:.3f} Y{y_min:.3f} Z{z:.3f} F{FEEDRATE_MOVE}\n")
        file.write(f"G1 X{x_max:.3f} Y{y_min:.3f} Z{z:.3f} E1.000 F{FEEDRATE_OUTER}\n")
        file.write(f"G1 X{x_max:.3f} Y{y_max:.3f} Z{z:.3f} E2.000 F{FEEDRATE_OUTER}\n")
        file.write(f"G1 X{x_min:.3f} Y{y_max:.3f} Z{z:.3f} E3.000 F{FEEDRATE_OUTER}\n")
        file.write(f"G1 X{x_min:.3f} Y{y_min:.3f} Z{z:.3f} E4.000 F{FEEDRATE_OUTER}\n")
        write_footer(file, functional=True)


def write_shape_functional_gcode(filename: str = "shape_functional.gcode") -> None:
    reset_gcode_state()

    shape = shapely.Polygon([
        (-30, 30),
        (30, 30),
        (30, -20),
        (0, -45),
        (-30, -20),
        (-30, 30),
    ])

    write_svg(shape, "debug_shape.svg")

    with open(filename, "w") as file:
        write_functional_header(file)
        file.write(";Draw arbitrary shape\n")
        file.write(shape_to_gcode(shape, BASE_Z_OFFSET, FEEDRATE_OUTER))
        write_footer(file, functional=True)

# -----------------------------------------------------------
# 3.2 Shell and bed adhesion


def find_first_non_empty_layer(mesh):
    z = BASE_Z_OFFSET
    while z <= mesh.bounds[1][2]:
        layer_shapes = slice_mesh_along_z_axis(mesh, z)
        if len(layer_shapes) > 0:
            return z, layer_shapes
        z += LAYER_HEIGHT
    return None, []


def write_bed_adhesion(file, first_layer_shapes, z_height: float, adhesion: str, optimize=False) -> None:
    if adhesion == "none" or z_height is None:
        return

    first_layer_union = get_layer_union(first_layer_shapes)
    if first_layer_union is None or first_layer_union.is_empty:
        return

    file.write(";TYPE:SKIRT\n")

    if adhesion == "skirt":
        skirt_distance = 8.0
        skirt_shape = first_layer_union.buffer(skirt_distance).boundary
        file.write(shape_to_gcode(skirt_shape, z_height, FEEDRATE_OUTER, optimize=optimize))

    elif adhesion == "brim":
        brim_lines = 30
        for i in range(brim_lines):
            brim_distance = (i + 1) * NOZZLE_DIAMETER
            brim_shape = first_layer_union.buffer(brim_distance).boundary
            file.write(shape_to_gcode(brim_shape, z_height, FEEDRATE_OUTER, optimize=optimize))


def write_walls_for_shape(file, shape, z_height: float, optimize=False, annotated=False) -> None:
    if annotated:
        file.write(";TYPE:WALL-OUTER\n")
    else:
        file.write(";Outer wall\n")
    file.write(shape_to_gcode(shape, z_height, FEEDRATE_OUTER, optimize=optimize))

    for wall_index in range(1, INNER_WALLS + 1):
        inner_wall = shape.buffer(-wall_index * NOZZLE_DIAMETER)
        if not inner_wall.is_empty:
            if annotated:
                file.write(";TYPE:WALL-INNER\n")
            else:
                file.write(f";Inner wall {wall_index}\n")
            inner_feedrate = FEEDRATE_INNER * (1.3 if optimize else 1.0)
            file.write(shape_to_gcode(inner_wall, z_height, inner_feedrate, optimize=optimize))


def write_sliced_shell_gcode(mesh, filename: str = "sliced_shell.gcode", adhesion: str = "none") -> None:
    reset_gcode_state()
    max_z = mesh.bounds[1][2]

    with open(filename, "w") as file:
        write_functional_header(file)

        adhesion_z, first_layer_shapes = find_first_non_empty_layer(mesh)
        write_bed_adhesion(file, first_layer_shapes, adhesion_z, adhesion)

        z = BASE_Z_OFFSET
        layer_index = 0
        while z <= max_z:
            file.write(f";LAYER:{layer_index}\n")
            layer_shapes = slice_mesh_along_z_axis(mesh, z)

            for shape in layer_shapes:
                write_walls_for_shape(file, shape, z, annotated=False)

            z += LAYER_HEIGHT
            layer_index += 1

        write_footer(file, functional=True)

# -----------------------------------------------------------
# 3.3 Infill generators


def create_basic_infill(shape, spacing: float = NOZZLE_DIAMETER) -> list[shapely.LineString]:
    if spacing <= 0:
        raise ValueError("spacing must be greater than 0")

    infill_lines = []
    min_x = -BED_SIZE_X / 2
    max_x = BED_SIZE_X / 2

    min_y = -BED_SIZE_Y / 2
    max_y = BED_SIZE_Y / 2

    y = min_y
    while y <= max_y:
        line = shapely.LineString([(min_x, y), (max_x, y)])
        infill_lines.extend(intersect_line(shape, line))
        y += spacing

    return infill_lines


def create_rotated_infill(shape, angle: float, spacing: float) -> list[shapely.LineString]:
    if spacing <= 0:
        raise ValueError("spacing must be greater than 0")

    infill_lines = []
    origin = (0, 0)
    rotated_shape = shapely.affinity.rotate(shape, -angle, origin=origin)
    min_x = -BED_SIZE_X / 2
    max_x = BED_SIZE_X / 2

    min_y = -BED_SIZE_Y / 2
    max_y = BED_SIZE_Y / 2

    y = min_y
    while y <= max_y:
        line = shapely.LineString([(min_x - 20, y), (max_x + 20, y)])
        intersections = intersect_line(rotated_shape, line)

        for intersection in intersections:
            rotated_back = shapely.affinity.rotate(intersection, angle, origin=origin)
            infill_lines.extend(extract_lines(rotated_back))

        y += spacing

    return infill_lines


def create_alternating_infill(shape, layer_index: int, spacing: float = 4.0) -> list[shapely.LineString]:
    angle = 45 if layer_index % 2 == 0 else -45
    return create_rotated_infill(shape, angle, spacing)


def create_quad_infill(shape, spacing: float = 8.0) -> list[shapely.LineString]:
    infill_lines = []
    infill_lines.extend(create_rotated_infill(shape, 45, spacing))
    infill_lines.extend(create_rotated_infill(shape, -45, spacing))
    return infill_lines


def create_rectangle_line(x1, y1, x2, y2):
    return shapely.LineString([(x1, y1), (x2, y2)])

def create_voronoi_infill(shape, layer_index: int, point_count: int = 45) -> list[shapely.LineString]:
    infill_lines = []

    min_x, min_y, max_x, max_y = shape.bounds

    # Same pattern for a few layers, then slightly change it
    random.seed(layer_index // 4)

    points = []

    for _ in range(point_count):
        points.append([
            random.uniform(min_x, max_x),
            random.uniform(min_y, max_y)
        ])

    # Add corner/support points so Voronoi is more stable
    points.extend([
        [min_x, min_y],
        [min_x, max_y],
        [max_x, min_y],
        [max_x, max_y],
        [(min_x + max_x) / 2, min_y],
        [(min_x + max_x) / 2, max_y],
        [min_x, (min_y + max_y) / 2],
        [max_x, (min_y + max_y) / 2],
    ])

    vor = Voronoi(points)

    for ridge in vor.ridge_vertices:
        if -1 in ridge:
            continue

        v1, v2 = ridge

        p1 = vor.vertices[v1]
        p2 = vor.vertices[v2]

        line = shapely.LineString([
            (p1[0], p1[1]),
            (p2[0], p2[1])
        ])

        clipped = shape.intersection(line)

        if clipped.is_empty:
            continue

        if type(clipped) is shapely.LineString:
            infill_lines.append(clipped)

        elif type(clipped) is shapely.MultiLineString:
            for geom in clipped.geoms:
                if not geom.is_empty:
                    infill_lines.append(geom)

    return infill_lines

# -----------------------------------------------------------
# 3.3 / 3.4 Slicer with infill


def create_infill_lines(infill_area, infill_type: str, layer_index: int, optimized=False):
    if infill_area.is_empty:
        return []

    if infill_type == "basic":
        return create_basic_infill(infill_area, spacing=NOZZLE_DIAMETER)

    if infill_type == "alternating":
        return create_alternating_infill(infill_area, layer_index, spacing=4.0)

    if infill_type == "quads":
        return create_quad_infill(infill_area, spacing=8.0)

    if infill_type == "freestyle":
        return create_voronoi_infill(infill_area, layer_index)

    return []


def write_infill_for_shape(file, shape, z_height: float, layer_index: int, infill_type: str, optimize=False, annotated=False):
    # First layers are full infill to create a stable base, as requested in 3.4.2.
    if optimize and layer_index < 3:
        infill_area = shape.buffer(-NOZZLE_DIAMETER)
        infill_lines = create_basic_infill(infill_area, spacing=NOZZLE_DIAMETER) if not infill_area.is_empty else []
    else:
        buffer_distance = NOZZLE_DIAMETER if infill_type == "freestyle" else 3 * NOZZLE_DIAMETER
        infill_area = shape.buffer(-buffer_distance)
        infill_lines = create_infill_lines(infill_area, infill_type, layer_index, optimized=optimize)

    if not infill_lines:
        return

    if optimize:
        infill_lines = sort_lines_by_distance(infill_lines)

    if annotated:
        file.write(";TYPE:FILL\n")
    else:
        file.write(f";{infill_type} infill\n")

    infill_feedrate = FEEDRATE_INFILL * (1.4 if optimize else 1.0)
    for line in infill_lines:
        file.write(shape_to_gcode(line, z_height, infill_feedrate, optimize=optimize))


def write_sliced_infill_gcode(
    mesh,
    filename: str,
    infill_type: str,
    adhesion: str = "none",
    optimize: bool = False,
    annotated: bool = False,
) -> None:
    reset_gcode_state()
    max_z = mesh.bounds[1][2]

    with open(filename, "w") as file:
        file.write(f";Sliced G-code with {infill_type} infill\n")
        file.write(";DO NOT SEND THIS G-CODE TO A PRINTER\n")
        write_functional_header(file)

        adhesion_z, first_layer_shapes = find_first_non_empty_layer(mesh)
        write_bed_adhesion(file, first_layer_shapes, adhesion_z, adhesion, optimize=optimize)

        z = BASE_Z_OFFSET
        layer_index = 0
        while z <= max_z:
            file.write(f";LAYER:{layer_index}\n")
            layer_shapes = slice_mesh_along_z_axis(mesh, z)

            for shape in layer_shapes:
                write_walls_for_shape(file, shape, z, optimize=optimize, annotated=annotated)
                write_infill_for_shape(file, shape, z, layer_index, infill_type, optimize=optimize, annotated=annotated)

            z += LAYER_HEIGHT
            layer_index += 1

        write_footer(file, functional=True, optimize=optimize)

# -----------------------------------------------------------
# File generation presets


def generate_files(mesh, mode: str) -> None:
    if mode in ["all", "3.1"]:
        write_square_simple_gcode("square_simple.gcode")
        write_square_functional_gcode("square_functional.gcode")
        write_shape_functional_gcode("shape_functional.gcode")

    if mode in ["all", "3.2", "shell"]:
        write_sliced_shell_gcode(mesh, "sliced_shell.gcode", adhesion="none")

    if mode in ["all", "3.2", "skirt"]:
        write_sliced_shell_gcode(mesh, "sliced_skirt.gcode", adhesion="skirt")

    if mode in ["all", "3.2", "brim"]:
        write_sliced_shell_gcode(mesh, "sliced_brim.gcode", adhesion="brim")

    if mode in ["all", "3.3", "full"]:
        write_sliced_infill_gcode(mesh, "sliced_full.gcode", infill_type="basic")

    if mode in ["all", "3.3", "alternating"]:
        write_sliced_infill_gcode(mesh, "sliced_alternating.gcode", infill_type="alternating")

    if mode in ["all", "3.3", "quads"]:
        write_sliced_infill_gcode(mesh, "sliced_quads.gcode", infill_type="quads")

    if mode in ["all", "3.3", "freestyle"]:
        write_sliced_infill_gcode(mesh, "sliced_freestyle.gcode", infill_type="freestyle")

    if mode in ["all", "3.4", "annotated"]:
        write_sliced_infill_gcode(
            mesh,
            "sliced_annotated.gcode",
            infill_type="quads",
            optimize=False,
            annotated=True,
        )

    if mode in ["all", "3.4", "optimized"]:
        write_sliced_infill_gcode(
            mesh,
            "sliced_optimized.gcode",
            infill_type="quads",
            optimize=True,
            annotated=True,
        )

# -----------------------------------------------------------
# Main script


if __name__ == "__main__":
    args = parse_args()
    INFILL_DENSITY = args.density / 100

    filename = args.filename
    mesh = create_default_mesh() if filename == "sphere.stl" else load_mesh_from_file(filename)
    mesh = move_mesh_to_build_plate(mesh)

    np.set_printoptions(precision=5, suppress=True)
    print(f"vertices: {mesh.vertices.shape}")
    print(f"faces: {mesh.faces.shape}")
    print(f"lower bounds: {mesh.bounds[0]} / upper bounds: {mesh.bounds[1]}")
    print(f"centroid: {mesh.centroid}")

    generate_files(mesh, args.generate)
    print("Done.")
