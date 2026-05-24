"""
Labyrinth preprocessing for OpenSCAD maze assignment.

What this script does:
1. Reads walls_south and walls_east arrays.
2. Builds valid maze connections.
3. Uses BFS from the target to calculate distance to target.
4. Converts distance into floor height.
5. Calculates downhill flow direction for each cell.
6. Exports an OpenSCAD include file with generated arrays.
7. Creates 2D and optional 3D visualizations.

Coordinate convention:
- row = 0 is the top row
- col = 0 is the left column
- target = (row, col)

Dependencies:
    pip install matplotlib numpy

Usage:
    python labyrinth_preprocessing.py
"""

from collections import deque
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle


# ------------------------------------------------------------
# 1. Input maze
# ------------------------------------------------------------

# Small 3x3 test maze from the assignment
walls_south = [
    [1, 0, 0],
    [0, 1, 0],
    [1, 1, 1]
];

walls_east = [
    [0, 1, 1],
    [1, 0, 1],
    [0, 0, 1]
];


# Choose target cell: row, col
# For this small maze, bottom-right is a simple target.
target = (2, 2)

# Physical / design parameters
cell_size_mm = 12.0
slope_step_mm = 1.50
base_floor_thickness_mm = 1.2
wall_thickness_mm = 1.4
wall_height_mm = 7.0
ball_diameter_mm = 6.35
target_hole_diameter_mm = 7.5


# ------------------------------------------------------------
# 2. Maze logic
# ------------------------------------------------------------

def maze_size(walls_south):
    rows = len(walls_south)
    cols = len(walls_south[0])
    return rows, cols


def inside(row, col, rows, cols):
    return 0 <= row < rows and 0 <= col < cols


def has_wall_between(cell_a, cell_b, walls_south, walls_east):
    """
    Returns True if a wall blocks movement between two neighboring cells.
    """
    r1, c1 = cell_a
    r2, c2 = cell_b

    # cell_b is south of cell_a
    if r2 == r1 + 1 and c2 == c1:
        return walls_south[r1][c1] == 1

    # cell_b is north of cell_a
    if r2 == r1 - 1 and c2 == c1:
        return walls_south[r2][c2] == 1

    # cell_b is east of cell_a
    if r2 == r1 and c2 == c1 + 1:
        return walls_east[r1][c1] == 1

    # cell_b is west of cell_a
    if r2 == r1 and c2 == c1 - 1:
        return walls_east[r1][c2] == 1

    raise ValueError("Cells are not direct neighbors")


def get_neighbors(row, col, walls_south, walls_east):
    """
    Returns all connected neighbor cells without crossing walls.
    """
    rows, cols = maze_size(walls_south)
    candidates = [
        (row - 1, col),  # north
        (row + 1, col),  # south
        (row, col - 1),  # west
        (row, col + 1),  # east
    ]

    result = []
    for nr, nc in candidates:
        if inside(nr, nc, rows, cols):
            if not has_wall_between((row, col), (nr, nc), walls_south, walls_east):
                result.append((nr, nc))

    return result


