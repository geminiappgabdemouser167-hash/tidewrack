# Journal & Save Regression Guide

Regression reference for journal discovery persistence across `user://save.json`, `Continue`, and `New Game`. For system context see [`GDD.md`](GDD.md), [`scripts/autoload/game_state.gd`](../scripts/autoload/game_state.gd), [`scripts/journal.gd`](../scripts/journal.gd), and [`scripts/main_menu.gd`](../scripts/main_menu.gd).

## Save Payload Contract

`GameState.save_game()` writes a four-key dictionary to `user://save.json`, preserving `"version"`, `"scene"`, and `"flags"` unchanged while extending the payload with `"journal_entries"`:

```json
{
	"flags": {
		"trusted_edith": true
	},
	"journal_entries": [
		"edith_log_01",
		"edith_log_02"
	],
	"scene": "res://scenes/game.tscn",
	"version": 1
}
```

## Five-Case Summary Matrix

| Case | Trigger / Input Shape | Expected `GameState` State | Expected `Journal` UI State | Story Flags & Scene |
|------|-----------------------|----------------------------|-----------------------------|---------------------|
| 1. Normal save / `Continue` | Valid `save_game()` → `MainMenu._on_continue()` → `load_game()` | `load_game()` returns `true`; `journal_entries` matches saved IDs in exact discovery order | `restore()` replaces `entries` cleanly; UI renders each saved ID once in order | `"scene"` and `"flags"` restore identically |
| 2. Legacy save | Pre-journal `save.json` missing `"journal_entries"` | `load_game()` returns `true` with zero warnings; `journal_entries` resets to `[]` | `reset()` clears any prior session entries and shows the empty-state prompt | `"scene"` and `"flags"` restore intact; next save adds `"journal_entries"` |
| 3. `New Game` reset | `MainMenu._on_new_game()` → `GameState.new_game()` | `flags` clears to `{}`, `current_scene` resets to `"res://scenes/game.tscn"`, `journal_entries` clears to `[]` | `journal_reset` signal runs `Journal.reset()`, clearing `entries` and UI rows | In-memory state wiped; existing `user://save.json` untouched on disk until next save |
| 4. Duplicate discovery | `add_journal_entry(id)` or `Journal.add_entry(id)` called twice with same ID (or duplicate IDs on disk) | Second call returns `false`; one copy kept at original index; no extra signals emitted | Single row retained in original discovery slot; duplicates in JSON collapse on `restore()` | Unchanged |
| 5. Malformed data | `"journal_entries"` is `null`, scalar/dict (`"bad"`, `42`, `{}`), or array with broken items (`[null, 99, "", "edith_log_01"]`) | `load_game()` logs `push_warning()` and still returns `true`; keeps valid string IDs or defaults to `[]` | `restore()` skips invalid values safely without failing or duplicating rows | `"scene"` and `"flags"` still restore intact |

## Detailed Case Walkthroughs

### 1. Normal Save / Continue

- **Setup**: Start a session, set a story flag (e.g., `GameState.set_flag("trusted_edith", true)`), and discover two logs in order (`Journal.add_entry("edith_log_01")` followed by `Journal.add_entry("edith_log_02")`).
- **Code path**:
  1. `GameState.save_game()` serializes `"version": 1`, `"scene"`, `"flags"`, and `"journal_entries": ["edith_log_01", "edith_log_02"]` to `user://save.json`.
  2. Clicking `Continue` in `scripts/main_menu.gd` calls `GameState.load_game()`.
  3. `load_game()` restores `current_scene` and `flags`, calls `restore_journal(data["journal_entries"], false)` (clearing prior RAM state before copying valid strings), emits `journal_changed` and `state_changed`, and transitions to `GameState.current_scene`.
- **Pass criteria**: `load_game()` returns `true`, `GameState.get_journal_entries()` equals `["edith_log_01", "edith_log_02"]` in order, `GameState.get_flag("trusted_edith")` remains `true`, and `Continue` after an earlier session replaces (never appends onto) in-memory entries.

### 2. Legacy Save (No `journal_entries` Key)

