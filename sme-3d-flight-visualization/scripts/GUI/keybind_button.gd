extends Button

# Nicholas Tran
# To create keybinds, link button node to this script. 
# Add original input map in Project -> Project Settings -> Input Map
# Change button node name to the input map's name. EX: "swtich_camera"

var action_name := ""
var waiting := false

func _ready():
	action_name = name
	_update_button_label()

func _pressed():
	waiting = true
	text = "Press a key..."
	release_focus()

func _unhandled_input(event):
	if waiting and event is InputEventKey and event.pressed:
		waiting = false

		# Clear old bindings
		InputMap.action_erase_events(action_name)

		# Add new binding
		var ev := InputEventKey.new()
		ev.physical_keycode = event.physical_keycode
		InputMap.action_add_event(action_name, ev)

		# Update button label
		text = OS.get_keycode_string(event.physical_keycode)

		# save to config file
		_save_binding(action_name, event.physical_keycode)

# Saves bindings
func _save_binding(action: String, keycode: int):
	var cfg := ConfigFile.new()
	cfg.load("user://controls.cfg")
	cfg.set_value("bindings", action, keycode)
	cfg.save("user://controls.cfg")

# Update label for bindings when changed
func _update_button_label():
	var events = InputMap.action_get_events(action_name)
	if events.size() > 0 and events[0] is InputEventKey:
		text = OS.get_keycode_string(events[0].physical_keycode)
