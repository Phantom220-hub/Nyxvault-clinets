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
- [~] Split intersecting non-collinear wall segments into shared T/cross nodes; rendered miters, collinear overlap resolution and opening/junction conflict resolution remain.
- [~] Move connected wall components and propagate endpoint moves through shared endpoints; junctions and arbitrary topology still need device/runtime validation.
- [~] Split selected walls and merge a single collinear neighbor with matching basic properties; splitting across openings is rejected and advanced layer/finish compatibility remains.
- [~] Numeric wall creation by X/Y, length and arbitrary angle; numeric angle editing of existing walls and constrained dimension chains remain.
- [~] Toggleable wall dimension strings with extension lines and end ticks; room/opening dimension chains remain.
- [~] Auto room labels, bounded-face area and perimeter totals; editable room names, net area and complex/concave topology remain.
- [ ] Wall construction layers and different finish materials on each face.
- [ ] Drafting layers for walls, doors, windows, furniture, electrical and plumbing.
- [~] Copy, vertical-axis mirror and normal-direction array for selected wall; multi-object transforms, alignment and snapping remain.
- [~] Undo/redo covers wall creation, splitting, merging, copy, mirror, array and network noding; furniture and all project entity operations remain.

## 2. Direct 3D editing
- [~] 3D scene generation from current 2D walls.
- [~] Orbit camera and mouse-wheel zoom.
- [~] Furniture selection and direct floor-plane movement.
- [~] 3D wall selection by projected wall midpoint with selection highlight; full ray/mesh picking remains.
- [~] Open the wall property/opening inspector from a wall selected in 3D; direct 3D wall creation, dragging and endpoint editing remain.
- [ ] Numeric X/Y/Z position and dimension inspector.
- [ ] Direct furniture rotate/scale gestures.
- [ ] Multi-select, group/ungroup, duplicate and lock.
- [~] Two-finger camera pan/pinch zoom and one-finger orbit; requires device gesture-conflict testing.
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
- [~] Flat and simple gable roof visuals from the top-floor wall bounding box; mono-pitch, hip, mansard and detailed roof geometry remain.
- [ ] Roof pitch, ridge, eaves, overhang and roof materials.
- [ ] Roof hide/show and building cutaway.

## 5. Multi-storey buildings and stairs
- [~] Add/switch floors with independent walls and furniture.
- [~] Floor rename and independent floor/slab height settings are stored and used for vertical stacking; duplication, reorder, visibility and custom elevation remain.
- [ ] Basements and attic levels.
- [~] Basic parametric straight stair object in the furniture library; floor-to-floor stair connection, L/U/spiral types and code checks remain.
- [ ] Stair width, rise, run, tread count, landing and handrails.
- [ ] Validate stair connection between floor elevations.
- [ ] Building sections and exploded floor view.

## 6. Furniture and object library
- [~] Basic sofa, bed, table, chair and wardrobe primitives.
- [~] Procedural furniture/equipment library: sofa, bed, table, chair, wardrobe, kitchen unit, fridge, toilet, bath, sink, plant, lamp, stairs, outlet, switch and radiator; realistic external assets remain.
- [ ] Kitchen cabinets, counters, sink, hob, refrigerator and oven.
- [ ] Bath, shower, toilet, vanity, mirror and washing machine.
- [ ] Desk, computer, shelves, curtains, rugs, plants and decor.
- [ ] Real-world dimensions, per-object materials and anchor points.
- [ ] Replace model while preserving object transform and metadata.
- [ ] Import supported external 3D formats and manage a local asset library.

## 7. Electrical and lighting design
- [~] Basic sun and fill lighting in the 3D preview.
- [~] Basic visual outlet/switch/radiator symbols as placed objects; circuit routing, panels, schedules and electrical validation remain.
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
- [~] Toggleable rectangular site boundary with editable width/depth, lawn, fence, gate gap, path and procedural trees; terrain elevation and irregular parcels remain.
- [ ] Fence, gates and pedestrian gate.
- [ ] Paths, driveway and parking.
- [ ] Garage, terrace, balcony and pool.
- [ ] Lawn, trees, planting and site lighting.
- [ ] Terrain slopes and level changes.

## 10. Measurement and quantities
- [~] Pixel-to-metre conversion at 48 px per metre.
- [x] Shared px/mm/m conversion utility.
- [x] Two-point measurement tool reports distance and angle; dimension chains and persistent annotations remain.
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
- [~] Persistent offline settings for grid snap, angle snap, dimensions and 3D shadows; graphics presets and device profiling remain.
- [ ] Realistic asset quality without exceeding target Android memory budgets.

## 12. Drawings and documentation
- [ ] Scaled floor plans, furniture plans and roof plans.
- [ ] Elevations and building sections.
- [ ] Dimensioned sheets, title block, symbols and legend.
- [ ] Door/window schedule and room schedule.
- [ ] Electrical and plumbing drawings.
- [ ] Material specification.
- [~] Basic fitted A4 landscape PDF export for the current floor's wall centerlines and PNG viewport screenshot; sheet templates, symbols, dimension annotations and raster crop remain.
- [~] Basic DXF R12 line export for current-floor wall centerlines; DXF import, thickness/blocks/dimensions and compatibility tests remain.
- [ ] Supported BIM exchange format and explicit interoperability tests.
- [ ] Print layout, sheet size, scale and line weights.

## 13. Material quantities and cost estimates
- [~] Wall finish area with door/window deductions and editable unit prices in a preliminary TJS estimator; multi-material layers and detailed takeoff remain.
- [ ] Floor and ceiling area.
- [ ] Tile, wallpaper and flooring quantities with waste factors.
- [ ] Concrete/volume estimates only where geometry and assumptions support them.
- [ ] Door/window counts and schedule.
- [~] User-entered unit prices for wall finish, floor finish, doors and windows in TJS; currency selection and full cost catalog remain.
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
- [~] Startup home menu, tutorial and furniture/site/roof primitives; reusable complete house templates remain.
- [ ] First-person walkthrough with collision and door interaction.
- [ ] Interior/exterior mode and lighting controls.
- [ ] Compare design variants.
- [ ] Saved camera shots, render gallery and video walkthrough.
- [ ] Custom model library.
- [ ] Responsive phone/tablet layouts and onboarding hints.

## 16. Quality, validation and Android delivery
- [ ] Run Godot headless editor parse/import check.
- [~] Headless tests cover units, angular snapping, connected wall moves, polygon metrics, bounded faces, splitting, T/cross noding, opening protection and collinear merging; the feature branch still requires CI validation.
- [ ] Save/load round-trip tests, including old schema versions.
- [~] Implemented 2D pinch/pan and mouse-wheel zoom plus 3D one-finger orbit/two-finger pan/pinch; real-device gesture testing remains.
- [~] Automated tests cover common connected-wall and intersection cases; near-coincident coordinates, collinear overlaps, complex openings, wall-face miters, floor joins and camera picking still need dedicated tests.
- [ ] Profile CPU/GPU/RAM on low-end Android hardware.
- [ ] Validate Android permissions and file import/export.
- [ ] Build signed/release APK and verify install/launch on target devices.
- [ ] Maintain CI status and publish only tested builds.

## Engineering boundary
A visual label such as “load-bearing” is metadata, not proof of structural capacity. The application must not certify structural safety, electrical safety, fire safety or code compliance without validated calculation methods, applicable jurisdictional rules and qualified professional review. Quantity and cost outputs must expose assumptions and be labelled estimates.

## AI scope
AI features are intentionally excluded from this roadmap.
