import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { GogoCompileError } from "../tools/gogo/model.ts";
import { parseMarkup, parseMarkupExpressionAt } from "../tools/gogo/parser.ts";
import { validateComponent } from "../tools/gogo/validate.ts";
import { transpileGogo } from "../tools/transpile-gogo.ts";
import { compileExample, EXAMPLE_OUTPUT } from "../tools/check-gdscript.ts";

const root = resolve(import.meta.dir, "..");
const temporary: string[] = [];
afterEach(async () => { for (const path of temporary.splice(0)) await rm(path, { recursive: true, force: true }); });

function diagnose(source: string): GogoCompileError {
    try { transpileGogo(source, "test.gogo"); }
    catch (error) {
        expect(error).toBeInstanceOf(GogoCompileError);
        return error as GogoCompileError;
    }
    throw new Error("Expected compilation to fail");
}

describe("T04 markup syntax and typed expressions", () => {
    test("parses nested expressions, matching/empty tags, comments and both quote styles", () => {
        const syntax = parseMarkup("<!-- before -->\n<VBox gap='2'><HBox /><Rect></Rect></VBox><!-- after -->");
        expect(syntax.kind).toBe("component-expression");
        expect(syntax.name).toBe("VBox");
        expect(syntax.children.map(child => child.name)).toEqual(["HBox", "Rect"]);
        expect(syntax.attributes[0]?.value).toBe("2");
        expect(syntax.span.start).toEqual({ offset: 16, line: 2, column: 1 });
        expect(syntax.nameSpan.start.column).toBe(2);
    });
    test("exposes an offset-based expression entrypoint without parsing surrounding GDScript", () => {
        const source = "func render():\r\n\treturn <VBox><Rect /></VBox>\r\n# later source";
        const start = source.indexOf("<");
        const node = parseMarkupExpressionAt(source, start, "mixed.gogo");
        expect(node.span.start).toEqual({ offset: start, line: 2, column: 9 });
        expect(source.slice(node.span.end.offset)).toBe("\r\n# later source");
        expect(() => parseMarkupExpressionAt(source, -1)).toThrow(RangeError);
    });
    test("validates dimensions, fill flags, gaps and RGBA colors as typed literals", () => {
        const node = validateComponent(parseMarkup('<VBox width="auto" height="0" fill_width="false" gap=".5"><Rect width="1e2" fill="#AABBCC80" /></VBox>'));
        expect(node.component).toBe("VBox");
        expect(node.properties.map(p => [p.name, p.value.kind, p.value.value])).toEqual([
            ["width", "number-literal", -1], ["height", "number-literal", 0],
            ["fill_width", "boolean-literal", false], ["gap", "number-literal", 0.5],
        ]);
        expect(node.children[0]?.properties[1]?.value).toMatchObject({ kind: "color-literal", value: "#aabbcc80" });
    });
    test("reports exact file, property and value locations, including CRLF", () => {
        const error = diagnose('<Rect\r\n  width="bad" />');
        expect(error.sourceName).toBe("test.gogo");
        expect(error.span.start).toEqual({ offset: 16, line: 2, column: 10 });
        expect(error.message).toStartWith("test.gogo:2:10:");
        expect(diagnose('\n  <Bogus/>').span.start).toEqual({ offset: 4, line: 2, column: 4 });
        expect(diagnose('<Rect\n  unknown="2"/>').span.start.column).toBe(3);
    });
    test("bounds nesting with a located diagnostic instead of a stack overflow", () => {
        const error = diagnose("<VBox>".repeat(257) + "</VBox>".repeat(257));
        expect(error.message).toContain("nesting exceeds");
    });

    const invalid: [string, string][] = [
        ["", "Expected"], ["<Rect", "terminator"], ["<Rect width=\"2", "Unterminated property"],
        ["<!-- missing", "Unterminated comment"], ["<VBox>", "Missing closing tag"],
        ["<VBox></HBox>", "Expected </VBox>"], ["<Rect/><Rect/>", "one component"],
        ["<VBox>text</VBox>", "Only component children"], ["<Rect><Rect/></Rect>", "Rect is a leaf"],
        ["<Button/>", "Unknown component"], ["<constructor/>", "Unknown component"],
        ["<fx:VBox/>", "Namespace-prefixed"], ['<VBox xmlns="urn:old"/>', "Namespaces"],
        ['<Rect fx:width="2"/>', "prefixed properties"], ['<Rect gap="1"/>', "Unsupported property"],
        ['<VBox fill="#abcdef"/>', "Unsupported property"], ['<Rect id="x"/>', "Unsupported property"],
        ['<Rect width="1" width="2"/>', "Duplicate property"], ['<Rect width="1"height="2"/>', "whitespace"],
        ['<Rect width={2}/>', "quoted literal"], ['<Rect width="{2}"/>', "finite nonnegative"],
        ['<Rect width="-1"/>', "use auto"], ['<Rect height="-2"/>', "nonnegative"],
        ['<Rect width="NaN"/>', "finite nonnegative"], ['<Rect width="1e400"/>', "finite in runtime"],
        ['<Rect width="1e39"/>', "finite in runtime"], ['<Rect width="0x10"/>', "finite nonnegative"],
        ['<Rect width="2px"/>', "finite nonnegative"],
        ['<Rect width="2\n"/>', "finite nonnegative"], ['<Rect fill="#aabbcc\n"/>', "#RRGGBB"], ['<Rect width=" 2 "/>', "finite nonnegative"],
        ['<HBox gap="-1"/>', "nonnegative"], ['<Rect fill_width="True"/>', "true or false"],
        ['<Rect fill_height="1"/>', "true or false"], ['<Rect fill="#fff"/>', "#RRGGBB"],
        ['<Rect fill="red"/>', "#RRGGBB"], ['<Rect width="&#50;"/>', "entities"],
        ['<Rect width="<"/>', "Markup delimiters"], ['<Rect width="\\2"/>', "escapes"],
        ['<?xml version="1.0"?><Rect/>', "Expected component"],
        ['<!DOCTYPE Rect><Rect/>', "Expected component"],
        ["extends VBox\n<Rect/>", "Expected"],
    ];
    test.each(invalid)("rejects unsupported/malformed source %s", (source, message) => {
        const error = diagnose(source);
        expect(error.message).toContain(message);
        expect(error.span.start.line).toBeGreaterThan(0);
        expect(error.span.start.column).toBeGreaterThan(0);
    });
});

