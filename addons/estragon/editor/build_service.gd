@tool
extends RefCounted
## Bounded direct subprocess adapter. No shell or user shell initialization.

const BUN_SETTING := "estragon/editor/bun_executable"
const TIMEOUT_SETTING := "estragon/editor/build_timeout_seconds"
const COMPILER := "res://tools/build-gogo.ts"


static func find_bun(configured: String = "") -> String:
	if not configured.is_empty():
		return configured if configured.is_absolute_path() and FileAccess.file_exists(configured) else ""
	var executable := "bun.exe" if OS.get_name() == "Windows" else "bun"
	var separator := ";" if OS.get_name() == "Windows" else ":"
	var candidates := PackedStringArray()
	for directory in OS.get_environment("PATH").split(separator, false):
		candidates.append(directory.path_join(executable))
	var home := OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME")
	candidates.append(home.path_join(".bun/bin/" + executable))
	candidates.append("/opt/homebrew/bin/bun")
	candidates.append("/usr/local/bin/bun")
	for candidate in candidates:
		if candidate.is_absolute_path() and FileAccess.file_exists(candidate):
			return candidate
	return ""


static func run_build(validate: bool = false) -> Dictionary:
	var bun := find_bun(str(ProjectSettings.get_setting(BUN_SETTING, "")))
	if bun.is_empty():
		return {"ok": false, "diagnostics": ["Estragon: Bun was not found. Install Bun 1.4.4 or set Project Settings > Estragon > Editor > Bun Executable to its absolute path."]}
	if not FileAccess.file_exists(COMPILER):
		return {"ok": false, "diagnostics": ["Estragon: missing res://tools/build-gogo.ts. Restore the compiler before Play."]}
	var report_path := ProjectSettings.globalize_path("res://.godot/estragon/build-report-%d.json" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	DirAccess.remove_absolute(report_path)
	var arguments := PackedStringArray([ProjectSettings.globalize_path(COMPILER), "--project", ProjectSettings.globalize_path("res://"), "--report", report_path])
	if validate:
		arguments.append_array(["--godot", OS.get_executable_path()])
	var process := OS.execute_with_pipe(bun, arguments, false)
	if process.is_empty():
		return {"ok": false, "diagnostics": ["Estragon: cannot start Bun at " + bun + ". Check executable permissions and the configured path."]}
	var pid: int = process.pid
	var output := ""
	var started := Time.get_ticks_msec()
	var timeout := clampf(float(ProjectSettings.get_setting(TIMEOUT_SETTING, 30.0)), 1.0, 120.0) * 1000.0
	while OS.is_process_running(pid):
		output += _drain(process)
		if Time.get_ticks_msec() - started > timeout:
			OS.kill(pid)
			return {"ok": false, "diagnostics": ["Estragon: compiler timed out; Play blocked. Check the compiler/Bun installation.\n" + output]}
		OS.delay_msec(10)
	output += _drain(process)
	var status := OS.get_process_exit_code(pid)
	if not FileAccess.file_exists(report_path):
		return {"ok": false, "diagnostics": ["Estragon: compiler exited without a build report (exit %d). Check Bun/compiler installation.\n%s" % [status, output]]}
	var report = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not report is Dictionary or not report.get("ok") is bool or not report.get("diagnostics") is Array:
		return {"ok": false, "diagnostics": ["Estragon: invalid compiler report; Play blocked.\n" + output]}
	if status != 0 and report.ok:
		return {"ok": false, "diagnostics": ["Estragon: compiler crashed (exit %d); Play blocked.\n%s" % [status, output]]}
	return report


static func _drain(process: Dictionary) -> String:
	var output := ""
	for key in ["stdio", "stderr"]:
		var pipe: FileAccess = process[key]
		# Nonblocking pipes: read bounded chunks until no bytes are available.
		while true:
			var bytes := pipe.get_buffer(4096)
			if bytes.is_empty():
				break
			output += bytes.get_string_from_utf8()
	return output
