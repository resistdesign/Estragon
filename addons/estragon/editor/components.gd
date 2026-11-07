@tool
extends RefCounted
## Trusted installed resources, not guessed global classes or installation roots.
const ITEMS := [
	{"alias":"Text","canonical":"EstragonText","script":preload("../runtime/node/text.gd"),"dimension":2,"origin":"native widget"},
	{"alias":"Rect","canonical":"EstragonRect","script":preload("../runtime/node/rect.gd"),"dimension":2,"origin":"native widget"},
	{"alias":"UiButton","canonical":"EstragonButton","script":preload("../runtime/node/button.gd"),"dimension":2,"origin":"native widget"},
	{"alias":"VBox","canonical":"EstragonVBox","script":preload("../runtime/node/vbox.gd"),"dimension":2,"origin":"native layout"},
	{"alias":"HBox","canonical":"EstragonHBox","script":preload("../runtime/node/hbox.gd"),"dimension":2,"origin":"native layout"},
	{"alias":"Entry2D","canonical":"Estragon2D","script":preload("../runtime/node/estragon_2d.gd"),"dimension":2,"origin":"layout entry"},
	{"alias":"Entry3D","canonical":"Estragon3D","script":preload("../runtime/node/estragon_3d.gd"),"dimension":3,"origin":"layout entry"},
	{"alias":"Element","canonical":"Element","script":preload("../runtime/composition/element.gd"),"dimension":0,"origin":"GGX description type"}
]
static func path(item: Dictionary) -> String: return (item.script as Script).resource_path
static func named(name: String) -> Dictionary:
	for item in ITEMS:
		if name in [item.alias,item.canonical]: return item
	return {}
