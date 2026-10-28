import { describe, expect, test } from "bun:test";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { GogoCompileError } from "../tools/gogo/model.ts";
import { parseHybrid } from "../tools/gogo/hybrid-parser.ts";
import { validateHybrid } from "../tools/gogo/validate.ts";
import { SourceFile } from "../tools/gogo/source.ts";
import { originalPosition, serializeSourceMap } from "../tools/gogo/source-map.ts";
import { compileGogo, transpileGogo } from "../tools/transpile-gogo.ts";
import { compileCounterExample, COUNTER_OUTPUT } from "../tools/check-gdscript.ts";

const root = resolve(import.meta.dir, "..");
const module = (markup: string) => `extends RefCounted\nfunc build():\n    return ${markup}\n`;
function diagnose(source: string): GogoCompileError {
    try { compileGogo(source, "Events.gogo"); }
    catch (error) { expect(error).toBeInstanceOf(GogoCompileError); return error as GogoCompileError; }
    throw new Error("Expected failure");
}

describe("T07 components and literals", () => {
    test("constructs Text/Button with typed string/integer/color/boolean literals", () => {
        const code = transpileGogo('<VBox><Text text="Hello" font_size="24" color="#AABBCC80"/><Button text="+" disabled="true" width="100" fill_height="true"/></VBox>');
        expect(code).toContain('EstragonText.new()');
        expect(code).toContain('EstragonButton.new()');
        expect(code).toContain('component_1.text = "Hello"');
        expect(code).toContain('component_1.font_size = 24\n');
        expect(code).toContain('component_1.color = Color("#aabbcc80")');
        expect(code).toContain('component_2.disabled = true');
        expect(code).toContain('component_2.width = 100.0');
        expect(code).toContain('component_2.fill_height = true');
    });
    test("escapes literal text as data, retaining Unicode, multiline and quote characters", () => {
        const value = '🦎 "quotes"\n\tprint(123)';
        const code = transpileGogo(`<Text text='${value}'/>`);
        expect(code).toContain(`.text = ${JSON.stringify(value)}`);
        expect(code).not.toContain('\n\tprint(123)');
        expect(transpileGogo('<Text text=""/>')).toContain('.text = ""');
    });
    test("canonicalizes positive integer exponent literals without changing float dimensions", () => {
        expect(transpileGogo('<Text font_size="2.4e1" width="24"/>')).toContain('.font_size = 24\n');
        expect(transpileGogo('<Text font_size="24" width="24"/>')).toContain('.width = 24.0');
    });
    const invalid = [
        ['<Text font_size="0"/>', 'positive 32-bit integer'],
        ['<Button font_size="-1"/>', 'positive 32-bit integer'],
        ['<Text font_size="2.5"/>', 'positive 32-bit integer'],
        ['<Text font_size="2147483648"/>', 'positive 32-bit integer'],
        ['<Text font_size="NaN"/>', 'positive 32-bit integer'],
        ['<Text color="red"/>', '#RRGGBB'],
        ['<Button disabled="False"/>', 'true or false'],
        ['<Text disabled="true"/>', 'Unsupported property'],
        ['<Button gap="2"/>', 'Unsupported property'],
        ['<Button fill="#ffffff"/>', 'Unsupported property'],
        ['<Rect text="oops"/>', 'Unsupported property'],
        ['<Text font="resource"/>', 'Unsupported property'],
        ['<Text><Rect/></Text>', 'Text is a leaf'],
        ['<Button><Text/></Button>', 'Button is a leaf'],
        ['<Button pressed="handler"/>', 'GDScript-first'],
    ];
    test.each(invalid)("rejects incompatible literal component contract %s", (source, detail) => {
        expect(diagnose(source!).message).toContain(detail!);
    });
});

