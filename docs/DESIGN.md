# Crumb Lords — design
A goofy 3D shooter. You play as a piece of furniture or a household item: door, table, TV, and so on. That object is your "race" or class. Weapons are other household items with silly mechanics, e.g. a **chapstick laser** where reloading means twisting the base until the stick comes back up.

**Locked decisions:**
- **First person with a visible body**: your object's edges and legs show in view, and the full object appears in mirrors and reflections and on death cams.
- **Single-player vs AI enemies**
- **Low-poly, bright toy-like colors**
- **Fast arena play at tiny scale**: you're a dollhouse-sized object in a normal house. A kitchen counter is an arena, the sink is a canyon, and drawers are elevators.

**Default enemy theme (adjustable):** household pests and gadgets turned evil. Dust bunnies (weak swarm), ants (ranged, spit crumbs), wind-up toys (chargers), and a Roomba boss. They're also rigid or simple, so they animate procedurally.

**First slice (expanded):** the kitchen counter as 2–3 linear rooms. Door class (passive + super), chapstick laser at the start, stapler picked up halfway, dust bunny rooms, then a mini-boss (a giant dust bunny or a hand mixer). The level timer and results screen are included.

**Core rules (locked):**
- Each class has **one passive + one super ability**. The super charges up from kills and damage.
- **Dual wield:** one weapon at level start and a second picked up partway through. Left mouse fires the left hand, right mouse fires the right hand, and each hand reloads on its own.
- **Death and checkpoints:** before the second-weapon pickup, dying instantly restarts the level and resets the timer. The pickup is the only checkpoint: dying after it respawns you there with both weapons, and the timer keeps running, so deaths cost time.
- **Weapon visuals:** weapons float with a magical mist or glow around them, near the table's legs or just in front of the door. In first person they hover at the bottom left and right of the screen and bob gently on their own. That's easier than hands, and the floating sway is procedural.
- **Levels:** a linear chain of rooms ending in a boss. A **timer** runs from the first move until the boss dies; the results screen shows the time, a medal tier and the personal best.

Classes (draft):
- **Door**: tanky, tall thin hitbox, moves by hopping.
  - Passive *Solid Core*: takes 30% less damage from the front.
  - Super *Slam*: swings open as a shield wall that blocks shots, then slams shut in a wide bash that knocks enemies back.
- **Table**: stable, scuttles on four legs.
  - Passive *Four Legs*: immune to knockback, and no accuracy loss while moving.
  - Super *Table Flip*: flips into a cover wall and sends out a shockwave stomp.
- **TV**: fragile and fast, rolls on a stand.
  - Passive *Picture-in-Picture*: nearby enemies show through walls.
  - Super *Channel Surf*: a static burst that stuns everything in a radius. The screen shows a face or emote.

Draft weapons (each needs a reload gag):
- Chapstick laser: twist the base to reload
- Stapler: rapid fire, open it to reload a staple strip
- Spray bottle: a short-range cone; pump the trigger for pressure
- TV remote: hitscan "pause" beam; reload by smacking the batteries


## Movement tricks (one per class)
- **Door, Hinge Hop**: a double jump. The second jump also lunges you forward and flaps the camera like a swinging door.
- **Table, Wall Scuttle**: briefly run up a wall on four legs (planned).
- **TV, Stand Slide**: a low, fast slide on the swivel stand (planned).
