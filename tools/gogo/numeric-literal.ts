/** Validated decimal normalization; native engines still own float conversion. */
export function normalizeNumber(text: string): string {
    const sign = text.startsWith("-") ? "-" : "";
    text = text.replace(/^[+-]/, "").toLowerCase();
    const [mantissa, rawExponent] = text.split("e");
    const point = mantissa!.includes(".") ? mantissa!.indexOf(".") : mantissa!.length;
    let digits = mantissa!.replace(".", "");
    const first = digits.search(/[1-9]/);
    if (first < 0) return "0.0";
    const negative = rawExponent?.startsWith("-") ?? false;
    const raw = (rawExponent ?? "0").replace(/^[+-]/, "").replace(/^0+(?=\d)/, "");
    let exponent = raw.length > 10 ? 10000000000 : Number(raw);
    if (negative) exponent = -exponent;
    exponent += point - first - 1;
    digits = digits.slice(first).replace(/0+$/, "");
    const fixedPoint = exponent + 1;
    if (exponent >= -6 && exponent <= 20 && (fixedPoint > 0 || 1 - fixedPoint + digits.length <= 18)) {
        if (fixedPoint >= digits.length) return sign + digits + "0".repeat(fixedPoint - digits.length) + ".0";
        if (fixedPoint > 0) return sign + digits.slice(0, fixedPoint) + "." + digits.slice(fixedPoint);
        return sign + "0." + "0".repeat(-fixedPoint) + digits;
    }
    const coefficient = digits[0]! + (digits.length > 1 ? "." + digits.slice(1) : "");
    return sign + coefficient + "e" + exponent;
}
