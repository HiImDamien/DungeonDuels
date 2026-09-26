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

# ── Player stats (keyed by the player's action_prefix) ────────────────────────

var player_stats := {
	"": PlayerStats.new(),
	"p2_": PlayerStats.new(),
}

# ── Opponent event ticker ─────────────────────────────────────────────────────

signal opponent_event(from_prefix: String, message: String)

func notify_opponent(from_prefix: String, message: String) -> void:
	opponent_event.emit(from_prefix, message)

# ── Match lifecycle ───────────────────────────────────────────────────────────

## Resets everything for a fresh match (including rematches from the menu).
func start_match() -> void:
	phase = Phase.DUNGEON
	for prefix in player_stats:
		player_stats[prefix] = PlayerStats.new()
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
		await get_tree().create_timer(1.0).timeout
	is_grace = false
	grace_ended.emit()
	await get_tree().create_timer(1.2).timeout
	grace_cleared.emit()

# ── Player stat persistence ───────────────────────────────────────────────────

func save_player_stats(players: Array) -> void:
	for p: player in players:
		player_stats[p.action_prefix].capture(p)

func stats_for(p: player) -> PlayerStats:
	return player_stats[p.action_prefix]
