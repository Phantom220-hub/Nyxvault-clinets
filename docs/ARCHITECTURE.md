# DreamHouse 3D — architecture notes

## Coordinate and unit contract

- 2D canvas coordinates are measured in pixels from the top-left of the drawing viewport.
- The current drawing scale is 48 pixels per metre.
- The canonical editable wall dimensions are millimetres (thickness_mm, height_mm).
- World coordinates in the 3D preview are metres.
- Conversion must go through scripts/building_units.gd; avoid adding ad-hoc conversion constants.

## Wall record (current schema)

A wall dictionary currently contains:

- a: Vector2 start point in canvas pixels.
- b: Vector2 end point in canvas pixels.
- thickness_mm: wall thickness in millimetres.
- height_mm: wall height in millimetres.
- load_bearing: user-assigned classification flag only.
- opening: currently empty, door or window.
- opening_width_mm: opening width.
- opening_offset_mm: distance from wall start to opening centre.
- opening_height_mm: door/window clear height.
- sill_height_mm: window sill elevation.

Future schema additions should include a stable wall ID, wall construction/type, opening records with offsets and dimensions, per-face finishes, level ID, and explicit constraints.

## Current script responsibilities

- main.gd: interface orchestration, floor/project state, 3D preview generation and JSON persistence.
- plan_canvas.gd: 2D drawing, wall selection, endpoint/body dragging and wall property editing.
- building_units.gd: pixel/metre/millimetre conversion and formatting.
- wall_geometry.gd: reusable segment math and basic wall validation.

## Data integrity rules

1. Never persist only the active floor; persist every floor and all editable properties.
2. New fields must have backward-compatible defaults when loading earlier JSON files.
3. Reject invalid/zero-length wall segments before geometry generation.
4. Preserve wall IDs and opening metadata when splitting or moving walls once those systems exist.
5. Do not interpret the load-bearing flag as a structural calculation.
6. Keep visual geometry separate from engineering analysis data.

## Known limitations

The current room-area routine is a preliminary graph-cycle search, not a robust planar subdivision engine. The current 3D scene is rebuilt procedurally and uses simple box meshes. Wall openings can be assigned to a selected wall and their width, offset, height and sill height are editable. Door leaf geometry, frame detailing and collision validation are not implemented. No Godot runtime parse or Android device test has yet been completed in the current development environment.
