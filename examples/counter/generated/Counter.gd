extends EstragonSurface

var count: int = 0


func _init() -> void:
    set_root(build_view())


func increment() -> void:
    count += 1
    set_root(build_view())


func reset_count() -> void:
    count = 0
    set_root(build_view())


func build_view() -> EstragonVBox:
    return (
        _gogo_build_0(
            (12),
            ("Count: %d" % count),
            (24),
            (increment),
            (count == 0),
            (reset_count)
        )
    )



static func _gogo_build_0(
    _gogo_value_0: float,
    _gogo_value_1: String,
    _gogo_value_2: int,
    _gogo_value_3: Callable,
    _gogo_value_4: bool,
    _gogo_value_5: Callable
) -> EstragonVBox:
    var component_0: EstragonVBox = EstragonVBox.new()
    component_0.gap = _gogo_value_0
    var component_1: EstragonText = EstragonText.new()
    component_1.text = "Estragon Gogo Counter"
    component_1.font_size = 26
    component_1.color = Color("#bba2efff")
    if component_0.add_child(component_1) != OK:
        push_error("examples/counter/Counter.gogo:23:13: Gogo child must be a live, uniquely owned component")
    var component_2: EstragonText = EstragonText.new()
    component_2.text = _gogo_value_1
    component_2.font_size = _gogo_value_2
    if component_0.add_child(component_2) != OK:
        push_error("examples/counter/Counter.gogo:24:13: Gogo child must be a live, uniquely owned component")
    var component_3: EstragonHBox = EstragonHBox.new()
    component_3.gap = 12.0
    component_3.fill_width = true
    var component_4: EstragonButton = EstragonButton.new()
    component_4.text = "+"
    component_4.fill_width = true
    var _gogo_callback_component_4: Variant = _gogo_value_3
    if not _gogo_value_3.is_valid() or (Engine.get_version_info()["minor"] >= 3 and _gogo_callback_component_4.get_argument_count() != 0):
        push_error("examples/counter/Counter.gogo:26:60: Button.pressed requires a valid zero-argument Callable with a live target")
    elif _gogo_callback_component_4.get_object() is EstragonDisplayObject and (_gogo_callback_component_4.get_object() as EstragonDisplayObject).is_disposed():
        push_error("examples/counter/Counter.gogo:26:60: Button.pressed requires a valid zero-argument Callable with a live target")
    elif component_4.pressed.connect(_gogo_value_3) != OK:
        push_error("examples/counter/Counter.gogo:26:60: Button.pressed requires a valid zero-argument Callable with a live target")
    if component_3.add_child(component_4) != OK:
        push_error("examples/counter/Counter.gogo:26:17: Gogo child must be a live, uniquely owned component")
    var component_5: EstragonButton = EstragonButton.new()
    component_5.text = "Reset"
    component_5.fill_width = true
    component_5.disabled = _gogo_value_4
    var _gogo_callback_component_5: Variant = _gogo_value_5
    if not _gogo_value_5.is_valid() or (Engine.get_version_info()["minor"] >= 3 and _gogo_callback_component_5.get_argument_count() != 0):
        push_error("examples/counter/Counter.gogo:27:86: Button.pressed requires a valid zero-argument Callable with a live target")
    elif _gogo_callback_component_5.get_object() is EstragonDisplayObject and (_gogo_callback_component_5.get_object() as EstragonDisplayObject).is_disposed():
        push_error("examples/counter/Counter.gogo:27:86: Button.pressed requires a valid zero-argument Callable with a live target")
    elif component_5.pressed.connect(_gogo_value_5) != OK:
        push_error("examples/counter/Counter.gogo:27:86: Button.pressed requires a valid zero-argument Callable with a live target")
    if component_3.add_child(component_5) != OK:
        push_error("examples/counter/Counter.gogo:27:17: Gogo child must be a live, uniquely owned component")
    if component_0.add_child(component_3) != OK:
        push_error("examples/counter/Counter.gogo:25:13: Gogo child must be a live, uniquely owned component")
    var component_6: EstragonText = EstragonText.new()
    component_6.text = "Gogo generates the signal connections. Explicit rebuild; automatic cleanup."
    component_6.font_size = 16
    if component_0.add_child(component_6) != OK:
        push_error("examples/counter/Counter.gogo:29:13: Gogo child must be a live, uniquely owned component")
    return component_0
