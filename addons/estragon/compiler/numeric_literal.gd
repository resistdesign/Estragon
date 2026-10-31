@tool
extends RefCounted
## Canonicalize validated decimal text without a binary-float formatting round trip.
## This never rewrites authored GDScript; native conversion still owns rounding.
static func normalize(text: String) -> String:
	var sign := "-" if text.begins_with("-") else ""
	if text.begins_with("-") or text.begins_with("+"): text = text.substr(1)
	var parts := text.to_lower().split("e")
	var point := parts[0].find(".")
	if point < 0: point = parts[0].length()
	var digits := parts[0].replace(".", "")
	var first: int = 0
	while first < digits.length() and digits[first] == "0": first += 1
	if first == digits.length(): return "0.0"
	var exponent: int = 0
	if parts.size() == 2:
		var raw := parts[1]
		var negative := raw.begins_with("-")
		if raw.begins_with("-") or raw.begins_with("+"): raw = raw.substr(1)
		var exponent_start: int = 0
		while exponent_start + 1 < raw.length() and raw[exponent_start] == "0": exponent_start += 1
		raw = raw.substr(exponent_start)
		# Exponents beyond this cannot be offset by any Godot String's length.
		# Bound integer conversion, preserving native overflow/underflow behavior.
		exponent = 10000000000 if raw.length() > 10 else raw.to_int()
		if negative: exponent = -exponent
	exponent += point - first - 1
	# Bound after applying the decimal-point offset. This prevents the native
	# converter's 32-bit exponent accumulator wrapping and bypassing finiteness.
	if exponent > 400: exponent = 400
	elif exponent < -400: exponent = -400
	var last := digits.length() - 1
	while last > first and digits[last] == "0": last -= 1
	digits = digits.substr(first, last - first + 1)
	# Keep ordinary readable fixed tokens, but never let leading zeros consume
	# native conversion's 18-digit mantissa budget. Small/large values use e.
	var fixed_point := exponent + 1
	if exponent >= -6 and exponent <= 20 and (fixed_point > 0 or 1 - fixed_point + digits.length() <= 18):
		if fixed_point >= digits.length(): return sign + digits + "0".repeat(fixed_point - digits.length()) + ".0"
		if fixed_point > 0: return sign + digits.substr(0, fixed_point) + "." + digits.substr(fixed_point)
		return sign + "0." + "0".repeat(-fixed_point) + digits
	var coefficient := digits.substr(0, 1)
	if digits.length() > 1: coefficient += "." + digits.substr(1)
	return sign + coefficient + "e" + str(exponent)
