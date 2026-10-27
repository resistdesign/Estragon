extends EstragonSurface
# Authored GDScript: literals containing markup are ordinary strings.
const DESCRIPTION: String = "<Rect> is not markup inside a string"
var spacing: float = 12.0
var header_height: float = 48.0
var sidebar_width: float = 120.0
var accent: Color = Color("8566e0")
var constructions: int = 0


func _init() -> void:
    set_root(build_view())


func make_panel(panel_width: float, color: Color) -> EstragonRect:
    constructions += 1
    return _gogo_build_0((panel_width), (true), (color))


func build_view() -> EstragonVBox:
    var small: bool = sidebar_width < 80.0
    var actual_gap: float = spacing / 2.0 if small else spacing
    return (
        _gogo_build_1(
            (actual_gap),
            (header_height + 8.0),
            (accent),
            (spacing),
            (true),
            (make_panel(sidebar_width, Color("30c9b0"))),
            (true),
            (Color("50466f") if sidebar_width > 0 else Color.BLACK)
        )
    )


func rebuild() -> void:
    # Explicit construction-time values, not reactive bindings.
    set_root(build_view())



static func _gogo_build_0(_gogo_value_0: float, _gogo_value_1: bool, _gogo_value_2: Color) -> EstragonRect:
    var component_0: EstragonRect = EstragonRect.new()
    component_0.width = _gogo_value_0
    component_0.fill_height = _gogo_value_1
    component_0.fill = _gogo_value_2
    return component_0


static func _gogo_build_1(
    _gogo_value_0: float,
    _gogo_value_1: float,
    _gogo_value_2: Color,
    _gogo_value_3: float,
    _gogo_value_4: bool,
    _gogo_value_5: EstragonDisplayObject,
    _gogo_value_6: bool,
    _gogo_value_7: Color
) -> EstragonVBox:
    var component_0: EstragonVBox = EstragonVBox.new()
    component_0.gap = _gogo_value_0
    var component_1: EstragonRect = EstragonRect.new()
    component_1.height = _gogo_value_1
    component_1.fill_width = true
    component_1.fill = _gogo_value_2
    if component_0.add_child(component_1) != OK:
        push_error("examples/mixed/Mixed.gogo:25:13: Gogo child must be a live, uniquely owned component")
    var component_2: EstragonHBox = EstragonHBox.new()
    component_2.gap = _gogo_value_3
    component_2.fill_width = _gogo_value_4
    component_2.fill_height = true
    if component_2.add_child(_gogo_value_5) != OK:
        push_error("examples/mixed/Mixed.gogo:27:17: Gogo child must be a live, uniquely owned component")
    var component_3: EstragonRect = EstragonRect.new()
    component_3.fill_width = true
    component_3.fill_height = _gogo_value_6
    component_3.fill = _gogo_value_7
    if component_2.add_child(component_3) != OK:
        push_error("examples/mixed/Mixed.gogo:28:17: Gogo child must be a live, uniquely owned component")
    if component_0.add_child(component_2) != OK:
        push_error("examples/mixed/Mixed.gogo:26:13: Gogo child must be a live, uniquely owned component")
    return component_0
