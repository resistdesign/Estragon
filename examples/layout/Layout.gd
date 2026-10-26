extends EstragonSurface
## Hand-authored component demo; Gogo-to-GDScript compilation is a later task.


func _init() -> void:
	var column := EstragonVBox.new()
	column.gap = 16
	var header := EstragonRect.new()
	header.height = 64
	header.fill_width = true
	header.fill = Color("8566e0")
	column.add_child(header)
	var row := EstragonHBox.new()
	row.gap = 12
	row.fill_width = true
	row.fill_height = true
	var sidebar := EstragonRect.new()
	sidebar.width = 160
	sidebar.fill_height = true
	sidebar.fill = Color("30c9b0")
	row.add_child(sidebar)
	var content := EstragonRect.new()
	content.fill_width = true
	content.fill_height = true
	content.fill = Color("50466f")
	row.add_child(content)
	column.add_child(row)
	set_root(column)
