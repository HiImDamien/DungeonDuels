#!/usr/bin/env bash
# Summarizes a balance log (see docs/balance.md): for every upgrade and bullet
# mode, how often it was picked and the win rate of the players who took it.
#
#   tests/balance_summary.sh [log.jsonl ...]
#
# With no arguments it reads the CPU vs CPU log in the Godot user folder.
# Needs jq. Every player record counts once per match, so 20 matches = 40
# players. A win rate from fewer than ~10 players is mostly noise.
set -eu
UD="$HOME/Library/Application Support/Godot/app_userdata/DungeonDuels"
if [ $# -eq 0 ]; then
	set -- "$UD/balance_log_cpu.jsonl"
fi

jq -s -r '
	# One row per player per match: their picks and whether they won.
	[ .[] | . as $m
	  | ({picks: .p1.picks, won: (.winner == 1)}, {picks: .p2.picks, won: (.winner == 2)}) ]
	as $players
	| ($players | length) as $n
	| def pct(a; b): if b == 0 then "-" else ((a * 100 / b) | round | tostring) + "%" end;
	  def row(name; rows):
	    (rows | length) as $k
	    | (rows | map(select(.won)) | length) as $w
	    | "\(name)\t\($k)\t\(pct($k; $n))\t\(pct($w; $k))";
	  ["spread", "bounce", "big", "tracking", "cardinal", "burst"] as $modes
	| ($players | map(.picks[]) | unique) as $all
	| ($all - $modes) as $stats
	| "Matches: \($n / 2)   players: \($n)\n",
	  "UPGRADE\tPLAYERS\tTOOK IT\tWIN RATE",
	  ( $stats[] as $u | row($u; $players | map(select(.picks | index($u)))) ),
	  "",
	  "BULLET MODE\tPLAYERS\tTOOK IT\tWIN RATE",
	  ( $modes[] as $u | row($u; $players | map(select(.picks | index($u)))) ),
	  row("(no mode)"; $players | map(select([.picks[] | select(. as $p | $modes | index($p))] | length == 0))),
	  "",
	  "STACKS\tPLAYERS\tTOOK IT\tWIN RATE",
	  ( $stats[] as $u
	    | ($players | map(.c = ([.picks[] | select(. == $u)] | length))) as $c
	    | ([$c[].c] | max) as $top
	    | range(2; $top + 1) as $k
	    | row("\($u) x\($k)"; $c | map(select(.c == $k))) ),
	  "",
	  "Avg picks: winners \(($players | map(select(.won) | .picks | length) | add) / ($n / 2) * 10 | round / 10), losers \(($players | map(select(.won | not) | .picks | length) | add) / ($n / 2) * 10 | round / 10)"
' "$@" | column -t -s $'\t'
