# SimpleTerrain for Godot 4

A 3D terrain addon for Godot 4 providing sculpting, procedural generation, texture painting, foliage scattering, and mesh/texture export.

---

## Table of Contents

- [Features](#features)
- [Terrain Palette & Asset Dock](#terrain-palette--asset-dock)
- [Editor Workflow](#editor-workflow)
- [Keyboard Shortcuts and Viewport Gestures](#keyboard-shortcuts-and-viewport-gestures)
- [Pattern Library](#pattern-library)
- [Foliage & MultiMesh Scattering](#foliage--multimesh-scattering)
- [Asset Persistence Architecture](#asset-persistence-architecture)
- [Architecture Overview](#architecture-overview)
- [API Reference](#api-reference)
  - [SimpleTerrain3D](#simpleterrain3d)
  - [SimpleTerrainData](#simpleterraindata)
  - [SimpleTerrainFoliageLayer](#simpleterrainfoliagelayer)
  - [SimpleTerrainFoliageSpatialGrid](#simpleterrainfoliagespatialgrid)
- [Code Examples](#code-examples)
  - [1. Creating Terrain via Code](#1-creating-terrain-via-code)
  - [2. Procedural / Runtime Terraforming (Explosion Crater)](#2-procedural--runtime-terraforming-explosion-crater)
  - [3. Runtime Texture Painting (Decal / Path Painting)](#3-runtime-texture-painting-decal--path-painting)
  - [4. Saving and Loading Saved Meshes & Textures](#4-saving-and-loading-saved-meshes--textures)
  - [5. Automatic Slope & Cliff Coloring](#5-automatic-slope--cliff-coloring)
  - [6. Scattering & Managing Foliage Programmatically](#6-scattering--managing-foliage-programmatically)
---

## Features


- **Draggable Scrubbers (`TerrainScrubber`)**:
  - Horizontal drag-scrub controls for `Radius`, `Strength`, `Falloff`, and `Height`.
  - Drag horizontally to adjust, hold <kbd>Shift</kbd> for 0.1x precision, or click to type values directly.

- **Falloff Curve Presets**:
  - Preset brush profiles: **Smooth** (Cosine), **Linear** (Cone), **Spherical** (Dome), and **Flat** (Hard Edge).
  - Inner-ring gizmo indicates the falloff boundary.

- **Pattern & Mask Flyout Popovers**:
  - Clicking the active pattern thumbnail opens a quick flyout with recent stamps, UV tiling, and rotation angle controls.

- **Brush Footprints & Shapes**:
  - 2D footprint masks: Circle Gradient, Square, Patch, Small Dots, X Gradient, and custom PNG imports.
  - Footprint rotation (`0° - 360°`) via toolbar or dock.
  - Modulates color painting, texture stamping, and terrain sculpting.

- **Slope Angle Constraints**:
  - Constrain sculpting and painting within a slope angle range (`[min_slope_deg, max_slope_deg]`).
  - Presets for **All (0°-90°)**, **Flat (<30°)**, and **Cliffs (>35°)**.
  - Toolbar indicator shows when slope filtering is active.

- **Interactive Viewport Brush Gestures**:
  - Hold <kbd>R</kbd> and drag horizontally to resize brush radius.
  - Hold <kbd>Shift + R</kbd> and drag horizontally to adjust brush strength or foliage density.

- **Decal Brush Projector & Dual-Ring Gizmo**:
  - Projects the active brush footprint onto uneven terrain geometry using Godot's `Decal` node.
  - Dual-ring gizmo shows outer radius and inner falloff boundaries.
  - Color-coded by operation mode (Green: Raise, Red: Lower, Blue: Smooth, Orange: Flatten, Purple: Noise, Violet: Paint).
  - Visual feedback when modifier keys (`Shift`, `Ctrl`) are held.

- **Wireframe Visualization**:
  - Viewport wireframe overlay showing terrain topology.
  - Supports **Triangles** or **Quads** grid mode.
  - Configurable wireframe color and optional runtime display.
  - Toggle with toolbar button or `Shift + W`.

- **Viewport Info HUD Overlay**:
  - Floating overlay showing cursor world/local `(X, Z)` coordinates, surface `Height (Y)`, `Slope Angle`, and active tool/layer.
  - Repositionable header bar, toggled via toolbar button or `H`.

- **Axis Lock Constraints (`X` and `Z`)**:
  - Constrain sculpt and paint strokes along a global X or Z axis line (`X` to lock to X, `Z` to lock to Z, `C` to clear).
  - Displays 3D line guides across the terrain.

- **Viewport Radial / Pie Menu**:
  - Mouse-centered radial gesture menu (`Tab` or `~`) for switching tools and toggling options.

- **Terrain Palette (Bottom Dock)**:
  - Dock panel accessible via the bottom panel or toolbar button.
  - **Foliage & Models Tab**: Active foliage layer list, preset library (BinbunGrass 1..10, custom `.tres`, imported models), drag-and-drop model import (`.glb`, `.gltf`, `.tscn`), and real-time layer property inspector.
  - **Textures & Patterns Tab**: Brush shapes gallery, pattern stamp grid, slope constraint controls, and drag-and-drop texture import (`.png`, `.jpg`, `.webp`).
  - **Persistence**: Project-wide registry in `settings.json`, per-user preferences in `user://simple_terrain_editor_state.json`, and layer properties saved in the terrain resource.

- **Terraforming & Sculpting**:
  - Viewport sculpting with real-time mesh deformation.
  - Modes:
    - **Raise**: Elevate terrain vertices.
    - **Lower**: Lower terrain vertices (or hold `Shift` while in Raise mode).
    - **Smooth**: Smooth elevation differences (or hold `Ctrl` while sculpting).
    - **Flatten**: Level terrain to target elevation (`Alt + Click` or eyedropper to sample).
    - **Noise / Detail**: Perturb vertex heights with procedural hash noise.
    - **Terrace / Step**: Quantize elevations into step height intervals.
    - **Ramp / Road Grading**: Two-point line grading between elevations with road width, falloff, crown camber arch, and 3D preview ribbon.
  - Grayscale stencil masks with rotation.
  - Brush spacing and position/angle jitter.
  - Configurable radius, strength, and falloff.

- **Procedural Generation**:
  - Integrated FastNoiseLite terrain generator.
  - Supports Simplex Smooth, Perlin, Cellular/Worley, Simplex, and Value noise types.
  - Configurable frequency, amplitude, octaves, seed, and island edge falloff.
  - Full Undo/Redo support.

- **Automatic Slope & Cliff Coloring**:
  - Textures or colors slopes based on surface angle.
  - Seamless repeating textures (e.g. `Rock Cliff`) or solid color presets.
  - Configurable slope angle threshold and blend transition range.
  - Option to preserve existing painted areas or fill with a ground color.
  - Live auto-coloring while sculpting.

- **Texture Painting & Pattern Library**:
  - Texture painting with UV mapping.
  - **Color Mode**: Color picker with eraser to revert to base terrain color.
  - **Pattern / Stamp Mode**: 8 built-in patterns (Rock Cliff, Cobblestone, Dirt Gravel, Grass Blades, Sand Ripples, Cracked Earth, Soft Radial, Splatter Grunge) and custom image import (`.png`, `.jpg`, `.webp`).
  - UV tiling and rotation angle controls.

- **MultiMesh Foliage Scattering**:
  - Paint, erase, and select/transform modes.
  - **10 Built-in BinbunGrass Presets** with wind shader materials and quad meshes.
  - **Custom 3D Models & Tree Scattering**: Import `.gltf`, `.glb`, `.obj`, and `.tscn` files. Combines multi-mesh hierarchies and preserves surface materials.
  - **Foliage Library**: Configure density, spacing, scale variation, normal alignment, slope limits, elevation offset, and random yaw/tilt.
  - **Spatial Hash Grid**: Enforces minimum instance spacing and fast radius queries for erasing.
  - **Elevation Conforming**: Existing foliage instances automatically conform their Y position when terrain elevation is sculpted.

- **Saving & Exporting**:
  - **Save Terrain Data**: Serializes the `SimpleTerrainData` resource (`.res` or `.tres`).
  - **Export Terrain as glTF**: Exports the terrain mesh and texture to `.glb` or `.gltf`.
  - **Export Terrain Mesh**: Exports the terrain geometry as an `ArrayMesh` (`.tres` or `.res`).
  - **Export Terrain Texture**: Exports the painted texture as a `.png` file.

---

## Terrain Palette & Asset Dock

The **Terrain Palette** is a bottom dock panel for managing foliage layers, brush patterns, and slope settings.

### Opening the Palette
- **Auto-Open on Tool Selection**: Switching to **Foliage Mode** (`G` / `Shift + F`, or pie menu) opens the **Foliage & Models** tab. Switching to **Paint Mode** (`P`, pie menu, or pattern button) opens the **Textures & Patterns** tab.
- Click the **Terrain Palette** tab in Godot's bottom editor panel (beside *Output*, *Debugger*), or
- Click the **Asset Palette** icon button on the 3D viewport toolbar (`AssetDockBtn`).

### 1. Foliage & Models Tab
The Foliage tab features a three-column layout:
- **Active Layers (Left Column)**:
  - Lists foliage layers on the selected terrain.
  - **Selection**: Click any layer to select and activate it for painting.
  - **Instance Count**: Counter badge showing the number of scattered instances in each layer.
  - **Visibility**: Toggle visibility of any foliage layer in the editor viewport.
  - **Deletion**: Delete an active layer directly.
- **Preset & Model Library (Center Column)**:
  - Built-in **BinbunGrass (Presets 1..10)** with wind shaders.
  - Custom `.tres` presets and imported 3D models.
  - **Filter & Search**: Filter by *All Foliage*, *Grass (Binbun)*, or *Imported Models*, with text search.
  - **Add to Terrain**: Double-click any preset card or click **+ Add to Terrain** to add the layer.
- **Layer Inspector (Right Column)**:
  - Configure layer properties:
    - **Density**: Scatter concentration per brush stroke.
    - **Min Spacing**: Minimum spacing enforced by the spatial hash grid.
    - **Scale Min / Max**: Random uniform scale range per instance.
    - **Normal Alignment**: Surface slope alignment factor (0.0 = vertical, 1.0 = normal aligned).
    - **Max Slope (Deg)**: Maximum slope angle for scattering.
    - **Random Tilt**: Random directional tilt in degrees.
    - **Height Offset**: Vertical displacement relative to the terrain mesh.
    - **Cast Shadows**: Shadow casting setting (`Off`, `On`, `Shadows Only`).
  - Modifications synchronize with `SimpleTerrainData.foliage_layers`.

### 2. Textures & Patterns Tab
- **Pattern Grid**: Displays built-in patterns (Rock Cliff, Cobblestone, Dirt Gravel, Grass Blades, Sand Ripples, Cracked Earth, Soft Radial, Splatter Grunge) and custom textures.
- **Activation**: Click any texture card to set the active stamp and switch to **Paint (Texture)** mode.
- **Controls**: UV Tiling and Angle spinboxes directly above the pattern grid.

### 3. Drag-and-Drop Workflow
- **3D Models**: Drag `.glb`, `.gltf`, or `.tscn` files from Godot's FileSystem dock onto the Terrain Palette. The model is imported, registered, and saved as a `.tres` preset in `res://addons/simple_terrain/foliage_presets/`.
- **Textures**: Drag `.png`, `.jpg`, or `.webp` image files onto the Textures tab to register them as active stamp patterns.

---

## Editor Workflow

1. **Add a Terrain Node**:
   - In any 3D scene, add a `SimpleTerrain3D` node (`Add Child Node -> SimpleTerrain3D`).
   - A default 64x64m terrain appears in the viewport.

2. **Open the Toolbar**:
   - Selecting the `SimpleTerrain3D` node displays the **Terrain Editor Toolbar** beneath Godot's 3D viewport toolbar.
   - The primary row offers terrain management, mode switches, and export actions. Activating **Sculpt**, **Paint**, or **Foliage** unfolds a dedicated contextual tool row below it.

3. **Configure, Resize, or Generate**:
   - Click **Terrain -> Resize Terrain...** to adjust physical dimensions and subdivision resolution additively (existing sculpt elevations and painted textures are preserved).
   - Click **Terrain -> New Terrain...** to create a fresh terrain grid.
   - Click **Terrain -> Generate Procedural Noise...** to generate terrain heights with FastNoiseLite.
   - Terrain Size and Resolution can also be adjusted directly in the Inspector on the `SimpleTerrain3D` node.

4. **Sculpt Geometry**:
   - Switch to **Sculpt** mode (shortcut `B`).
   - Click and drag with the left mouse button to modify terrain elevations.
   - Hold `Shift` while dragging to invert sculpt (Raise <-> Lower).
   - Hold `Ctrl` while dragging to smooth elevations.
   - In Flatten mode, sample target height using the eyedropper tool or `Alt + Click` in the viewport.

5. **Texture Paint**:
   - Switch to **Paint** mode (shortcut `P`).
   - Choose **Color** for solid tinting or **Pattern Stamp** for textured brushes.
   - Select a pattern from the Terrain Palette dock or toolbar flyout, or drag in custom PNG/JPG textures.
   - Adjust brush size (`[` and `]`), strength, falloff, tiling, and angle.

6. **Automatic Slope & Cliff Coloring**:
   - Click the slope icon in the toolbar or select **Terrain -> Auto Color Slopes...** to open the slope dialog.
   - Choose seamless repeating textures (such as `Rock Cliff`) or solid cliff color presets (Slate, Rock Gray, Sandstone, etc.).
   - Configure the slope angle threshold (e.g. 35°) and blend transition range (e.g. 10°).
   - Enable **Keep Existing Ground Texture / Paint** to protect previously painted areas, or pick a ground fill color.
   - Click **Apply to Terrain**, or enable **Live Auto-Color Slopes while Sculpting** to update cliffs automatically while deforming elevation.

7. **Scatter Foliage & Props**:
   - Switch to **Foliage** mode (shortcut `G` or `Shift + F`).
   - Open the **Terrain Palette** dock (or click the palette button in the toolbar).
   - Select a preset (or drag a `.glb`/`.tscn` model into the dock) and click **+ Add to Terrain**.
   - Select the active layer row on the left to paint.
   - Click and drag in the viewport to scatter in **Paint** mode (`1`). Hold `Shift` while dragging to erase in **Erase** mode (`2`).
   - Switch to **Select** mode (`3`) to edit individual instances:
     - Drag selected instances across the terrain surface.
     - Adjust position (X/Y/Z), yaw rotation, and scale via toolbar controls.
     - Click **Align to Surface** to snap height and re-align to terrain normal.
     - Press `Delete` or `Backspace` to remove the selected instance, or use `[` and `]` to rotate in 15° increments.

8. **Save & Export**:
   - Click **Save** in the toolbar to save the terrain resource (`.res`/`.tres`), export as a 3D model (`.glb`/`.gltf`), export the `ArrayMesh` (`.tres`/`.res`), or export the albedo image (`.png`). Saving as `.res` is recommended to prevent large text scene files.

---

## Keyboard Shortcuts and Viewport Gestures

| Shortcut | Context | Description |
| :--- | :--- | :--- |
| `Hold RMB` / `Hold MMB` | Viewport Navigation | Camera freelook / pan / orbit (native Godot viewport controls) |
| `V` | Viewport | Switch to **View** mode |
| `B` | Viewport | Switch to **Sculpt** mode |
| `P` | Viewport | Switch to **Paint** mode |
| `G` / `Shift + F` | Viewport | Switch to **Foliage** mode |
| `Shift + W` | Viewport | Toggle terrain wireframe overlay on/off |
| `H` | Viewport | Toggle Live Info HUD overlay |
| `Tab` / `~` | Viewport | Open Viewport Radial / Pie Menu |
| `Hold R + Drag Mouse` | Active Brush | Interactively resize brush radius |
| `Hold Shift + R + Drag Mouse` | Active Brush | Interactively adjust brush strength / foliage density |
| `Shift + Wheel Up/Down` | Active Brush | Increase / decrease brush radius in 0.5m increments |
| `Shift + Ctrl + Wheel Up/Down` | Active Brush | Increase / decrease brush strength / foliage density |
| `X` | Viewport | Toggle X-Axis Lock constraint |
| `Z` | Viewport | Toggle Z-Axis Lock constraint |
| `C` | Viewport | Clear active axis lock constraint |
| `1` - `7` | Sculpt Mode | Quick-select submode: Raise (`1`), Lower (`2`), Smooth (`3`), Flatten (`4`), Noise (`5`), Terrace (`6`), Ramp (`7`) |
| `Enter` | Sculpt (Ramp) | Apply active ramp to terrain geometry |
| `Escape` | Sculpt (Ramp) | Clear active ramp points and viewport preview guide |
| `1` - `2` | Paint Mode | Quick-select submode: Color (`1`), Pattern (`2`) |
| `1` - `3` | Foliage Mode | Quick-select submode: Paint (`1`), Erase (`2`), Select & Align (`3`) |
| `Click / Drag` | Foliage (Select) | Select instance; drag to reposition across terrain surface |
| `[` / `]` | Foliage (Select) | Rotate selected instance by -15° / +15° around Y axis |
| `Delete` / `Backspace` | Foliage (Select) | Delete selected foliage instance |
| `Escape` | Foliage (Select) | Deselect active foliage instance |
| `[` | Active Paint/Sculpt | Decrease brush radius by 0.5m |
| `]` | Active Paint/Sculpt | Increase brush radius by 0.5m |
| `Shift + [` | Any Active Brush | Decrease brush strength / foliage density |
| `Shift + ]` | Any Active Brush | Increase brush strength / foliage density |
| `Shift + Drag` | Sculpt Mode | Invert sculpting action (Raise becomes Lower, Lower becomes Raise) |
| `Ctrl + Drag` | Sculpt Mode | Temporarily switch to Smooth mode |
| `Alt + Click` | Sculpt (Flatten) | Sample terrain elevation under cursor as target height |
| `Shift + Drag` | Foliage Mode | Invert foliage action (Paint becomes Erase, Erase becomes Paint) |
| `Ctrl + Z` | Editor | Undo last action |
| `Ctrl + Y` | Editor | Redo undone action |

---

## Pattern Library

The Pattern Library provides an interface for managing brush patterns and stamps:

- **Built-in Patterns**:
  - `Rock Cliff`: Directional rock fractures and cliff face roughness.
  - `Cobblestone`: Rounded paver stones with mortar channels.
  - `Dirt Gravel`: Soil speckle with pebbles.
  - `Grass Blades`: Grass clumps with varied tones.
  - `Sand Ripples`: Wave ripples for dunes and beaches.
  - `Cracked Earth`: Voronoi mud cracks for arid terrain.
  - `Soft Radial`: Smooth alpha gradient stamp.
  - `Splatter Grunge`: Multi-scale spatter and speckles.
- **Tiling Preview**: Visualizes how the pattern repeats across surfaces before painting.
- **Custom Image Importer**: Imports project or disk image files (`.png`, `.jpg`, `.jpeg`, `.webp`).
- **Search & Filter**: Filter by category (All, Built-in, Custom) or search pattern names.

---

## Foliage & MultiMesh Scattering

SimpleTerrain includes foliage and prop scattering built on Godot's native `MultiMeshInstance3D`:

- **Foliage Library**:
  - Browse, inspect, configure, and save foliage layers.
  - **10 Built-in BinbunGrass Presets**: Presets for `BinbunGrass` with wind-swaying shader materials, subdivided quad meshes, and shadow casting presets.
  - **Category Filter & Search**: Filter presets by `All Foliage`, `Grass (Binbun)`, or `Custom Presets` and search.
  - **Inspector Panel**: Configure density, minimum spacing, scale variation (min/max), surface normal alignment, max slope angle, elevation offset, and random yaw/tilt.
  - **Custom Presets**: Create custom foliage layers with any mesh/material, and save to `.tres` in `res://addons/simple_terrain/foliage_presets/`.
- **Spatial Hash Grid (`SimpleTerrainFoliageSpatialGrid`)**:
  - 2D spatial grid enforces minimum spacing between instances and provides radius queries for erasing.
- **Elevation Conforming**:
  - When terrain elevation is sculpted, smoothed, raised, or flattened, overlapping foliage instances conform their Y position to match the updated terrain surface.
- **MultiMesh Generation**:
  - Each foliage layer creates an internal `MultiMeshInstance3D` child node (`FoliageLayer_X`) under a dedicated container `TerrainFoliage`.
  - Transforms are serialized inside `SimpleTerrainData.foliage_layers`.

---

## Asset Persistence Architecture

SimpleTerrain organizes settings, presets, and state across several storage locations:

```
┌────────────────────────────────────────┐
│        Editor Action / Input           │
└───────────────────┬────────────────────┘
                    │
       ┌────────────┴────────────┐
       ▼                         ▼
┌──────────────┐         ┌──────────────┐
│ Import Model │         │ Select Stamp │
└──────┬───────┘         └──────┬───────┘
       │                        │
       ├────────────────────────┼────────────────────────┐
       ▼                        ▼                        ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  settings.json   │    │ editor_state.json│    │  .tres Presets   │
│ (res://addons/   │    │ (user://         │    │ (res://addons/   │
│  simple_terrain) │    │  simple_terrain) │    │  foliage_presets)│
├──────────────────┤    ├──────────────────┤    ├──────────────────┤
│ • Model registry │    │ • Last pattern   │    │ • Auto-generated │
│ • Texture list   │    │ • Tiling / angle │    │   layer resource │
│ • Shared across  │    │ • Brush sizes    │    │ • Preserved in   │
│   team & Git     │    │ • User-specific  │    │   Git repo       │
└──────────────────┘    └──────────────────┘    └──────────────────┘
```

1. **Project Registry (`res://addons/simple_terrain/settings.json`)**:
   - Stores imported 3D models and external custom texture paths.
   - Checked into version control so team members share the same imported asset library.

2. **Auto-Generated Foliage Presets (`res://addons/simple_terrain/foliage_presets/*.tres`)**:
   - When a 3D model (`.glb`, `.gltf`, `.tscn`) is imported via the dock or drag-and-drop, an explicit `SimpleTerrainFoliageLayer` resource is saved to disk.
   - Allows the layer to be edited in Godot's Inspector independently.

3. **Per-User Editor State (`user://simple_terrain_editor_state.json`)**:
   - Stores user-specific preferences across sessions:
     - Active pattern stamp path
     - Pattern tiling and rotation angle
     - Brush size, strength, and foliage scatter settings
   - Restored automatically when a terrain node is selected.

4. **Resource Synchronization**:
   - Adjusting layer properties in the bottom dock writes directly to `SimpleTerrainData.foliage_layers`.
   - External `.res` terrain files are saved when the scene or project is saved.

---

## Architecture Overview

The addon is modular, strictly typed, and structured according to standard Godot 4 guidelines:

```
res://addons/simple_terrain/
├── simple_terrain_3d.gd           # Node3D: Visuals, collision, sculpt/paint/foliage operations
├── simple_terrain_data.gd         # Resource: Serializable heights, texture bytes, and foliage layers
├── simple_terrain_foliage_layer.gd # Resource: Foliage layer definitions, presets, and transforms
├── simple_terrain_foliage_spatial_grid.gd # RefCounted: 2D spatial hash grid for spacing and radius queries
├── simple_terrain_settings.gd     # RefCounted: Settings, asset registry, and editor state persistence
├── simple_terrain_plugin.gd       # EditorPlugin: Viewport input, dock lifecycle, tool routing
├── brushes/                       # Built-in 2D footprint brush masks (PNG)
├── foliage_presets/               # Saved and imported .tres foliage layer presets
├── icons/                         # UI toolbar and dock SVG vector icons
├── patterns/                      # Built-in seamless terrain patterns (PNG)
├── ui/                            # Editor UI scenes and controllers (toolbar, dock, HUD, pie menu, dialogs)
├── plugin.cfg                     # Plugin manifest
└── icon.svg                       # Node type icon
```

---

## API Reference

### `SimpleTerrain3D`

Inherits: `Node3D`  
File: `res://addons/simple_terrain/simple_terrain_3d.gd`

#### Enums

- **`SculptMode`**:
  - `RAISE = 0`: Raises vertex height.
  - `LOWER = 1`: Lowers vertex height.
  - `SMOOTH = 2`: Blends vertices with neighboring heights.
  - `FLATTEN = 3`: Interpolates heights toward a target level.
  - `NOISE = 4`: Perturbs vertices with procedural hash noise.
  - `TERRACE = 5`: Quantizes vertex elevations into discrete step intervals.
  - `RAMP = 6`: Grades linear road transitions between two points.
- **`PaintMode`**:
  - `COLOR = 0`: Paints solid or blended color onto the texture.
  - `TEXTURE = 1`: Samples and blends a source texture using UV tiling and angle rotation.
- **`WireframeMode`**:
  - `TRIANGLES = 0`: Displays full triangular polygon edges.
  - `QUADS = 1`: Displays quad grid lines without diagonal subdivisions.
- **`SlopeCliffMode`**:
  - `COLOR = 0`: Renders steep slopes using a flat tint color.
  - `TEXTURE = 1`: Renders steep slopes using repeated seamless cliff textures.
- **`FoliageBrushMode`**:
  - `PAINT = 0`: Scatters foliage instances within the brush radius.
  - `ERASE = 1`: Erases foliage instances within the brush radius.

#### Properties

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `terrain_size` | `Vector2` | `Vector2(64, 64)` | Width (X) and Depth (Z) of the terrain in meters. Resizing is additive. |
| `resolution` | `Vector2i` | `Vector2i(64, 64)` | Subdivision resolution (quads along X and Z). Updates take effect immediately. |
| `data` | `SimpleTerrainData` | `null` | The underlying data resource storing dimensions, heights, and texture data. |
| `auto_slope_on_sculpt` | `bool` | `false` | Enables live automatic cliff texturing while sculpting terrain elevations. |
| `slope_cliff_mode` | `SlopeCliffMode` | `TEXTURE` | Cliff appearance mode (`COLOR` or `TEXTURE`). |
| `slope_cliff_color` | `Color` | `Color(0.45, 0.45, 0.45, 1)` | Color tint applied to steep cliff surfaces. |
| `slope_cliff_texture` | `Texture2D` | `null` | Seamless texture applied to steep cliff surfaces. |
| `slope_cliff_tiling` | `float` | `4.0` | World UV tiling repetition frequency for cliff textures. |
| `slope_threshold_deg` | `float` | `35.0` | Angle threshold in degrees where slopes begin texturing as cliffs. |
| `slope_blend_deg` | `float` | `10.0` | Angular blend range in degrees between flat terrain and full cliff texture. |
| `slope_keep_flat_paint` | `bool` | `true` | When true, preserves existing painted colors/textures on flat ground. |
| `slope_ground_color` | `Color` | `Color(0.28, 0.52, 0.22, 1)` | Ground fill color used when `slope_keep_flat_paint` is false. |
| `show_wireframe` | `bool` | `false` | Toggles the 3D wireframe overlay on the terrain. |
| `wireframe_color` | `Color` | `Color(1, 1, 1, 0.45)` | Custom color and opacity for the wireframe lines. |
| `wireframe_mode` | `WireframeMode` | `TRIANGLES` | Topology mode for wireframe display (`TRIANGLES` or `QUADS`). |
| `wireframe_in_game` | `bool` | `false` | Enables wireframe rendering during runtime gameplay (editor-only by default). |
| `collision_enabled` | `bool` | `true` | Enables or disables physical collision generation. |
| `collision_layer` | `int` | `1` | 3D physics collision layer flag. |
| `collision_mask` | `int` | `1` | 3D physics collision mask flag. |

#### Signals

- `signal terrain_modified()`: Emitted whenever the terrain height or texture is altered.
- `signal terrain_rebuilt()`: Emitted when the terrain mesh is completely regenerated.
- `signal foliage_modified(layer_index: int)`: Emitted when foliage instances are painted, erased, or cleared (`-1` when layers are added or removed).

#### Methods

```gdscript
func resize_terrain(new_size: Vector2, new_res: Vector2i) -> void
```
Resizes the terrain additively: existing sculpted elevations and painted textures are preserved at their exact physical coordinates within bounds. Newly expanded areas default to zero elevation and base color. Updates the mesh, collision shape, and wireframe immediately.

```gdscript
func create_new_terrain(p_size: Vector2, p_res: Vector2i, p_tex_size: Vector2i, p_base_color: Color) -> void
```
Generates a new terrain grid with specified dimensions (in meters), subdivision resolution, texture resolution, and initial albedo color (resets all heights and paint).

```gdscript
func sculpt(
	local_pos: Vector3,
	radius: float,
	strength: float,
	falloff: float,
	mode: SculptMode,
	delta: float,
	target_height: float = 0.0,
	step_size: float = 2.0,
	mask_image: Image = null,
	mask_angle: float = 0.0,
	mask_scale: float = 1.0
) -> void
```
Modifies vertex elevations around `local_pos`.
- `radius`: Brush radius in local space.
- `strength`: Intensity multiplier.
- `falloff`: Blend between linear (`0.0`) and smooth cosine (`1.0`) falloff.
- `mode`: Sculpt mode (`RAISE`, `LOWER`, `SMOOTH`, `FLATTEN`, `NOISE`, `TERRACE`, `RAMP`).
- `delta`: Time step or drag factor.
- `target_height`: Target elevation when using `SculptMode.FLATTEN`.
- `step_size`: Quantization step height interval (in meters) when using `SculptMode.TERRACE`.
- `mask_image`: Optional grayscale `Image` stencil to modulate brush deformation falloff.
- `mask_angle`: Rotation angle (in radians) applied to stencil mask sampling.
- `mask_scale`: Relative UV scaling multiplier for stencil mask.

```gdscript
func apply_ramp(point_a: Vector3, point_b: Vector3, width: float, falloff: float, crown: float = 0.0) -> void
```
Grades a linear road or ramp transition between two arbitrary 3D world/local points.
- `point_a`: Starting point coordinates in local space.
- `point_b`: Ending point coordinates in local space.
- `width`: Full road bed flat width (in meters).
- `falloff`: Lateral transition blend distance (in meters) beyond the road bed edges.
- `crown`: Parabolic camber/crown height (in meters) added along the centerline for drainage/profile.
- Automatically recalculates surface normals, updates the collision shape, and conforms overlapping foliage instances.

```gdscript
func paint_color(local_pos: Vector3, radius: float, strength: float, falloff: float, color: Color, delta: float = 0.0) -> void
```
Paints a color onto the terrain texture centered at `local_pos`.

```gdscript
func paint_texture(local_pos: Vector3, radius: float, strength: float, falloff: float, stamp_image: Image, tiling: float, angle: float = 0.0, delta: float = 0.0) -> void
```
Stamps a repeated texture pattern onto the terrain texture around `local_pos` with optional rotation angle (in degrees).

```gdscript
func generate_from_noise(noise: FastNoiseLite, amplitude: float, flatten_edges: bool = true) -> void
```
Generates procedural elevations across the entire terrain grid using a `FastNoiseLite` instance.

```gdscript
func flatten_all(target_height: float = 0.0) -> void
```
Sets all vertex heights across the grid to `target_height`.

```gdscript
func clear_texture_to_color(base_color: Color) -> void
```
Clears the entire albedo texture to `base_color`.

```gdscript
func rebuild_mesh() -> void
```
Regenerates all `ArrayMesh` surfaces, tangents, UVs, analytical normals, and updates the collision shape.

```gdscript
func update_mesh_geometry() -> void
```
Performs a fast vertex elevation and analytical normal update during sculpting without recreating textures or materials.

```gdscript
func update_collision() -> void
```
Generates and assigns a new `ConcavePolygonShape3D` to the internal `StaticBody3D`.

```gdscript
func export_to_gltf(path: String) -> Error
```
Exports the terrain mesh and its painted texture into a standard `.glb` or `.gltf` 3D model file.

```gdscript
func save_mesh_to_file(path: String) -> Error
```
Saves the active `ArrayMesh` to `.tres` (Text Resource) or `.res` (Binary Resource).

```gdscript
func save_texture_to_file(path: String) -> Error
```
Saves the painted `Image` to `.png`.

```gdscript
func save_data_to_file(path: String) -> Error
```
Serializes the complete `SimpleTerrainData` resource to `.res` (binary, recommended) or `.tres` (text).

```gdscript
func is_data_embedded() -> bool
```
Returns `true` if the terrain data is stored internally as a scene subresource rather than an external `.res`/`.tres` file.

```gdscript
func is_slope_texture_embedded() -> bool
```
Returns `true` if the slope cliff texture is an in-memory image stored internally as a scene subresource rather than an external file.

```gdscript
func get_height_at_local(local_pos: Vector3) -> float
```
Returns the terrain height at local coordinates `local_pos`.

```gdscript
func get_wireframe_mesh() -> ArrayMesh
```
Returns the generated line `ArrayMesh` used for wireframe rendering.

```gdscript
func apply_auto_slope_coloring() -> void
```
Applies automatic slope texturing using the configured inspector properties (`slope_cliff_mode`, `slope_cliff_color`, `slope_cliff_texture`, etc.).

```gdscript
func apply_slope_coloring(
    cliff_mode: int,
    cliff_color: Color,
    cliff_image: Image,
    cliff_tiling: float,
    threshold_deg: float,
    blend_deg: float,
    keep_flat_paint: bool,
    ground_color: Color,
    rect_min: Vector2 = Vector2(-INF, -INF),
    rect_max: Vector2 = Vector2(INF, INF)
) -> void
```
Applies quad-culled slope and cliff texturing across the terrain or within an optional 2D bounding rectangle (`rect_min` to `rect_max`). Flat quads are culled early, and intermediate slopes are smoothly blended between ground color and cliff appearance.

```gdscript
func set_wireframe_visible(p_visible: bool) -> void
```
Programmatically toggles the wireframe overlay on or off.

```gdscript
func paint_foliage(
    local_pos: Vector3,
    radius: float,
    layer_index: int,
    density: float,
    min_spacing: float,
    min_scale: float,
    max_scale: float,
    align_to_normal: float,
    max_slope_deg: float,
    height_offset: float,
    random_yaw: bool,
    random_tilt_deg: float
) -> int
```
Scatters instances into the specified foliage layer within `radius` around `local_pos`. Checks spatial hash distance, slope limits, and applies normal alignment and height offset. Returns the number of successfully placed instances.

```gdscript
func erase_foliage(local_pos: Vector3, radius: float, layer_index: int = -1) -> int
```
Erases foliage instances within `radius` around `local_pos`. If `layer_index` is `-1`, erases from all layers. Returns the total count erased.

```gdscript
func clear_foliage_layer(layer_index: int) -> void
```
Removes all instances from layer `layer_index` and updates its `MultiMesh`.

```gdscript
func clear_all_foliage() -> void
```
Removes all instances from all foliage layers.

```gdscript
func add_foliage_layer(layer: SimpleTerrainFoliageLayer) -> int
```
Appends a foliage layer to the terrain, creates its internal `MultiMeshInstance3D`, and returns its index.

```gdscript
func remove_foliage_layer(index: int) -> void
```
Removes foliage layer at `index` and updates remaining layer nodes.

```gdscript
func get_layer_transforms(layer_index: int) -> Array[Transform3D]
```
Returns a duplicate array of all instance transforms in layer `layer_index`.

```gdscript
func set_layer_transforms(layer_index: int, new_transforms: Array[Transform3D]) -> void
```
Assigns instance transforms to layer `layer_index`, rebuilds the spatial grid, and updates the `MultiMesh`.

```gdscript
func get_height_bilinear(local_x: float, local_z: float) -> float
```
Samples continuous terrain height at any floating-point local coordinates using bilinear interpolation.

```gdscript
func get_normal_at_local(local_x: float, local_z: float) -> Vector3
```
Calculates the analytical 3D surface normal at `(local_x, local_z)` using central differences.

---

### `SimpleTerrainData`

Inherits: `Resource`  
File: `res://addons/simple_terrain/simple_terrain_data.gd`

#### Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `terrain_size` | `Vector2` | Width (X) and Depth (Z) of the terrain in meters. |
| `resolution` | `Vector2i` | Number of quad subdivisions along X and Z axes. |
| `texture_size` | `Vector2i` | Width and height of the painted albedo image in pixels. |
| `height_data` | `PackedFloat32Array` | Array of float heights for all `(res.x + 1) * (res.y + 1)` vertices. |
| `image_data` | `PackedByteArray` | Compressed PNG byte buffer preserving texture paint edits. |
| `foliage_layers` | `Array[SimpleTerrainFoliageLayer]` | Array of foliage layer configurations and placed instance transforms. |

#### Signals

- `signal terrain_resized(old_size: Vector2, new_size: Vector2, old_res: Vector2i, new_res: Vector2i)`: Emitted when data is resized.

#### Methods

```gdscript
func resize_data(new_size: Vector2, new_res: Vector2i, base_color: Color = DEFAULT_BASE_COLOR) -> void
```
Resamples heightfield data via bilinear interpolation and redistributes texture painting additively to the new dimensions and resolution.

```gdscript
func add_foliage_layer(layer: SimpleTerrainFoliageLayer) -> int
```
Appends a foliage layer to the data array and marks the resource modified.

```gdscript
func remove_foliage_layer(index: int) -> void
```
Removes the foliage layer at `index`.

```gdscript
func insert_foliage_layer(index: int, layer: SimpleTerrainFoliageLayer) -> void
```
Inserts a foliage layer at `index` (used by Undo/Redo).

---

### `SimpleTerrainFoliageLayer`

Inherits: `Resource`  
File: `res://addons/simple_terrain/simple_terrain_foliage_layer.gd`

A custom resource defining a foliage or prop scattering layer, its visual representation (mesh and material), placement rules, and instance transform data.

#### Properties

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `layer_id` | `String` | `""` | Unique identifier string for the layer. |
| `name` | `String` | `"Grass 01"` | Display name shown in active layer rows and library cards. |
| `source_scene_path` | `String` | `""` | File path to source 3D model scene (`.gltf`, `.glb`, `.obj`, `.tscn`). |
| `mesh` | `Mesh` | `null` | 3D mesh instanced by the MultiMesh (extracted from 3D model or QuadMesh). |
| `material` | `Material` | `null` | Optional material override. If `null`, uses model's native surface materials. |
| `cast_shadow` | `ShadowCastingSetting` | `OFF` | Shadow casting mode (`OFF`, `ON`, `SHADOWS_ONLY`). Auto-enabled for trees/props. |
| `visible` | `bool` | `true` | Visibility toggle for the entire layer. |
| `transforms` | `Array[Transform3D]` | `[]` | Serialized array of individual instance 3D transforms. |
| `density` | `float` | `12.0` | Default placement attempts per brush click/step. |
| `min_spacing` | `float` | `0.25` | Minimum distance in meters between any two instances (0.05m to 50.0m). |
| `min_scale` | `float` | `0.8` | Minimum random uniform scale factor. |
| `max_scale` | `float` | `1.3` | Maximum random uniform scale factor. |
| `random_yaw` | `bool` | `true` | When true, applies random rotation around the up vector (0° - 360°). |
| `align_to_normal` | `float` | `0.5` | Slerp blend between world UP (`0.0`) and terrain surface normal (`1.0`). |
| `random_tilt_deg` | `float` | `5.0` | Maximum random angle perturbation away from aligned up axis. |
| `height_offset` | `float` | `-0.05` | Vertical elevation offset in meters relative to terrain surface. |
| `max_slope_deg` | `float` | `40.0` | Maximum allowable terrain slope angle for placing instances. |

#### Static Factory Methods

```gdscript
static func create_from_file(path: String) -> SimpleTerrainFoliageLayer
```
Creates a new layer directly from a 3D model or mesh file (`.gltf`, `.glb`, `.obj`, `.tscn`, `.tres`). Automatically computes model bounding size (AABB), preserves embedded surface materials, and sets smart defaults for spacing, density, and shadows (e.g. for trees and rocks).

```gdscript
static func load_mesh_from_path(path: String) -> Mesh
```
Loads and extracts a ready-to-use `Mesh` from any resource or model path.

```gdscript
static func extract_mesh_from_resource(res: Resource) -> Mesh
```
Extracts a `Mesh` from a `Resource`. For `PackedScene` hierarchies (such as imported glTF/GLB models), combines multiple child `MeshInstance3D` nodes into a single consolidated `ArrayMesh` using `SurfaceTool`, preserving local node transforms and surface materials.

```gdscript
static func create_binbun_grass_preset(variant_index: int) -> SimpleTerrainFoliageLayer
```
Returns a fully configured preset for BinbunGrass variants 1 through 10, complete with shader material, wind animation settings, and quad mesh.

```gdscript
static func create_custom_layer(p_name: String, p_mesh: Mesh = null, p_mat: Material = null) -> SimpleTerrainFoliageLayer
```
Constructs a new blank or custom foliage layer with sensible default placement parameters.

---

### `SimpleTerrainFoliageSpatialGrid`

Inherits: `RefCounted`  
File: `res://addons/simple_terrain/simple_terrain_foliage_spatial_grid.gd`

2D spatial hash grid providing distance checks and radius queries for foliage scattering and erasing.

#### Methods

```gdscript
func _init(p_cell_size: float = 2.0) -> void
```
Initializes the spatial grid with specified cell size (default 2.0m).

```gdscript
func is_too_close(pos: Vector2, min_dist: float) -> bool
```
Returns `true` if any existing instance is closer than `min_dist` to `pos`.

```gdscript
func add_instance(index: int, pos: Vector2) -> void
```
Registers an instance index at 2D coordinate `pos`.

```gdscript
func query_radius(pos: Vector2, radius: float) -> Array[int]
```
Returns all instance indices within `radius` meters of `pos`.

```gdscript
func build(transforms: Array[Transform3D]) -> void
```
Rebuilds the entire spatial grid from an array of transforms.

---

## Code Examples

### 1. Creating Terrain via Code

```gdscript
extends Node3D

func _ready() -> void:
    # 1. Instantiate the terrain node
    var terrain: SimpleTerrain3D = SimpleTerrain3D.new()
    add_child(terrain)

    # 2. Configure dimensions (e.g. 128m x 128m, 64x64 quads, 1024x1024 texture)
    var size: Vector2 = Vector2(128.0, 128.0)
    var resolution: Vector2i = Vector2i(64, 64)
    var tex_size: Vector2i = Vector2i(1024, 1024)
    var grass_color: Color = Color(0.3, 0.55, 0.2, 1.0)

    terrain.create_new_terrain(size, resolution, tex_size, grass_color)
```

---

### 2. Procedural / Runtime Terraforming (Explosion Crater)

Deform the terrain at runtime in response to gameplay events (e.g., explosions, impacts, spells):

```gdscript
func create_explosion_crater(terrain: SimpleTerrain3D, explosion_world_pos: Vector3, radius: float, depth: float) -> void:
    # Convert world coordinates to terrain local space
    var local_pos: Vector3 = terrain.global_transform.affine_inverse() * explosion_world_pos

    # Lower the terrain at the impact point
    terrain.sculpt(
        local_pos,
        radius,
        depth,
        0.7, # Smooth cosine falloff
        SimpleTerrain3D.SculptMode.LOWER,
        1.0
    )

    # Paint a scorched dark crater on the terrain texture
    terrain.paint_color(
        local_pos,
        radius * 0.9,
        1.0, # Full opacity
        0.5,
        Color(0.12, 0.1, 0.08, 1.0), # Scorched crater color
        1.0
    )

    # Update collision shape for physics bodies and projectiles
    terrain.update_collision()
```

---

### 3. Runtime Texture Painting (Decal / Path Painting)

Paint footsteps, trails, or dirt paths directly onto the terrain texture:

```gdscript
func paint_dirt_path(terrain: SimpleTerrain3D, path_points: Array[Vector3], width: float) -> void:
    var dirt_color: Color = Color(0.45, 0.32, 0.18, 1.0)

    for pt: Vector3 in path_points:
        var local_pt: Vector3 = terrain.global_transform.affine_inverse() * pt
        terrain.paint_color(local_pt, width, 0.6, 0.8, dirt_color, 0.2)
```

---

### 4. Saving and Loading Saved Meshes & Textures

Export the sculpted mesh and painted texture to project files from code:

```gdscript
func export_terrain_assets(terrain: SimpleTerrain3D) -> void:
    # 1. Export complete terrain with texture as standard glTF / GLB model
    var gltf_err: Error = terrain.export_to_gltf("res://assets/terrain/island_model.glb")
    if gltf_err == OK:
        print("Terrain glTF model exported successfully!")

    # 2. Save mesh as native Godot resource (.tres or .res)
    var mesh_err: Error = terrain.save_mesh_to_file("res://assets/terrain/island_mesh.tres")
    if mesh_err == OK:
        print("Terrain mesh saved successfully!")

    # 3. Save painted albedo texture as standard PNG
    var tex_err: Error = terrain.save_texture_to_file("res://assets/terrain/island_albedo.png")
    if tex_err == OK:
        print("Terrain texture saved successfully!")

    # 4. Save full data resource for reloading or procedural loading (.res recommended)
    var data_err: Error = terrain.save_data_to_file("res://assets/terrain/island_data.res")
    if data_err == OK:
        print("Terrain data resource saved successfully!")
```

#### Loading a Saved Terrain Resource

```gdscript
func load_existing_terrain(saved_data_path: String) -> SimpleTerrain3D:
    var terrain: SimpleTerrain3D = SimpleTerrain3D.new()
    var saved_data: SimpleTerrainData = load(saved_data_path) as SimpleTerrainData
    terrain.data = saved_data
    add_child(terrain)
    return terrain
```

---

### 5. Automatic Slope & Cliff Coloring

Automatically texture steep cliffs with a repeating rock pattern or solid color tint:

```gdscript
func apply_cliff_styling(terrain: SimpleTerrain3D) -> void:
    # Option A: Seamless Rock Cliff texture with 4x UV tiling
    var rock_tex: Texture2D = preload("res://addons/simple_terrain/patterns/rock_cliff.png")
    terrain.apply_slope_coloring(
        SimpleTerrain3D.SlopeCliffMode.TEXTURE,
        Color.WHITE,
        rock_tex.get_image(),
        4.0,   # Cliff tiling scale
        35.0,  # Slope angle threshold in degrees
        10.0,  # Slope blend range in degrees
        true,  # Keep existing painted grass/paths on flat areas
        Color(0.28, 0.52, 0.22, 1.0) # Ground color (if keep_flat_paint is false)
    )

    # Option B: Solid Dark Slate rock color
    var slate_color: Color = Color(0.24, 0.25, 0.28, 1.0)
    terrain.apply_slope_coloring(
        SimpleTerrain3D.SlopeCliffMode.COLOR,
        slate_color,
        null,
        1.0,
        40.0,  # Slopes steeper than 40 degrees become rock
        8.0,   # 8 degree smooth blend
        true,
        Color.DARK_GREEN
    )
```

---

### 6. Scattering & Managing Foliage Programmatically

Create foliage layers, scatter grass instances at runtime or generation time, and query instance counts:

```gdscript
func populate_terrain_with_grass(terrain: SimpleTerrain3D) -> void:
    # 1. Create a BinbunGrass preset layer (e.g. Preset 03: Vibrant Meadow)
    var grass_layer: SimpleTerrainFoliageLayer = SimpleTerrainFoliageLayer.create_binbun_grass_preset(3)
    grass_layer.name = "Meadow Grass"
    var layer_idx: int = terrain.add_foliage_layer(grass_layer)

    # 2. Scatter grass instances within a radius around the origin
    var center: Vector3 = Vector3(0.0, 0.0, 0.0)
    var radius: float = 20.0
    var density: float = 40.0       # Placement attempts
    var min_spacing: float = 0.25   # Minimum distance between grass clumps
    var min_scale: float = 0.8
    var max_scale: float = 1.3
    var align_to_normal: float = 0.5 # 50% terrain normal / 50% vertical UP
    var max_slope_deg: float = 35.0  # Avoid scattering on steep cliffs
    var height_offset: float = -0.05 # Sink slightly into ground to prevent gaps
    var random_yaw: bool = true
    var random_tilt_deg: float = 6.0

    var placed_count: int = terrain.paint_foliage(
        center,
        radius,
        layer_idx,
        density,
        min_spacing,
        min_scale,
        max_scale,
        align_to_normal,
        max_slope_deg,
        height_offset,
        random_yaw,
        random_tilt_deg
    )
    print("Scattered %d grass clumps onto terrain." % placed_count)

    # 3. Erase a clearing in the middle of the grass (e.g. for a campsite)
    var erased_count: int = terrain.erase_foliage(Vector3(0.0, 0.0, 0.0), 5.0, layer_idx)
    print("Erased %d grass clumps for campsite clearing." % erased_count)

    # 4. Any subsequent sculpting automatically conforms overlapping grass:
    terrain.sculpt(Vector3(5.0, 0.0, 5.0), 8.0, 3.0, 0.5, SimpleTerrain3D.SculptMode.RAISE, 1.0)
    # Existing grass in the 8m radius automatically elevated to new surface.
```

