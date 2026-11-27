extends Node
## Autoload holding match-wide state that has to survive scene changes:
## the phase, the dungeon timer, the grace period and each player's stats.

# ── Phase ─────────────────────────────────────────────────────────────────────

enum Phase { DUNGEON, FINAL_BATTLE }
var phase: Phase = Phase.DUNGEON

# ── Match timer ───────────────────────────────────────────────────────────────

const MATCH_DURATION := 63.0
var time_remaining: float = MATCH_DURATION

signal timer_tick(seconds_left: int)
signal timer_expired

var _timer_active := false
var _last_whole_second: int = -1

# ── Grace period ──────────────────────────────────────────────────────────────

const GRACE_DURATION := 3.0
var is_grace: bool = true

signal grace_tick(seconds_left: int)
signal grace_ended
signal grace_cleared

# ── Player stats (keyed by player_index) ──────────────────────────────────────

var player_stats := {
	1: PlayerStats.new(),
	2: PlayerStats.new(),
}

# ── Pausing ───────────────────────────────────────────────────────────────────

## How many times each player may pause per match (dungeon + final battle).
const PAUSES_PER_PLAYER := 3
var pauses_left := {1: PAUSES_PER_PLAYER, 2: PAUSES_PER_PLAYER}

# ── Opponent event ticker ─────────────────────────────────────────────────────

signal opponent_event(from_player: int, message: String)

## Show `message` on the screen of whoever is NOT from_player.
func notify_opponent(from_player: int, message: String) -> void:
	opponent_event.emit(from_player, message)

# ── Balance log (see docs/balance.md) ─────────────────────────────────────────

## Upgrade ids in the order each player picked them up (Upgrade.pick_id()).
var picks := {1: [], 2: []}
var rooms_cleared := {1: 0, 2: 0}
## Dungeon deaths (respawns). The final battle's result is the winner instead.
var deaths := {1: 0, 2: 0}
## Perfect blocks (#58), dungeon and final battle together.
var perfect_blocks := {1: 0, 2: 0}
## Seconds actually played this match. Only grows in _process, which stops
## while the tree is paused, so pauses don't count.
var match_elapsed := 0.0
var _match_logged := false

func _process(delta: float) -> void:
	match_elapsed += delta

func record_pick(player_index: int, id: String) -> void:
	picks[player_index].append(id)

func record_room_cleared(player_index: int) -> void:
	rooms_cleared[player_index] += 1

func record_death(player_index: int) -> void:
	deaths[player_index] += 1

func record_perfect_block(player_index: int) -> void:
	perfect_blocks[player_index] += 1

## Writes this match's balance record. Only the first call per match writes, so
## nothing can log a match twice. Quitting mid-match never gets here.
func log_match_result(winner: int) -> void:
	if _match_logged:
		return
	_match_logged = true
	var record := {
		"time": Time.get_datetime_string_from_system(true) + "Z",
		"version": _version(),
		"duration_s": snappedf(match_elapsed, 0.1),
		"winner": winner,
	}
	for index in [1, 2]:
		record["p%d" % index] = {
			"device": _device_kind(index),
			"picks": picks[index].duplicate(),
			"rooms_cleared": rooms_cleared[index],
			"kills": player_stats[index].kills,
			"deaths": deaths[index],
			"perfect_blocks": perfect_blocks[index],
		}
		if record["p%d" % index].device == PlayerDevices.CPU:
			record["p%d" % index]["difficulty"] = PlayerDevices.cpu_difficulty_for(index)
	BalanceLog.append(record)

## The project's version (Project Settings > Application > Config > Version),
## or "dev" while it's left blank.
func _version() -> String:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	return version if version != "" else "dev"

func _device_kind(player_index: int) -> String:
	if not PlayerDevices.is_assigned():
		return "unassigned"  # game.tscn run straight from the editor
	return BalanceLog.device_kind(PlayerDevices.devices[player_index])

# ── Match lifecycle ───────────────────────────────────────────────────────────

## Resets everything for a fresh match (including rematches from the menu).
func start_match() -> void:
	phase = Phase.DUNGEON
	for index in player_stats:
		player_stats[index] = PlayerStats.new()
		pauses_left[index] = PAUSES_PER_PLAYER
		picks[index] = []
		rooms_cleared[index] = 0
		deaths[index] = 0
		perfect_blocks[index] = 0
	match_elapsed = 0.0
	_match_logged = false
	time_remaining = MATCH_DURATION
	_last_whole_second = int(ceil(time_remaining))
	_timer_active = true
	start_grace_period()

func tick(delta: float) -> void:
	if not _timer_active or phase == Phase.FINAL_BATTLE:
		return
	time_remaining -= delta
	if time_remaining <= 0.0:
		time_remaining = 0.0
		_timer_active = false
		timer_expired.emit()
		return
	var whole := int(ceil(time_remaining))
	if whole != _last_whole_second:
		_last_whole_second = whole
		timer_tick.emit(whole)

func start_grace_period() -> void:
	is_grace = true
	for i in range(int(GRACE_DURATION), 0, -1):
		grace_tick.emit(i)
		await get_tree().create_timer(1.0, false).timeout
	is_grace = false
	grace_ended.emit()
	await get_tree().create_timer(1.2, false).timeout
	grace_cleared.emit()

# ── Player stat persistence ───────────────────────────────────────────────────

func save_player_stats(players: Array) -> void:
	for p: player in players:
		player_stats[p.player_index].capture(p)

func stats_for(p: player) -> PlayerStats:
	return player_stats[p.player_index]
