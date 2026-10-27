extends EstragonSurface
## Ordinary GDScript wiring. Gogo-generated signal connections belong to T07.

var _status: EstragonText
var _count: int = 0


func _init() -> void:
	var column := EstragonVBox.new()
	column.gap = 16
	var heading := EstragonText.new()
	heading.text = "Estragon: independent interactive components"
	heading.font_size = 26
	column.add_child(heading)
	_status = EstragonText.new()
	_status.text = "Count: 0 — click either button"
	column.add_child(_status)
	var row := EstragonHBox.new()
	row.gap = 12
	row.fill_width = true
	var increment := EstragonButton.new()
	increment.text = "Add one"
	increment.fill_width = true
	increment.pressed.connect(_increment)
	row.add_child(increment)
	var reset := EstragonButton.new()
	reset.text = "Reset"
	reset.fill_width = true
	reset.pressed.connect(_reset)
	row.add_child(reset)
	column.add_child(row)
	var disabled := EstragonButton.new()
	disabled.text = "Disabled"
	disabled.disabled = true
	column.add_child(disabled)
	var instructions := EstragonText.new()
	instructions.text = "Hover and hold to see states.\nRelease outside to cancel. Resize to reflow the row."
	instructions.color = Color("bdb4cc")
	column.add_child(instructions)
	set_root(column)


func _increment() -> void:
	_count += 1
	_status.text = "Count: %d — Add one handler ran" % _count
	print("Estragon Add one: ", _count)


func _reset() -> void:
	_count = 0
	_status.text = "Count: 0 — Reset handler ran"
	print("Estragon Reset")
