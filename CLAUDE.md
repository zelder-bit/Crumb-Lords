# Household Havoc — agent rules

A goofy first-person shooter in Godot **4.7.2**. You play as a dollhouse-scale household object (Door, Table, TV) in a giant kitchen. The design is in `docs/DESIGN.md` and the code interfaces are in `docs/ARCHITECTURE.md`.

## Hard rules
- Godot 4.7 GDScript only. No Godot 3 APIs (`KinematicBody`, `yield`, `instance()`, `onready var` without `@`, etc.).
- When you're unsure about an API, grep the exact-version reference: `tools/godot_api/doc/classes/<Class>.xml`. Regenerate it with `cd tools/godot_api && godot --headless --doctool .`.
- **Build nodes in code.** Scenes (`.tscn`) stay tiny, with a root node plus a script. Don't hand-write large `.tscn` files.
- Everything animates as rigid parts with pivots (Tween / procedural springs). No skeletal rigs.
- Low-poly look, bright toy-like colors, primitive meshes or `.glb` from Blender.
- Collision layers: 1 = world (bit 1), 2 = player (bit 2), 3 = enemies (bit 4).

## Verify before saying you're done
```sh
godot --headless --import                      # re-import after adding assets/scripts with class_name
godot --headless --quit-after 300              # run the main scene ~5s; must print no SCRIPT ERROR
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit   # unit tests
tools/shot.sh shots/room.png                   # windowed screenshot (see debug/screenshot.gd)
```
Use `tools/review_shot.sh <png>` to get a Gemini (agy) art critique of a screenshot.