describe("T07 typed signals and scope", () => {
    test("keeps property/signal attributes distinct and source ordered in typed IR", () => {
        const source = module('<Button text={label()} pressed={callback()} disabled={flag}/>');
        const ir = validateHybrid(parseHybrid(source, 'Events.gogo'), 'Events.gogo');
        const component = ir.parts.find(part => part.kind === 'component-expression');
        expect(component?.kind).toBe('component-expression');
        if (component?.kind !== 'component-expression') throw new Error('missing component');
        expect(component.attributes.map(p => [p.kind, p.name])).toEqual([['property', 'text'], ['signal', 'pressed'], ['property', 'disabled']]);
    });
    test("passes scoped method/local expressions as typed Callables to static factories", () => {
        const source = 'extends RefCounted\nfunc build(callback: Callable):\n    var local: Callable = callback\n    return <Button pressed={local} text={title} font_size={size} color={tint} disabled={flag}/>\n';
        const code = compileGogo(source).code;
        expect(code).toContain('(local)');
        expect(code).toContain('_gogo_value_0: Callable');
        expect(code).toContain('_gogo_value_1: String');
        expect(code).toContain('_gogo_value_2: int');
        expect(code).toContain('_gogo_value_3: Color');
        expect(code).toContain('_gogo_value_4: bool');
        expect(code).toContain('component_0.pressed.connect(_gogo_value_0)');
        expect(code).toContain('not _gogo_value_0.is_valid()');
        expect(code).toContain('_gogo_value_0.get_argument_count() != 0');
        expect(code).toContain('is_disposed()');
        expect(code).not.toContain('connect("');
        expect(code).not.toMatch(/eval\(|new Function|JSON\.parse/);
    });
    test("evaluates interleaved callback/property arguments once, before nested children", () => {
        const source = module('<VBox gap={spacing()}><Button pressed={make_callback()} text={make_label()}/>{child()}</VBox>');
        const code = compileGogo(source).code;
        expect(code.match(/make_callback\(\)/g)?.length).toBe(1);
        expect(code.indexOf('(spacing())')).toBeLessThan(code.indexOf('(make_callback())'));
        expect(code.indexOf('(make_callback())')).toBeLessThan(code.indexOf('(make_label())'));
        expect(code.indexOf('(make_label())')).toBeLessThan(code.indexOf('(child())'));
        expect(code.match(/\.pressed.connect\(/g)?.length).toBe(1);
    });
    test("accepts native zero-argument lambdas, bound callables and conditional references lexically", () => {
        const source = module('<VBox><Button pressed={func() -> void: action("<&}")}/><Button pressed={handler.bind(1) if enabled else fallback}/></VBox>');
        const code = compileGogo(source).code;
        expect(code).toContain('func() -> void: action("<&}")');
        expect(code).toContain('handler.bind(1) if enabled else fallback');
        expect(code.match(/\.pressed.connect\(/g)?.length).toBe(2);
    });
    const invalid = [
        ['<Text pressed={handler}/>', 'Unsupported property'],
        ['<VBox pressed={handler}/>', 'Unsupported property'],
        ['<Button clicked={handler}/>', 'Unsupported property'],
        ['<Button released={handler}/>', 'Unsupported property'],
        ['<Button pressed="handler"/>', 'not a quoted method'],
        ['<Button pressed={one} pressed={two}/>', 'Duplicate property or signal pressed'],
        ['<Button text="a" text="b"/>', 'Duplicate property'],
        ['<Button pressed={}/>', 'Expected a GDScript expression inside braces'],
        ['<Button><Rect/></Button>', 'Button is a leaf'],
        ['<Text>{child}</Text>', 'Text is a leaf'],
        ['<fx:Button pressed={handler}/>', 'Namespace-prefixed'],
    ];
    test.each(invalid)("rejects invalid hybrid attributes/nesting %s", (source, detail) => {
        const error = diagnose(module(source!));
        expect(error.message).toContain(detail!);
        expect(error.span.start.line).toBe(3);
    });
    test("leaves GDScript semantic checking to Godot rather than accepting it as proven", () => {
        expect(compileGogo(module('<Button pressed={missing_handler}/>')).code).toContain('(missing_handler)');
        expect(compileGogo(module('<Button pressed={42}/>')).code).toContain('(42)');
    });
});

describe("T07 maps and example", () => {
    test("maps copied callback references and generated connect/guards to authored event spans", () => {
        const source = 'extends RefCounted\r\n# 🦎\r\nfunc build():\r\n    return <Button pressed={on_click}/>\r\n';
        const result = compileGogo(source, 'Events.gogo');
        const file = new SourceFile(result.code, '');
        for (const needle of ['on_click)', '.pressed.connect(', 'if not _gogo_value_0']) {
            const pos = file.position(result.code.indexOf(needle));
            const offset = originalPosition(result, pos.line, pos.column)?.offset;
            expect(offset).toBe(needle === 'on_click)' ? source.indexOf('on_click') : source.indexOf('{on_click'));
        }
    });
    test("avoids generated name collisions and emits deterministic code/maps", () => {
        const source = 'extends RefCounted\nfunc _gogo_build_0(): pass\nfunc build():\n    return <Button pressed={_gogo_build_0}/>\n';
        const result = compileGogo(source);
        expect(result.code).toContain('static func _gogo_build_1(');
        expect(result.code).toContain('(_gogo_build_0)');
        expect(result).toEqual(compileGogo(source));
    });
    test("matches Counter fixture and contains no handwritten signal connections/disposal", async () => {
        const result = await compileCounterExample(root);
        expect(result.code).toBe(await readFile(resolve(root, COUNTER_OUTPUT), 'utf8'));
        expect(serializeSourceMap(result.sourceMap)).toBe(await readFile(resolve(root, COUNTER_OUTPUT + '.map.json'), 'utf8'));
        const source = await readFile(resolve(root, 'examples/counter/Counter.gogo'), 'utf8');
        expect(source).not.toMatch(/\.connect\(|dispose\(/);
        expect(result.code.match(/\.pressed.connect\(/g)?.length).toBe(2);
    });
});
