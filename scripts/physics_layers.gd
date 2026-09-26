class_name PhysicsLayers
## Bit values for the 2D physics layers named in Project Settings → Layer Names.
## Use these instead of raw numbers when setting collision_layer / collision_mask
## from code. Combine with |, e.g. PhysicsLayers.WALLS | PhysicsLayers.ENEMIES.

const PLAYERS := 1 << 0
const WALLS   := 1 << 1
const SHIELDS := 1 << 2
const BULLETS := 1 << 3
const ENEMIES := 1 << 4
const PICKUPS := 1 << 5
