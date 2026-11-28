# Testing

```bash
tests/run_smoke_test.sh                     # headless end-to-end smoke test; exit code = failed checks
GODOT=/path/to/Godot tests/run_smoke_test.sh  # if `godot` isn't on PATH
```

- The runner first does `godot --headless --editor --quit` to import, so new `class_name`
  scripts get registered, and then runs `res://tests/smoke_test.tscn`.
- A run fails if the summary line isn't `N checks, 0 failed`, if any `SCRIPT ERROR` is logged, or
  if it hangs longer than 180s.
- There is one test (`tests/smoke_test.gd`) and no way to run part of it. To try a section, open
  `smoke_test.tscn` in the editor and run the current scene (⌘R on macOS, F6 elsewhere), or
  temporarily cut down `_run()`.
- There is no linter or build step.

## How the smoke test works

`smoke_test.gd` runs `PROCESS_MODE_ALWAYS` and plays a real match by injecting input with
`Input.parse_input_event` through its `press(button, device)`, `press_key(key)` and
`join_side(device, side)` helpers. The first match joins the keyboard as P1 and controller 2
(device 1) as P2. The rematch joins controllers 1 and 2.

It reaches into private fields (`_root`, `_messages`, `_offered_upgrades`, `_input_prefix`) and
`CpuBrain`'s perception helpers (`_my_enemies()`, `_bullets_in_world()`), `_lead_aim()`,
`_bullet_speed()` and `_shield_aim()`, so renaming those breaks it. It also points `BalanceLog.path` at a throwaway file, so test runs
never write to the real balance log. For a new behavior, add `check(...)` calls in the matching section
rather than writing a separate test.

## Manual testing

Each issue lists things to try in the editor (⌘B runs the project, ⌘R the current scene) and in
a browser build. If a controller does nothing in a browser, check `navigator.getGamepads()` and
try restarting Chrome before blaming the code.
