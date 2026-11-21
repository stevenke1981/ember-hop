# Ember Hop — Art Direction 美術風格

## Technical frame

- Engine: Godot 4.7.2, 2D, side view, Compatibility-safe.
- Base viewport 1280x720, stretch mode `canvas_items`, aspect `expand`.
- Tile size 64 px. Player ~ 1 tile wide, 1.25 tiles tall on screen.
- Sprites authored at 2x (128 px tall) and drawn at scale 0.5; linear filter + mipmaps.
- Transparency: generated on flat magenta #FF00FF, keyed to real alpha, edges defringed.
- Raw generations in `art/raw/`, normalized game files in `art/final/`.

## Visual system

- Shape language: round, soft, friendly for Pip and pickups; jagged/angular for hazards and enemies.
- Outline: thick dark indigo (#1E1838) outline on every gameplay object; background has no outlines.
- Palette roles: player = warm amber/gold glow (#FFB347, #FFD27A) in a teal-glass lantern;
  enemies = desaturated violet; hazards = cold grey-blue with pale tips; ground = mossy teal-green
  top over indigo-brown soil; background = deep indigo → dusky violet twilight, low contrast.
- Lighting: cool ambient twilight, warm light only from Pip and fireflies.
- Detail density: gameplay objects simple and readable; background softer, lower contrast.
- Motion: bouncy, squash & stretch on jump/land.

## Locks

Same view (side, facing right), same outline weight, same palette, same flat cel shading for
the whole family. No text, no signatures, no scenery behind isolated objects.
