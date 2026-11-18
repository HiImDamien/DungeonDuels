# UI conventions and pausing

## Menus

- Menus are `MenuList` containers of `Button`s, with built-in focus turned off (`FOCUS_NONE`) and
  navigation handled in `_unhandled_input`.
- Mark input as handled *before* doing anything that might change the scene. Otherwise
  `get_viewport()` will be null afterwards.
- Hidden buttons are skipped by `get_buttons()`.
- Overlays such as `ControlsScreen`, `CountdownOverlay` and the win screen in `final_battle.gd`
  are built in code rather than in `.tscn` files.
- `InputLabels` creates the Controls screen text from the saved bindings
  (`PlayerDevices.template_events()`), so editing the Input Map updates it automatically, and the
  text doesn't change with who picked which side.
- Web fonts: use plain ASCII in labels. Symbols like △ fall back to system fonts on desktop but
  show as boxes on web.
- On web, Esc only exits browser fullscreen. Every screen needs an Enter / A way out.

## Pausing

`PauseMenu` (CanvasLayer, `PROCESS_MODE_ALWAYS`) sets `get_tree().paused`. Only the player who
paused can resume. Resuming counts down 3-2-1 first, and each player gets
`GameState.PAUSES_PER_PLAYER` pauses per match. Async waits that should stop during a pause use
`create_timer(t, false)` (process_always = false).
