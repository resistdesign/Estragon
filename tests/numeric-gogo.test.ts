import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { compileGogo } from "../tools/transpile-gogo.ts";
import { parseMarkup } from "../tools/gogo/parser.ts";
import { validateComponent } from "../tools/gogo/validate.ts";
import { emitLiteral } from "../tools/gogo/emit-gdscript.ts";

const fixture = JSON.parse(readFileSync(new URL("./compatibility/numeric_cases.json", import.meta.url), "utf8")) as {
    cases: { source: string; expected_bits: string }[];
};
for (const item of fixture.cases) {
    test(`numeric model and deterministic mapped emission: ${item.source}`, () => {
        const source = `<Rect width="${item.source}"/>`;
        const root = validateComponent(parseMarkup(source), "Numeric.gogo");
        const value = root.properties[0]!.value;
        expect(value.kind).toBe("number-literal");
        if (value.kind !== "number-literal") throw new Error("Expected numeric literal");
        const bytes = Buffer.alloc(8);
        bytes.writeDoubleLE(value.value);
        expect(bytes.toString("hex")).toBe(item.expected_bits);
        const token = emitLiteral(value);
        expect(/[.e]/.test(token)).toBe(true);
        const output = compileGogo(source, "Numeric.gogo");
        expect(output.code).toContain(".width = " + token);
        expect(output).toEqual(compileGogo(source, "Numeric.gogo"));
    });
}
test("canonicalizes equivalent decimal spellings before conversion", () => {
    for (const [left, right] of [["1e-20", "0.00000000000000000001"],
        ["1.2345678901234567e-20", "0.000000000000000000012345678901234567"],
        ["000000000000000000000012.5", "12.5"], ["1e2", "100"], ["-0.0", "0"]]) {
        expect(compileGogo(`<Rect width="${left}"/>`).code).toBe(compileGogo(`<Rect width="${right}"/>`).code);
    }
});
test("rejects malformed and overflowing values without allocating exponent-sized tokens", () => {
    for (const value of ["1e39", "1e999999999999999999999", "0.00000000000000000001e999999999999999999", "1;pass", "1e", "-1"]) {
        expect(() => compileGogo(`<Rect width="${value}"/>`)).toThrow();
    }
});
