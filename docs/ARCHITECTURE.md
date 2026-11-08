# DreamHouse 3D — architecture notes

## Offline-first contract (mandatory)

DreamHouse 3D is a fully local application. Normal app use must work with airplane mode enabled and must never depend on a server, account, API key, cloud storage, remote catalog, online font, remote texture, analytics SDK or network license.

- Android export explicitly disables the INTERNET permission.
- All interface code, geometry, procedural models, materials and default content are bundled in the APK.
- Project creation, editing, undo/redo, floor switching, 2D/3D viewing, calculations, save/load and import/export operate on local device storage only.
- Project files use local JSON. Do not add cloud sync or remote project paths.
- Future furniture/material libraries must ship inside the app or be imported by the user from local files.
- Future PDF/DXF/BIM export, drawing generation, quantity takeoff and validation must run locally.
- No feature may silently fall back to a network service. If an optional local asset is absent, show a local error and keep the rest of the app usable.
- Any proposed network-dependent feature is out of scope unless the owner explicitly changes this contract.

The CI pipeline includes a source scan that rejects common Godot networking APIs and remote URL references in runtime project files. This is a guardrail, not a mathematical proof; the exported APK must still be checked on a real device in airplane mode.

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

The current room-area routine is a preliminary graph-cycle search, not a robust planar subdivision engine. The current 3D scene is rebuilt procedurally and uses simple box meshes. Wall openings can be assigned to a selected wall and their width, offset, height and sill height are editable. Door leaf geometry, frame detailing and collision validation are not implemented. CI has built an Android debug APK, but this is not equivalent to full runtime testing on a physical Android device.