def bfs_distances_from_target(walls_south, walls_east, target):
    """
    Calculates shortest path distance from every cell to target.
    Unreachable cells stay as -1.
    """
    rows, cols = maze_size(walls_south)
    distances = np.full((rows, cols), -1, dtype=int)

    tr, tc = target
    if not inside(tr, tc, rows, cols):
        raise ValueError("Target cell is outside maze")

    queue = deque()
    queue.append(target)
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
    Converts BFS distance into printable floor height.

    Target cell has the lowest floor height.
    Farther cells are higher.
    """
    heights = np.zeros_like(distances, dtype=float)

    for row in range(distances.shape[0]):
        for col in range(distances.shape[1]):
            d = distances[row, col]
            if d < 0:
                heights[row, col] = np.nan
            else:
                heights[row, col] = base_floor_thickness_mm + d * slope_step_mm

    return heights


def direction_from_to(cell_a, cell_b):
    """
    Direction from cell_a to neighboring cell_b.
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
    For each cell, finds the connected neighbor with smaller distance.
    That is the downhill direction.
    """
    rows, cols = distances.shape
    directions = [["X" for _ in range(cols)] for _ in range(rows)]

    for row in range(rows):
        for col in range(cols):
            if distances[row, col] == -1:
                directions[row][col] = "X"  # unreachable
                continue

            if (row, col) == target:
                directions[row][col] = "T"  # target
                continue

            current_distance = distances[row, col]
            neighbors = get_neighbors(row, col, walls_south, walls_east)

            lower_neighbors = [
                (nr, nc)
                for nr, nc in neighbors
                if distances[nr, nc] >= 0 and distances[nr, nc] < current_distance
            ]

            if not lower_neighbors:
                directions[row][col] = "!"  # problem: local trap
                continue

            # In a normal maze, usually there is one best lower neighbor.
            # If there are several, choose the lowest distance.
            best = min(lower_neighbors, key=lambda p: distances[p[0], p[1]])
            directions[row][col] = direction_from_to((row, col), best)

    return directions


# ------------------------------------------------------------
# 3. Visualization
# ------------------------------------------------------------

def draw_maze(ax, walls_south, walls_east, cell_size=1.0, line_width=2.0):
    rows, cols = maze_size(walls_south)

    # Outer north boundary
    ax.plot([0, cols * cell_size], [0, 0], linewidth=line_width, color="black")

    # Outer west boundary
    ax.plot([0, 0], [0, rows * cell_size], linewidth=line_width, color="black")

    for row in range(rows):
        for col in range(cols):
            x = col * cell_size
            y = row * cell_size

            # South wall
            if walls_south[row][col] == 1:
                ax.plot(
                    [x, x + cell_size],
                    [y + cell_size, y + cell_size],
                    linewidth=line_width,
                    color="black",
                )

            # East wall
            if walls_east[row][col] == 1:
                ax.plot(
                    [x + cell_size, x + cell_size],
                    [y, y + cell_size],
                    linewidth=line_width,
                    color="black",
                )


def visualize_2d(walls_south, walls_east, distances, heights, directions, target, filename="labyrinth_2d.png"):
    rows, cols = distances.shape

    fig, ax = plt.subplots(figsize=(cols * 1.1, rows * 1.1))

    # Color by height
    image = ax.imshow(heights, origin="upper")
    plt.colorbar(image, ax=ax, label="Floor height [mm]")

    draw_maze(ax, walls_south, walls_east, cell_size=1.0, line_width=2.5)

    # Text labels and arrows
    arrow_vectors = {
        "N": (0, -0.28),
        "S": (0, 0.28),
        "W": (-0.28, 0),
        "E": (0.28, 0),
    }

    for row in range(rows):
        for col in range(cols):
            x = col + 0.5
            y = row + 0.5

            d = distances[row, col]
            h = heights[row, col]
            direction = directions[row][col]

            if d >= 0:
                ax.text(
                    x,
                    y - 0.22,
                    f"d={d}",
                    ha="center",
                    va="center",
                    fontsize=8,
                    color="white",
                    weight="bold",
                )
                ax.text(
                    x,
                    y + 0.20,
                    f"{h:.2f} mm",
                    ha="center",
                    va="center",
                    fontsize=7,
                    color="white",
                )

            if direction in arrow_vectors:
                dx, dy = arrow_vectors[direction]
                ax.arrow(
                    x,
                    y,
                    dx,
                    dy,
                    head_width=0.08,
                    head_length=0.08,
                    length_includes_head=True,
                    color="white",
                    linewidth=2,
                )

    # Target marker
    tr, tc = target
    ax.add_patch(Circle((tc + 0.5, tr + 0.5), 0.18, color="red"))
    ax.text(tc + 0.5, tr + 0.5, "T", ha="center", va="center", color="white", weight="bold")

    ax.set_xticks(np.arange(cols + 1))
    ax.set_yticks(np.arange(rows + 1))
    ax.set_xlim(0, cols)
    ax.set_ylim(rows, 0)
    ax.set_aspect("equal")
    ax.set_title("Labyrinth preprocessing: height map + downhill directions")
    ax.set_xlabel("Column")
    ax.set_ylabel("Row")

    plt.tight_layout()
    plt.savefig(filename, dpi=200)
    plt.close(fig)


def visualize_3d(heights, filename="labyrinth_3d.png"):
    rows, cols = heights.shape

    x = np.arange(cols)
    y = np.arange(rows)
    X, Y = np.meshgrid(x, y)

    fig = plt.figure(figsize=(8, 6))
    ax = fig.add_subplot(111, projection="3d")

    ax.plot_surface(X, Y, heights, edgecolor="black", linewidth=0.5, alpha=0.85)

    ax.set_title("Approximate 3D floor height map")
    ax.set_xlabel("Column")
    ax.set_ylabel("Row")
    ax.set_zlabel("Height [mm]")
    ax.invert_yaxis()

    plt.tight_layout()
    plt.savefig(filename, dpi=200)
    plt.close(fig)


# ------------------------------------------------------------
# 4. OpenSCAD export
# ------------------------------------------------------------

def python_matrix_to_scad(matrix, decimals=None):
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
    filename="labyrinth_preprocessed.scad",
):
    rows, cols = distances.shape

    with open(filename, "w", encoding="utf-8") as f:
        f.write("// Auto-generated by labyrinth_preprocessing.py\n")
        f.write("// Include this file in your OpenSCAD model.\n\n")

        f.write(f"rows = {rows};\n")
        f.write(f"cols = {cols};\n")
        f.write(f"target_row = {target[0]};\n")
        f.write(f"target_col = {target[1]};\n\n")

        f.write(f"cell_size = {cell_size_mm};\n")
        f.write(f"wall_thickness = {wall_thickness_mm};\n")
        f.write(f"wall_height = {wall_height_mm};\n")
        f.write(f"ball_diameter = {ball_diameter_mm};\n")
        f.write(f"target_hole_diameter = {target_hole_diameter_mm};\n\n")

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
    heights = calculate_height_map(distances, slope_step_mm, base_floor_thickness_mm)
    directions = calculate_flow_directions(walls_south, walls_east, distances, target)

    print("Distance map:")
    print(distances)
    print()

    print("Height map [mm]:")
    print(np.round(heights, 3))
    print()

    print("Flow directions:")
    for row in directions:
        print(row)
    print()

    if np.any(distances == -1):
        print("WARNING: Some cells are unreachable from the target.")
        print("Those cells cannot be guaranteed to roll to the target.")

    if any("!" in row for row in directions):
        print("WARNING: Some cells have no downhill neighbor. Check the maze or target.")

    export_scad_include(
        walls_south,
        walls_east,
        distances,
        heights,
        directions,
        target,
        filename="labyrinth_preprocessed.scad",
    )

    visualize_2d(
        walls_south,
        walls_east,
        distances,
        heights,
        directions,
        target,
        filename="labyrinth_2d.png",
    )

    visualize_3d(
        heights,
        filename="labyrinth_3d.png",
    )

    print("Generated files:")
    print("- labyrinth_preprocessed.scad")
    print("- labyrinth_2d.png")
    print("- labyrinth_3d.png")


if __name__ == "__main__":
    main()