describe("T04 GDScript output", () => {
    test("emits ordinary typed component construction and surface ownership", () => {
        const code = transpileGogo('<VBox gap="2"><HBox><Rect width="3" fill="#AAbbCC"/></HBox></VBox>', "Demo.gogo");
        expect(code).toContain("extends EstragonSurface");
        expect(code).toContain("var component_0: EstragonVBox = EstragonVBox.new()");
        expect(code).toContain("var component_1: EstragonHBox = EstragonHBox.new()");
        expect(code).toContain("var component_2: EstragonRect = EstragonRect.new()");
        expect(code).toContain('component_2.fill = Color("#aabbccff")');
        expect(code.indexOf("component_1.add_child(component_2)")).toBeLessThan(code.indexOf("component_0.add_child(component_1)"));
        expect(code).toEndWith("\tset_root(component_0)\n");
        expect(code).not.toMatch(/JSON|parse_string|dispose|Control\.new|Node\.new/);
    });
    test("is repeatable, normalizes literals and canonicalizes property order", () => {
        const source = '<Rect width="1e2" height="0" fill_width="true"/>';
        expect(transpileGogo(source)).toBe(transpileGogo(source));
        expect(transpileGogo(source)).toBe(transpileGogo('<Rect fill_width="true" height="-0" width="100"/>'));
        expect(transpileGogo('<Rect width="1e20"/>')).toContain("width = 100000000000000000000.0");
        expect(transpileGogo('<Rect width="1e-5"/>')).toContain("width = 0.00001");
    });
    test("does not turn source labels or property text into executable code", () => {
        const code = transpileGogo("<Rect/>", 'source\nprint("injected")\r.gogo');
        expect(code.split("\n")[1]).toContain('\\nprint(\\"injected\\")\\r.gogo');
        expect(() => transpileGogo('<Rect width="1; print(123)"/>')).toThrow(GogoCompileError);
        expect(() => transpileGogo('<Rect fill=\'#fff"); print(123)\'/>')).toThrow(GogoCompileError);
    });
    test("matches the committed generated example byte-for-byte", async () => {
        expect(await compileExample(root)).toBe(await readFile(join(root, EXAMPLE_OUTPUT), "utf8"));
    });
});

describe("T04 CLI", () => {
    async function fixture(source: string): Promise<{ input: string; output: string }> {
        const folder = await mkdtemp(join(tmpdir(), "estragon-transpile-"));
        temporary.push(folder);
        const input = join(folder, "Input.gogo");
        await writeFile(input, source);
        return { input, output: join(folder, "Output.gd") };
    }
    function cli(...args: string[]) {
        return Bun.spawnSync([process.execPath, join(root, "tools/transpile-gogo.ts"), ...args], { cwd: root });
    }
    test("writes a reproducible .gd output to the requested path", async () => {
        const { input, output } = await fixture('<Rect width="4"/>');
        expect(cli(input, "--output", output).exitCode).toBe(0);
        expect(await readFile(output, "utf8")).toBe(transpileGogo('<Rect width="4"/>', input));
    });
    test("reports located errors and preserves previous output on invalid input", async () => {
        const { input, output } = await fixture('<VBox>\n <Rect bad="2"/>\n</VBox>');
        await writeFile(output, "previous output");
        const result = cli(input, "--output", output);
        expect(result.exitCode).toBe(1);
        expect(result.stderr.toString()).toContain(`${input}:2:8: Unsupported property`);
        expect(await readFile(output, "utf8")).toBe("previous output");
    });
    test("rejects bad arguments, unknown flags, same-path output and wrong extension", async () => {
        const { input, output } = await fixture("<Rect/>");
        expect(cli().exitCode).toBe(1);
        expect(cli(input, "--output").exitCode).toBe(1);
        expect(cli(input, "--other", output).exitCode).toBe(1);
        expect(cli(input, "--output", output, "extra").exitCode).toBe(1);
        expect(cli(input, "--output", input).exitCode).toBe(1);
        expect(await readFile(input, "utf8")).toBe("<Rect/>");
        expect(cli(input, "--output", output + ".json").exitCode).toBe(1);
    });
});
