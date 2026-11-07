@tool
extends CodeEdit
## Documented public virtual. Attached only to otherwise scriptless Gogo editors.
## Popup navigation and confirmation gestures remain native; commit is synchronous.
var estragon_accept: Callable
func _confirm_code_completion(replace: bool) -> void:
	if estragon_accept.is_valid(): estragon_accept.call(replace)
