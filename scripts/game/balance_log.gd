class_name BalanceLog
extends RefCounted
## Appends one JSON line per finished match to a .jsonl file, for balancing.
## See docs/balance.md for the record format and how to summarize it.
##
## On web, user:// lives in the browser's IndexedDB, so the file is written but
## nobody can open it. That's why every line is also printed: it shows up in the
## browser's dev tools console.

## Where records go. `static var` (not const) so the smoke test can point it at
## a throwaway file instead of the real log.
static var path := "user://balance_log.jsonl"

static func append(record: Dictionary) -> void:
	var line := JSON.stringify(record, "", false)  # keep the record's key order
	print(line)
	# WRITE truncates, so only use it to create the file; otherwise open for
	# READ_WRITE and jump to the end to append.
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if file == null:
		push_warning("BalanceLog: can't open %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.seek_end()
	file.store_line(line)
	file.close()

## The device kind without its id: "keyboard", "joypad" (from "joypad:<id>"),
## and any future kind such as "cpu" passes through unchanged. An empty device
## (the idle side in solo play) is "none".
static func device_kind(device: String) -> String:
	return "none" if device == "" else device.get_slice(":", 0)
