extends Button

# Nicholas Tran
# To create keybinds, link button node to this script. 
# Add original input map in Project -> Project Settings -> Input Map
# Change button node name to the input map's name. EX: "swtich_camera"

var action_name := ""
var waiting := false
var pending_keycode: int = -1


func _ready():
	action_name = name
	set_process_unhandled_input(true)

func _pressed():
	waiting = true
	text = "Press a key..."
	release_focus()

func _unhandled_input(event):
	if waiting and event is InputEventKey and event.pressed:
		pending_keycode = event.physical_keycode
		waiting = false

		# APPLY IMMEDIATELY (old behavior)
		InputMap.action_erase_events(action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = pending_keycode
		InputMap.action_add_event(action_name, ev)
		
		refresh_label()
# Saves bindings
func _save_binding(action: String, keycode: int):
	var cfg := ConfigFile.new()
	cfg.load("user://controls.cfg")
	cfg.set_value("bindings", action, keycode)
	cfg.save("user://controls.cfg")

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

		
func apply_pending_key():
	print("APPLYING:", action_name, "pending:", pending_keycode)
	if pending_keycode == -1:
		return
	InputMap.action_erase_events(action_name)
	var ev := InputEventKey.new()
	ev.physical_keycode = pending_keycode
	InputMap.action_add_event(action_name, ev)
	print("APPLYING TO ACTION:", action_name)
	print("ACTIONS IN INPUTMAP:", InputMap.get_actions())


func clear_pending_key():
	pending_keycode = -1
	refresh_label()
