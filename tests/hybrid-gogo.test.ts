import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { compileGogo, transpileGogo } from "../tools/transpile-gogo.ts";
import { GogoCompileError } from "../tools/gogo/model.ts";
import { parseHybrid } from "../tools/gogo/hybrid-parser.ts";
import { SourceFile } from "../tools/gogo/source.ts";
import { originalPosition, serializeSourceMap, traceGodotDiagnostics } from "../tools/gogo/source-map.ts";
import { compileHybridExample, HYBRID_OUTPUT } from "../tools/check-gdscript.ts";

const root = resolve(import.meta.dir, "..");
const folders: string[] = [];
afterEach(async () => { for (const path of folders.splice(0)) await rm(path, { recursive: true, force: true }); });
const module = (expression: string, indent = "\t") => `extends RefCounted\nfunc build(value: float) -> EstragonDisplayObject:\n${indent}return ${expression}\n`;

function error(source: string): GogoCompileError {
    try { compileGogo(source, "Bad.gogo"); }
    catch (result) { expect(result).toBeInstanceOf(GogoCompileError); return result as GogoCompileError; }
    throw new Error("Expected a compiler error");
}

describe("T05 lexical composition", () => {
    test("preserves typed methods, declarations/control flow, and local expression scope", () => {
        const source = 'extends EstragonSurface\nvar count: int = 2\nfunc build(scale: float) -> EstragonRect:\n    if count < 3:\n        return <Rect width={scale * count} fill={Color.RED}/>\n    return <Rect/>\n';
        const result = compileGogo(source);
        expect(result.mode).toBe("hybrid");
        expect(result.code).toStartWith(source.slice(0, source.indexOf("<Rect")));
        expect(result.code).toContain('return _gogo_build_0((scale * count), (Color.RED))');
        expect(result.code).toContain('static func _gogo_build_0(_gogo_value_0: float, _gogo_value_1: Color) -> EstragonRect:');
        expect(result.code).not.toContain(".call()");
        expect(result.code).toContain("    var component_0:");
    });
    test("handles nested markup, dictionaries, arrays, comments and string brace delimiters", () => {
        const source = module('<VBox gap={float({"key": [1, 2], "text": "} <Rect>"}["key"][0])}>{make_child()}<HBox>{<Rect width={value}/>}</HBox></VBox>');
        const result = compileGogo(source);
        expect(result.code).toContain('float({"key": [1, 2], "text": "} <Rect>"}["key"][0])');
        expect(result.code).toContain("(make_child())");
        expect(result.code).toContain("EstragonDisplayObject");
        expect(result.code).toContain("EstragonHBox.new()");
        expect(result.code).toContain("EstragonRect.new()");
    });
    test("preserves ordinary comparisons, shifts, strings and comments verbatim", () => {
        const source = 'extends RefCounted\nconst A = "<Rect/> }"\nconst B = \'<HBox>\'\nconst C = r"\\\"<VBox>"\nconst D = """\n<Rect>{x}</Rect>\n"""\n# <VBox/>\nfunc compare(a, b):\n\treturn a<b and a<=b and a>b and a>=b and a<<1 == b>>1\n';
        expect(compileGogo(source).code).toBe(source + "\n");
        expect(parseHybrid(source).parts.every(part => part.kind === "gdscript-source")).toBe(true);
    });
    test("recognizes return/assignment/call/array/dictionary/conditional expression positions", () => {
        const source = 'extends RefCounted\nfunc build(flag):\n\tvar value := <Rect/>\n\tvar items = [<Rect/>, {"child": <HBox/>}]\n\tconsume(<VBox/>)\n\treturn <Rect/> if flag else <Rect/>\n';
        expect(compileGogo(source).code.match(/static func _gogo_build_/g)?.length).toBe(6);
    });
    test("keeps multiline braced comparisons and explicit GDScript line continuation", () => {
        const source = module('<Rect fill_width={value\n <threshold} width={value \\\n + 1}/>', "    ");
        expect(compileGogo(source).code).toContain('(value\n <threshold)');
        expect(compileGogo(source).code).toContain('(value \\\n + 1)');
        expect(compileGogo('extends RefCounted\nfunc compare(a,b):\n\treturn a \\\n <b\n').code).not.toContain("_gogo_build");
    });
    test("ignores escaped quotes, raw/triple strings and comments when finding expression end", () => {
        const source = module('<Rect width={calculate("\\\"}", r"\\\"}", """}\n<Rect/>""") # } ignored\n}/>', "    ");
        expect(compileGogo(source).code).toContain('calculate("\\\"}", r"\\\"}", """}\n<Rect/>""") # } ignored\n');
    });
    test("handles Unicode identifiers as operands and counts UTF-16/CRLF positions", () => {
        const source = 'extends RefCounted\r\n# 🦎\r\nfunc f(largeur, seuil):\r\n    var same = largeur<seuil\r\n    return <Rect width={largeur}/>\r\n';
        const result = compileGogo(source, "Unicode.gogo");
        expect(result.code).toContain('var same = largeur<seuil\r\n');
        expect(result.code).toContain('(largeur)');
        expect(result.sourceMap.segments.some(segment => segment.original.start.line === 5)).toBe(true);
        expect(compileGogo('extends RefCounted\nfunc f(𐐀, b):\n\treturn 𐐀<b\n').code).not.toContain('_gogo_build');
    });
    test("avoids authored identifier collisions and keeps static factory calls typed", () => {
        const source = 'extends RefCounted\nstatic func _gogo_build_0():\n\treturn 2\nfunc build():\n\tvar _gogo_build_1 = 3\n\treturn <Rect/>\n';
        expect(compileGogo(source).code).toContain('return _gogo_build_2()');
        expect(compileGogo(source).code).toContain('static func _gogo_build_2() -> EstragonRect:');
    });
    test("detects tab or space indentation without reading indentation inside strings", () => {
        const source = 'extends RefCounted\nconst TEXT = """\n    indentation in a string\n"""\nfunc build():\n\treturn <Rect/>\n';
        expect(compileGogo(source).code).toContain('\tvar component_0:');
        expect(compileGogo(module('<Rect/>', '  ')).code).toContain('\n  var component_0:');
    });
    test("rejects invalid tags/properties/children and unsupported markup extensions", () => {
        for (const [body, detail] of [
            ['<Widget/>', 'Unknown component'], ['<Rect gap={1}/>', 'Unsupported property'],
            ['<VBox gap={1} gap={2}/>', 'Duplicate property'], ['<Rect>{child()}</Rect>', 'Rect is a leaf'],
            ['<ns:Rect/>', 'Namespace-prefixed'], ['<VBox xmlns="x"/>', 'Namespaces'],
            ['<Rect width={}/>', 'Expected a GDScript expression'], ['<Rect width={# comment\n}/>', 'Expected a GDScript expression'],
            ['<VBox>text</VBox>', 'Only component children'], ['<VBox>{[1,2}</VBox>', 'Unmatched GDScript delimiter'],
            ['<Rect width={1/>', 'Unterminated GDScript expression'], ['<Rect width={"unfinished}/>', 'Unterminated GDScript string'],
            ['<VBox></HBox>', 'Expected </VBox>'], ['<Rect width="bad"/>', 'finite nonnegative'],
        ]) expect(error(module(body!)).message).toContain(detail!);
    });
    test("rejects unterminated GDScript delimiters/strings with authored locations", () => {
        expect(error('extends RefCounted\nvar x = (1\n').message).toContain('Bad.gogo:2:9:');
        expect(error('extends RefCounted\nvar x = "missing\n').message).toContain('Bad.gogo:2:9:');
        expect(error('extends RefCounted\nvar x = ]\n').message).toContain('Unmatched');
    });
    test("keeps standalone T04 mode and its quoted-only grammar unchanged", () => {
        expect(compileGogo('<Rect width="3"/>').mode).toBe("markup");
        expect(() => compileGogo('<Rect width={3}/>')).toThrow('quoted literal');
        expect(error('extends RefCounted\n<Rect/>').message).toContain('Expected a GDScript expression context');
    });
    test("preserves named-class GDScript but rejects unsupported markup inside it", () => {
        const prefix = 'extends RefCounted\nclass Data:\n    func value() -> int:\n        return 42\n';
        expect(compileGogo(prefix).code).toBe(prefix + "\n");
        expect(error('extends RefCounted\nclass Data:\n    func build():\n        return <Rect/>\n').message).toContain('named inner classes');
        expect(compileGogo(prefix + '\nfunc outer():\n    return <Rect/>\n').code).toContain('return _gogo_build_0()');
    });
    test("does not claim to typecheck/interpret GDScript expressions in TypeScript", () => {
        expect(compileGogo(module('<Rect width={unknown_name +}/>', '    ')).mode).toBe('hybrid');
        expect(compileGogo(module('<Rect width={"wrong type"}/>')).code).toContain('("wrong type")');
        expect(compileGogo(module('<VBox>{null}</VBox>')).code).toContain('push_error(');
    });
    test("is deterministic, including mixed source/map fixtures", async () => {
        const source = await readFile(join(root, 'tests/fixtures/hybrid-edges.gogo'), 'utf8');
        expect(compileGogo(source)).toEqual(compileGogo(source));
        const example = await compileHybridExample(root);
        expect(example.code).toBe(await readFile(join(root, HYBRID_OUTPUT), 'utf8'));
        expect(serializeSourceMap(example.sourceMap)).toBe(await readFile(join(root, HYBRID_OUTPUT + '.map.json'), 'utf8'));
        expect(transpileGogo(source)).toBe(compileGogo(source).code);
    });
});

