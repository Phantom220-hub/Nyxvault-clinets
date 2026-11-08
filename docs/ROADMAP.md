# DreamHouse 3D — engineering roadmap

This file is the acceptance checklist for the non-AI product scope. A feature is not marked complete merely because a button or placeholder exists.

Legend:
- [x] Implemented in source; still requires runtime/device verification where noted.
- [~] Partial prototype; not production-ready.
- [ ] Not implemented.

## 1. Architectural 2D drafting
- [~] Draw wall segments with grid snapping.
- [x] Select a wall by touch/click.
- [x] Drag a whole wall and drag either endpoint.
- [x] Snapshot-based wall undo/redo (bounded history per active floor).
- [x] Snap newly drawn endpoints to existing wall endpoints.
- [x] Edit wall length in millimetres.
- [x] Store wall thickness and height in millimetres.
- [x] Store a load-bearing classification flag (classification only, not structural analysis).
- [~] Display wall thickness in plan.
- [~] Bounded-face detection for simple planar wall graphs, including split faces; concave/overlapping/near-coincident topology still needs validation.
- [ ] Automatic wall junction resolution and T/L/cross junctions.
- [~] Move connected wall components and propagate endpoint moves through shared endpoints; junctions and arbitrary topology still need device/runtime validation.
- [ ] Split/merge wall segments while preserving openings and metadata.
- [ ] Exact angle constraints and numeric angle entry.
- [~] Toggleable wall dimension strings with extension lines and end ticks; room/opening dimension chains remain.
- [~] Auto room labels, bounded-face area and perimeter totals; editable room names, net area and complex/concave topology remain.
- [ ] Wall construction layers and different finish materials on each face.
- [ ] Drafting layers for walls, doors, windows, furniture, electrical and plumbing.
- [ ] Copy, mirror, array and alignment tools.
- [ ] Undo/redo command history for all edit operations.

## 2. Direct 3D editing
- [~] 3D scene generation from current 2D walls.
- [~] Orbit camera and mouse-wheel zoom.
- [~] Furniture selection and direct floor-plane movement.
- [~] 3D wall selection by projected wall midpoint with selection highlight; full ray/mesh picking remains.
- [~] Open the wall property/opening inspector from a wall selected in 3D; direct 3D wall creation, dragging and endpoint editing remain.
- [ ] Numeric X/Y/Z position and dimension inspector.
- [ ] Direct furniture rotate/scale gestures.
- [ ] Multi-select, group/ungroup, duplicate and lock.
- [ ] Two-finger camera pan/zoom and one-finger orbit with gesture arbitration.
- [~] Perspective/orthographic projection, top/front/side camera presets and camera state saved with the project; named camera bookmarks remain.
- [ ] Front/side/top/interior camera presets.
- [~] Furniture drag updates the selected 3D node without rebuilding the full scene; incremental wall/object scene updates remain.

## 3. Walls, doors and windows
- [~] Basic wall solids with configurable height/thickness.
- [~] Basic door/window gap for a newly created wall.
- [~] Set an opening on a selected wall and edit its width, along-wall offset, height and sill height; full drag handles and opening collision checks remain.
- [~] Persist opening offset from wall start, opening width/height and sill height; editable head-height constraints and validation remain.
- [ ] Door leaf, frame, hinge side and swing direction.
- [ ] Sliding, double, entrance and interior door types.
- [ ] Window frame, glazing, sill and configurable transparency.
- [ ] Wall layers, exterior/interior finishes and structural core.
- [ ] Wall visibility and cutaway controls.

## 4. Floors, ceilings and roofs
- [~] Basic stacked floor plates.
- [~] Independent floor-to-floor height and slab thickness; explicit absolute elevation editing remains.
- [ ] Floor finish zones and thickness.
- [ ] Flat, suspended and multi-level ceilings.
- [ ] Flat, mono-pitch, gable, hip and mansard roofs.
- [ ] Roof pitch, ridge, eaves, overhang and roof materials.
- [ ] Roof hide/show and building cutaway.

## 5. Multi-storey buildings and stairs
- [~] Add/switch floors with independent walls and furniture.
- [~] Floor rename and independent floor/slab height settings are stored and used for vertical stacking; duplication, reorder, visibility and custom elevation remain.
- [ ] Basements and attic levels.
- [ ] Straight, L, U and spiral staircases.
- [ ] Stair width, rise, run, tread count, landing and handrails.
- [ ] Validate stair connection between floor elevations.
- [ ] Building sections and exploded floor view.

## 6. Furniture and object library
- [~] Basic sofa, bed, table, chair and wardrobe primitives.
- [ ] Realistic model library for living room, bedroom, kitchen and bathroom.
- [ ] Kitchen cabinets, counters, sink, hob, refrigerator and oven.
- [ ] Bath, shower, toilet, vanity, mirror and washing machine.
- [ ] Desk, computer, shelves, curtains, rugs, plants and decor.
- [ ] Real-world dimensions, per-object materials and anchor points.
- [ ] Replace model while preserving object transform and metadata.
- [ ] Import supported external 3D formats and manage a local asset library.

