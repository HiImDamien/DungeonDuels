# Player input and devices

`player.gd` reads input actions with the prefix `""` for P1 and `"p2_"` for P2 (e.g.
`p2_move_left`). Each player has exactly one device (the keyboard or one controller), chosen on
the join screen. The left side is P1 and the right side is P2.

The CPU opponent will move these reads behind a `PlayerInput` object. See `docs/cpu-opponent.md`.

## `PlayerDevices` autoload (`scripts/game/player_devices.gd`)

- Stores the choice as `"keyboard"` / `"joypad:<id>"`, built from the event class plus its device id.
- `assign()` rewrites both players' actions in the InputMap at runtime (in memory only), using
  P1's saved bindings in project.godot as templates. In project.godot, P1 actions hold the
  keyboard and controller templates. The `p2_` actions there are only defaults for when no join
  has happened, e.g. running `game.tscn` straight from the editor.
- `pause` stays bound to any device. `PlayerDevices.player_for_event()` (wrapped by
  `MenuList.player_for_event()`) decides who pressed something, and devices that haven't joined
  map to 0. `PauseMenu`, `ControlsScreen` and `MenuList.controlling_player` all depend on it.

## Device ids

In Godot 4.7, keyboard events use `InputEvent.DEVICE_ID_KEYBOARD` (16). Saved `"device":0` key
bindings are converted to 16 on load, and joypads start at 0. Never identify a device by id alone.

In project.godot, input actions are serialized as `Object(InputEventKey, ...)` blobs where
`"device"` matters: `-1` means any device.

## Join screen

The join screen is event-driven and never lists connected joypads at startup, because browsers
only report a gamepad after one of its buttons is pressed.

**Solo play:** when exactly one device has joined, picked a side and readied up, pressing A /
Enter again sets `JoinScreen.solo` and starts the countdown. `assign()` then gets
`PlayerDevices.CPU` (`"cpu"`) for the empty side, which erases that player's actions and adds
none, so no device can steer or pause for them. `CpuBrain.attach_if_cpu()` gives them a brain in
the dungeon and in the final battle. See `docs/cpu-opponent.md`.
A second device joining, backing out, or the device disconnecting clears `solo`.
