extends Button

@export var tab := 0

func _pressed() -> void:
	var parent: Node = self

	while parent and not parent is TabContainer:
		parent = parent.get_parent()

	var c := parent as TabContainer
	assert(c, "No TabContainer parent for %s" % get_path())
	c.current_tab = tab
