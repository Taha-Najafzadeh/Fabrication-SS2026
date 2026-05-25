"""
Labyrinth preprocessing for the OpenSCAD maze assignment.

This script:
1. Reads the maze wall arrays: walls_south and walls_east.
2. Builds valid cell-to-cell connections.
3. Runs BFS from the target cell.
4. Calculates the distance from every cell to the target.
5. Converts distance values into floor heights.
6. Calculates the downhill direction for every cell.
7. Exports OpenSCAD-ready arrays and parameters.
8. Exports max_floor_height and wall_total_height for global wall sizing.

Coordinate convention:
- row = 0 is the top row
- col = 0 is the left column
- target = (row, col)

Required package:
    pip install numpy

Run:
    python labyrinth_preprocessing.py
"""

from collections import deque
import numpy as np


# ------------------------------------------------------------
# 1. Input maze
# ------------------------------------------------------------

# walls_south[r][c] = 1 means there is a wall south of cell (r, c).
# walls_east[r][c] = 1 means there is a wall east of cell (r, c).

walls_south = [
   [ 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0 ],
   [ 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0 ],
   [ 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1 ],
   [ 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1 ],
   [ 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1 ],
   [ 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0 ],
   [ 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0 ],
   [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
]

walls_east = [
   [ 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1 ],
   [ 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1 ],
   [ 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1 ],
   [ 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 ],
   [ 1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 0, 1 ],
   [ 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1 ],
   [ 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1 ],
   [ 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1 ],
]

# Target cell position: target = (row, col)
target = (2, 8)


# ------------------------------------------------------------
# 2. Physical and design parameters
# ------------------------------------------------------------

cell_size_mm = 12.0
slope_step_mm = 1.00
base_floor_thickness_mm = 1.2
wall_thickness_mm = 1.4
wall_height_mm = 7.0
ball_diameter_mm = 6.35
target_hole_diameter_mm = 7.5


# ------------------------------------------------------------
# 3. Maze logic
# ------------------------------------------------------------

def maze_size(walls_south):
    """
    Returns the number of rows and columns in the maze.
    """
    rows = len(walls_south)
    cols = len(walls_south[0])
    return rows, cols


def inside(row, col, rows, cols):
    """
    Checks whether a cell coordinate is inside the maze.
    """
    return 0 <= row < rows and 0 <= col < cols


def has_wall_between(cell_a, cell_b, walls_south, walls_east):
    """
    Returns True if a wall blocks movement between two neighboring cells.
    """
    r1, c1 = cell_a
    r2, c2 = cell_b

    if r2 == r1 + 1 and c2 == c1:
        return walls_south[r1][c1] == 1

    if r2 == r1 - 1 and c2 == c1:
        return walls_south[r2][c2] == 1

    if r2 == r1 and c2 == c1 + 1:
        return walls_east[r1][c1] == 1

    if r2 == r1 and c2 == c1 - 1:
        return walls_east[r1][c2] == 1

    raise ValueError("Cells are not direct neighbors")


def get_neighbors(row, col, walls_south, walls_east):
    """
    Returns all neighboring cells that can be reached without crossing a wall.
    """
    rows, cols = maze_size(walls_south)

    candidates = [
        (row - 1, col),
        (row + 1, col),
        (row, col - 1),
        (row, col + 1),
    ]

    neighbors = []

    for nr, nc in candidates:
        if inside(nr, nc, rows, cols):
            if not has_wall_between((row, col), (nr, nc), walls_south, walls_east):
                neighbors.append((nr, nc))

    return neighbors


def bfs_distances_from_target(walls_south, walls_east, target):
    """
    Calculates the shortest path distance from every cell to the target.

    The search starts at the target and expands outward.
    Cells that cannot reach the target remain -1.
    """
    rows, cols = maze_size(walls_south)
    distances = np.full((rows, cols), -1, dtype=int)

    tr, tc = target

    if not inside(tr, tc, rows, cols):
        raise ValueError("Target cell is outside maze")

    queue = deque([target])
    distances[tr, tc] = 0

    while queue:
        row, col = queue.popleft()

        for nr, nc in get_neighbors(row, col, walls_south, walls_east):
            if distances[nr, nc] == -1:
                distances[nr, nc] = distances[row, col] + 1
                queue.append((nr, nc))

    return distances


def calculate_height_map(distances, slope_step_mm, base_floor_thickness_mm):
    """
    Converts BFS distance values into floor heights.

    The target cell has the lowest height.
    Cells farther from the target are higher.
    """
    heights = np.zeros_like(distances, dtype=float)

    for row in range(distances.shape[0]):
        for col in range(distances.shape[1]):
            distance = distances[row, col]

            if distance < 0:
                heights[row, col] = np.nan
            else:
                heights[row, col] = base_floor_thickness_mm + distance * slope_step_mm

    return heights


def calculate_max_floor_height(heights):
    """
    Returns the highest valid floor height in the maze.
    """
    return float(np.nanmax(heights))


def direction_from_to(cell_a, cell_b):
    """
    Returns the direction from cell_a to neighboring cell_b.
    """
    r1, c1 = cell_a
    r2, c2 = cell_b

    if r2 == r1 - 1 and c2 == c1:
        return "N"

    if r2 == r1 + 1 and c2 == c1:
        return "S"

    if r2 == r1 and c2 == c1 - 1:
        return "W"

    if r2 == r1 and c2 == c1 + 1:
        return "E"

    return "?"


def calculate_flow_directions(walls_south, walls_east, distances, target):
    """
    Calculates the downhill direction for each cell.

    For every cell, the selected direction points to a connected neighbor
    with a smaller distance value.
    """
    rows, cols = distances.shape
    directions = [["X" for _ in range(cols)] for _ in range(rows)]

    for row in range(rows):
        for col in range(cols):

            if distances[row, col] == -1:
                directions[row][col] = "X"
                continue

            if (row, col) == target:
                directions[row][col] = "T"
                continue

            current_distance = distances[row, col]
            neighbors = get_neighbors(row, col, walls_south, walls_east)

            lower_neighbors = [
                (nr, nc)
                for nr, nc in neighbors
                if distances[nr, nc] >= 0 and distances[nr, nc] < current_distance
            ]

            if not lower_neighbors:
                directions[row][col] = "!"
                continue

            best_neighbor = min(
                lower_neighbors,
                key=lambda p: distances[p[0], p[1]]
            )

            directions[row][col] = direction_from_to((row, col), best_neighbor)

    return directions


# ------------------------------------------------------------
# 4. OpenSCAD export
# ------------------------------------------------------------

def python_matrix_to_scad(matrix, decimals=None):
    """
    Converts a Python list or numpy matrix into OpenSCAD array syntax.
    """
    lines = []

    for row in matrix:
        values = []

        for value in row:
            if isinstance(value, str):
                values.append(f'"{value}"')
            elif decimals is not None:
                values.append(f"{float(value):.{decimals}f}")
            else:
                values.append(str(int(value)))

        lines.append("   [ " + ", ".join(values) + " ]")

    return "[\n" + ",\n".join(lines) + "\n]"


def export_scad_include(
    walls_south,
    walls_east,
    distances,
    heights,
    directions,
    target,
    max_floor_height,
    filename="labyrinth_preprocessed.scad"
):
    """
    Exports generated maze data into a .scad file.
    """
    rows, cols = distances.shape

    wall_total_height = max_floor_height + wall_height_mm

    with open(filename, "w", encoding="utf-8") as f:
        f.write("// Auto-generated by labyrinth_preprocessing.py\n")
        f.write("// This file contains preprocessed maze data for OpenSCAD.\n\n")

        f.write(f"rows = {rows};\n")
        f.write(f"cols = {cols};\n")
        f.write(f"target_row = {target[0]};\n")
        f.write(f"target_col = {target[1]};\n\n")

        f.write(f"cell_size = {cell_size_mm};\n")
        f.write(f"wall_thickness = {wall_thickness_mm};\n")
        f.write(f"wall_height = {wall_height_mm};\n")
        f.write(f"ball_diameter = {ball_diameter_mm};\n")
        f.write(f"target_hole_diameter = {target_hole_diameter_mm};\n\n")

        f.write("// Highest floor value in height_map.\n")
        f.write("// Used to create one global wall height.\n")
        f.write(f"max_floor_height = {max_floor_height:.3f};\n\n")

        f.write("// Every wall has this same absolute height from z = 0.\n")
        f.write("// This prevents walls from having different heights per cell.\n")
        f.write("wall_total_height = max_floor_height + wall_height;\n\n")

        f.write("walls_south = ")
        f.write(python_matrix_to_scad(walls_south))
        f.write(";\n\n")

        f.write("walls_east = ")
        f.write(python_matrix_to_scad(walls_east))
        f.write(";\n\n")

        f.write("distance_map = ")
        f.write(python_matrix_to_scad(distances))
        f.write(";\n\n")

        f.write("height_map = ")
        f.write(python_matrix_to_scad(heights, decimals=3))
        f.write(";\n\n")

        f.write("flow_direction = ")
        f.write(python_matrix_to_scad(directions))
        f.write(";\n")


# ------------------------------------------------------------
# 5. Main execution
# ------------------------------------------------------------

def main():
    distances = bfs_distances_from_target(walls_south, walls_east, target)

    heights = calculate_height_map(
        distances,
        slope_step_mm,
        base_floor_thickness_mm
    )

    directions = calculate_flow_directions(
        walls_south,
        walls_east,
        distances,
        target
    )

    max_floor_height = calculate_max_floor_height(heights)

    print("Distance map:")
    print(distances)
    print()

    print("Height map [mm]:")
    print(np.round(heights, 3))
    print()

    print(f"Max floor height [mm]: {max_floor_height:.3f}")
    print()

    print("Flow directions:")
    for row in directions:
        print(row)
    print()

    if np.any(distances == -1):
        print("WARNING: Some cells are unreachable from the target.")
        print("Those cells cannot be guaranteed to roll to the target.")

    if any("!" in row for row in directions):
        print("WARNING: Some cells have no downhill neighbor.")
        print("Check the maze walls or target position.")

    export_scad_include(
        walls_south,
        walls_east,
        distances,
        heights,
        directions,
        target,
        max_floor_height,
        filename="labyrinth_preprocessed.scad"
    )

    print("Generated file:")
    print("- labyrinth_preprocessed.scad")


if __name__ == "__main__":
    main()