- **Setup**: Place a pre-journal `user://save.json` on disk (and optionally pre-populate `GameState.journal_entries` in RAM to simulate an active session):
  ```json
  {
  	"flags": {
  		"trusted_edith": true,
  		"radioed_tom": true
  	},
  	"scene": "res://scenes/game.tscn",
  	"version": 1
  }
  ```
- **Code path**:
  1. `load_game()` sees `not data.has("journal_entries")` and calls `reset_journal(false)` instead of `restore_journal()`, avoiding false warnings on valid older saves.
  2. `journal_entries` clears to `[]`, `journal_changed([])` triggers `Journal.reset()` on any open `Journal` node, and `load_game()` returns `true`.
- **Pass criteria**: Load succeeds without warnings or errors, `current_scene` and both story flags (`trusted_edith`, `radioed_tom`) remain intact, `journal_entries` is `[]` (no stale session bleed), and a subsequent `save_game()` writes `"journal_entries"` cleanly alongside the preserved flags.

### 3. New Game Reset

- **Setup**: Load or play a session where `flags` has `"trusted_edith": true` and `journal_entries` has `["edith_log_01"]`, return to the title screen, and click `New Game`.
- **Code path**:
  1. `MainMenu._on_new_game()` invokes `GameState.new_game()` and switches to `"res://scenes/game.tscn"`.
  2. `GameState.new_game()` runs `flags.clear()`, resets `current_scene = "res://scenes/game.tscn"`, and calls `reset_journal()`.
  3. `reset_journal()` clears `journal_entries` and emits `journal_reset`, `journal_changed([])`, and `state_changed`; any live `Journal` control connected to `journal_reset` calls `reset()` immediately.
- **Pass criteria**: `GameState.flags` is `{}`, `GameState.get_journal_entries()` is `[]`, opening the journal shows `"No log entries recorded yet."`, and any prior `user://save.json` on disk stays untouched until the player explicitly saves again.

### 4. Duplicate Discovery

- **Setup**: Discover `"edith_log_01"`, then `"edith_log_02"`, then trigger `"edith_log_01"` (or `"  edith_log_01  "`) a second time—and also test loading a hand-edited `save.json` containing `["edith_log_01", "edith_log_01"]`.
- **Code path**:
  1. `GameState.add_journal_entry()` and `Journal.add_entry()` trim whitespace with `strip_edges()` and check `has(clean_id)`; when already present, both return `false` immediately without mutating the array or emitting signals.
  2. On load, `restore_journal()` and `Journal.restore()` check `not ...has(clean_id)` on each element before appending.
- **Pass criteria**: `"edith_log_01"` is stored once at index `0` (`["edith_log_01", "edith_log_02"]`), the repeat call returns `false` with zero extra signal emissions, and duplicate entries in a hand-edited JSON file collapse to one copy on `Continue`.

### 5. Malformed Journal Data

- **Setup**: Test `load_game()` against two malformed `user://save.json` shapes that still have valid `"scene"` and `"flags"`:
  - **Wrong outer type**: `"journal_entries": "edith_log_01"`, `"journal_entries": 42`, `"journal_entries": null`, or `"journal_entries": {"entries": []}`.
  - **Broken inner structure**: `"journal_entries": ["edith_log_01", null, 99, {"bad": true}, ["nested"], "", "   ", "edith_log_02"]`.
- **Code path**:
  1. `load_game()` restores `current_scene` and `flags` first, then passes `data["journal_entries"]` into `restore_journal(..., false)`.
  2. For `null` or non-`Array` outer values, `restore_journal()` clears `journal_entries` to `[]` and logs a non-fatal `push_warning()` naming the actual type via `type_string()`.
  3. For `Array` values containing non-strings or blank/whitespace strings, `restore_journal()` logs a `push_warning()` per bad element, skips it, and retains valid trimmed string IDs in order.
- **Pass criteria**: `load_game()` still returns `true` in every sub-case, `"scene"` and `"flags"` never fail or reset, wrong outer types yield `[]`, and the mixed broken array recovers `["edith_log_01", "edith_log_02"]`.