describe("T05 range source maps", () => {
    test("maps copied code and generated assignments back to authored ranges", () => {
        const source = 'extends RefCounted\nvar member: int = 2\nfunc build():\n    return <Rect width={member + 1}/>\n';
        const result = compileGogo(source, 'View.gogo');
        const generated = new SourceFile(result.code, '<gd>');
        const member = generated.position(result.code.indexOf('member: int'));
        expect(originalPosition(result, member.line, member.column)).toEqual(new SourceFile(source, '').position(source.indexOf('member: int')));
        const assignment = generated.position(result.code.indexOf('component_0.width'));
        expect(originalPosition(result, assignment.line, assignment.column)?.offset).toBe(source.indexOf('{member'));
        const expression = generated.position(result.code.indexOf('member + 1'));
        expect(originalPosition(result, expression.line, expression.column)?.offset).toBe(source.indexOf('member + 1'));
    });
    test("maps multiline UTF-16 copied ranges and bounds imprecise columns", () => {
        const source = 'extends RefCounted\r\n# 🦎\r\nfunc f():\r\n    return <Rect width={3.0}/>\r\n';
        const result = compileGogo(source);
        const generated = new SourceFile(result.code, "");
        const offset = result.code.indexOf('🦎') + 2;
        const point = generated.position(offset);
        expect(originalPosition(result, point.line, point.column)?.offset).toBe(source.indexOf('🦎') + 2);
        const mapped = originalPosition(result, point.line, 10000);
        expect(mapped?.offset).toBeLessThanOrEqual(source.length);
    });
    test("maps Godot line diagnostics while retaining the original engine output", () => {
        const result = compileGogo(module('<Rect width={value}/>'), 'Source.gogo');
        const line = new SourceFile(result.code, '').position(result.code.indexOf('component_0.width')).line;
        const output = `SCRIPT ERROR: failure\n at: helper (res://generated/File.gd:${line})`;
        const traced = traceGodotDiagnostics(output, new Map([['res://generated/File.gd', result]]));
        expect(traced).toStartWith(output);
        expect(traced).toContain('Gogo source: Source.gogo:3:');
        expect(traceGodotDiagnostics('plain output', new Map())).toBe('plain output');
        expect(result.sourceMap.format).toBe('estragon.gogo.source-map');
    });
});

describe("T05 CLI maps", () => {
    test("writes hybrid .gd/map and preserves both artifacts on failed parsing", async () => {
        const folder = await mkdtemp(join(tmpdir(), 'estragon-hybrid-'));
        folders.push(folder);
        const input = join(folder, 'Source.gogo'), output = join(folder, 'Output.gd');
        const run = () => Bun.spawnSync([process.execPath, join(root, 'tools/transpile-gogo.ts'), input, '--output', output]);
        await writeFile(input, module('<Rect width={value}/>'));
        expect(run().exitCode).toBe(0);
        const code = await readFile(output, 'utf8'), map = await readFile(output + '.map.json', 'utf8');
        expect(JSON.parse(map).sourceName).toBe(input);
        await writeFile(input, module('<Rect width={}/>'));
        expect(run().exitCode).toBe(1);
        expect(await readFile(output, 'utf8')).toBe(code);
        expect(await readFile(output + '.map.json', 'utf8')).toBe(map);
        await writeFile(input, '<Rect/>');
        expect(run().exitCode).toBe(0);
        expect(await Bun.file(output + '.map.json').exists()).toBe(false);
    });
});