## 7. Electrical and lighting design
- [~] Basic sun and fill lighting in the 3D preview.
- [ ] Electrical outlets, switches, panels and lighting fixtures.
- [ ] Symbolic electrical routes and circuit layers.
- [ ] Circuit grouping, labels and connection schedule.
- [ ] Day/night controls, sun azimuth/elevation and lighting intensity.
- [ ] Distinguish visual lighting from code-compliant electrical design.

## 8. Water supply, drainage and heating
- [ ] Cold/hot water routes and risers.
- [ ] Drainage routes, slopes and stacks.
- [ ] Pipe diameters and connection points.
- [ ] Plumbing fixtures and water heater.
- [ ] Radiators and heating routes.
- [ ] Separate water, drainage and heating layers.
- [ ] Engineering checks must be based on applicable local codes.

## 9. Site and landscape
- [ ] Editable site boundary and terrain elevation.
- [ ] Fence, gates and pedestrian gate.
- [ ] Paths, driveway and parking.
- [ ] Garage, terrace, balcony and pool.
- [ ] Lawn, trees, planting and site lighting.
- [ ] Terrain slopes and level changes.

## 10. Measurement and quantities
- [~] Pixel-to-metre conversion at 48 px per metre.
- [x] Shared px/mm/m conversion utility.
- [ ] Dimension tool for distances and angles.
- [ ] Accurate room area/perimeter and building gross/net area.
- [ ] Room volume, floor elevation and wall thickness schedules.
- [ ] Unit preferences, precision and display formatting.
- [ ] Quantity takeoff with opening deductions and explicit formulas.

## 11. Materials and rendering
- [~] Three global colour/material presets.
- [~] Basic directional shadow and procedural sky.
- [ ] PBR wood, stone, brick, concrete, metal, glass and tile assets.
- [ ] Per-face wall finish assignment.
- [ ] Roughness/metallic controls, reflections and ambient occlusion.
- [ ] Day/night environment and saved lighting setups.
- [ ] Fast/high/maximum graphics presets with mobile profiling.
- [ ] Realistic asset quality without exceeding target Android memory budgets.

## 12. Drawings and documentation
- [ ] Scaled floor plans, furniture plans and roof plans.
- [ ] Elevations and building sections.
- [ ] Dimensioned sheets, title block, symbols and legend.
- [ ] Door/window schedule and room schedule.
- [ ] Electrical and plumbing drawings.
- [ ] Material specification.
- [ ] PDF and raster export.
- [ ] DXF import/export.
- [ ] Supported BIM exchange format and explicit interoperability tests.
- [ ] Print layout, sheet size, scale and line weights.

## 13. Material quantities and cost estimates
- [ ] Wall finish area with openings deducted.
- [ ] Floor and ceiling area.
- [ ] Tile, wallpaper and flooring quantities with waste factors.
- [ ] Concrete/volume estimates only where geometry and assumptions support them.
- [ ] Door/window counts and schedule.
- [ ] User-entered unit prices and currency.
- [ ] Cost estimate with visible formulas, waste factors and exclusions.
- [ ] PDF and spreadsheet estimate export.

## 14. Project management and data integrity
- [~] JSON save/load for current walls, furniture and floors.
- [x] Persist wall thickness, height and bearing classification in floor records.
- [ ] Named multi-project manager.
- [ ] Autosave, manual save and recovery snapshots.
- [ ] Versioned schema migrations and corrupt-file recovery.
- [~] Persist wall opening geometry and wall construction properties across floors; materials, layers, roof, stairs, MEP and dimensions remain.
- [ ] Reliable import/export on Android scoped storage.
- [ ] Backup/restore and project comparison.

## 15. Presentation and workflow
- [ ] Editable house templates.
- [ ] First-person walkthrough with collision and door interaction.
- [ ] Interior/exterior mode and lighting controls.
- [ ] Compare design variants.
- [ ] Saved camera shots, render gallery and video walkthrough.
- [ ] Custom model library.
- [ ] Responsive phone/tablet layouts and onboarding hints.

## 16. Quality, validation and Android delivery
- [ ] Run Godot headless editor parse/import check.
- [~] Headless geometry/unit tests now cover units, angular snapping, connected wall moves, polygon metrics and bounded faces; latest complete CI run still pending.
- [ ] Save/load round-trip tests, including old schema versions.
- [ ] Test touch input, screen scaling, rotation and gesture conflicts.
- [~] Automated tests cover basic connected-wall and room-face geometry; wall intersections, openings, floor joins and camera picking still need dedicated tests.
- [ ] Profile CPU/GPU/RAM on low-end Android hardware.
- [ ] Validate Android permissions and file import/export.
- [ ] Build signed/release APK and verify install/launch on target devices.
- [ ] Maintain CI status and publish only tested builds.

## Engineering boundary
A visual label such as “load-bearing” is metadata, not proof of structural capacity. The application must not certify structural safety, electrical safety, fire safety or code compliance without validated calculation methods, applicable jurisdictional rules and qualified professional review. Quantity and cost outputs must expose assumptions and be labelled estimates.

## AI scope
AI features are intentionally excluded from this roadmap.
