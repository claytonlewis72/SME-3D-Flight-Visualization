#|------------------------------------------------------------------------------------
#|   Unclassified
#|------------------------------------------------------------------------------------
#|
#|   SME Solutions, Inc.
#|   Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|   SME Solutions Proprietary Information
#|
#|------------------------------------------------------------------------------------
#|
#|   File Name   : key_bind_button.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Self-contained key-rebinding button. Attach to any Button node whose
#|       name matches an existing InputMap action. When clicked, the button
#|       enters a listening state and captures the next physical key press as
#|       a pending binding. The binding is not written to InputMap or disk
#|       until apply_pending_key is called externally (typically on Save in
#|       the config window).
#|
#|   Notes       : To create a keybind, link a Button node to this script and
#|                 name the node to match the target InputMap action exactly.
#|                 Register the action first in Project > Project Settings >
#|                 Input Map.
#|
#|   Author      : Nicholas Tran
#|
#|------------------------------------------------------------------------------------

extends Button

## Self-contained key-rebinding button that captures a new physical key and
## defers applying it until explicitly committed.
##
## The button derives its [member action_name] from the node's [member Node.name]
## so it requires no manual configuration beyond being named to match an
## [InputMap] action. Clicking the button enters a listening state; the next
## [InputEventKey] press is stored as [member pending_keycode] and displayed
## immediately, but [InputMap] is not modified until [method apply_pending_key]
## is called. This allows the parent config window to commit or discard all
## pending bindings as a batch on Save or Cancel respectively.


## The [InputMap] action this button controls.
##
## Derived from [member Node.name] in [method _ready]. Must exactly match an
## action registered in [b]Project > Project Settings > Input Map[/b].
var action_name := ""

## Whether the button is currently waiting for a key press.
##
## Set to [code]true[/code] when the button is clicked and cleared once a
## valid [InputEventKey] is received in [method _unhandled_input].
var waiting := false

## Physical keycode of the key selected by the operator but not yet applied.
##
## [code]-1[/code] when no pending change exists. Written to [InputMap] and
## [code]user://controls.cfg[/code] only when [method apply_pending_key] is
## called. Cleared by [method clear_pending_key].
var pending_keycode: int = -1


## Initialises [member action_name] from the node name and enables input listening.
func _ready():
	action_name = name
	set_process_unhandled_input(true)


## Enters the key-listening state when the button is clicked.
##
## Sets [member waiting] to [code]true[/code], updates the button label to
## prompt the operator, and releases focus so subsequent key events are not
## consumed by the button itself.
func _pressed():
	waiting = true
	text = "Press a key..."
	release_focus()


## Captures the next physical key press while [member waiting] is [code]true[/code].
##
## Stores the event's physical keycode in [member pending_keycode], clears
## [member waiting], and calls [method refresh_label] to display the newly
## selected key name. Only reacts to [InputEventKey] press events; all other
## event types are ignored. Input listening can be suspended entirely via
## [method enable_listening].
##
## Parameters:
##   event : InputEvent
##       The unhandled input event forwarded by the engine.
func _unhandled_input(event):
	if waiting and event is InputEventKey and event.pressed:
		pending_keycode = event.physical_keycode
		waiting = false
		refresh_label()
		

## Persists a single action binding to [code]user://controls.cfg[/code].
##
## Loads the existing config file (or creates a new one if absent), writes
## the given [param keycode] under the [code][bindings][/code] section keyed
## by [param action], and saves the file. Does not update [InputMap]; call
## [method apply_pending_key] for that.
##
## Parameters:
##   action  : String
##       The [InputMap] action name to store the binding under.
##   keycode : int
##       The physical keycode to associate with [param action].
func _save_binding(action: String, keycode: int):
	var cfg := ConfigFile.new()
	cfg.load("user://controls.cfg")
	cfg.set_value("bindings", action, keycode)
	cfg.save("user://controls.cfg")


## Updates the button label to reflect the current pending or active binding.
##
## Displays the human-readable name of [member pending_keycode] if a pending
## change exists. Otherwise reads the first [InputEventKey] event bound to
## [member action_name] in [InputMap] and displays its key name, or
## [code]"Unbound"[/code] if no key event is registered.
func refresh_label():
	# If user selected a new key but hasn't saved yet
	if pending_keycode != -1:
		text = OS.get_keycode_string(pending_keycode)
		return

	# Otherwise show the current InputMap binding
	var events = InputMap.action_get_events(action_name)
	if events.size() > 0 and events[0] is InputEventKey:
		text = OS.get_keycode_string(events[0].physical_keycode)
	else:
		text = "Unbound"


## Commits [member pending_keycode] to [InputMap].
##
## Called externally by the config window when the operator presses Save.
## Clears all existing events on [member action_name], creates a new
## [InputEventKey] with [member pending_keycode] as its physical keycode,
## and registers it. Has no effect if [member pending_keycode] is
## [code]-1[/code]. Does not write to [code]user://controls.cfg[/code];
## the caller is responsible for persisting bindings via
## [method DroneManager.save_bindings].
func apply_pending_key(): # Applies current added keys, only applies when saved is pressed
	print("APPLYING:", action_name, "pending:", pending_keycode)
	if pending_keycode == -1:
		return
	InputMap.action_erase_events(action_name)
	var ev := InputEventKey.new()
	ev.physical_keycode = pending_keycode
	InputMap.action_add_event(action_name, ev)
	print("APPLYING TO ACTION:", action_name)
	print("ACTIONS IN INPUTMAP:", InputMap.get_actions())
	

## Discards any pending key selection and restores the label to the active binding.
##
## Called externally by the config window when it is closed without saving.
## Resets [member pending_keycode] to [code]-1[/code] and calls
## [method refresh_label] so the button displays the currently active
## [InputMap] binding rather than the discarded selection.
func clear_pending_key():
	pending_keycode = -1
	refresh_label()
	

## Enables or disables unhandled input processing for this button.
##
## When [param enable] is [code]false[/code], [method _unhandled_input] will
## not fire and the button cannot enter or remain in a listening state. Called
## by the config window to suspend all rebinding buttons when the window is
## closed, preventing stale key captures from other scenes.
##
## Parameters:
##   enable : bool
##       [code]true[/code] to allow input capture; [code]false[/code] to suspend it.
func enable_listening(enable: bool):
	set_process_unhandled_input(enable)
