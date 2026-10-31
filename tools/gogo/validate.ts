import { normalizeNumber } from "./numeric-literal.ts";
import { GogoCompileError, type AttributeSyntax, type ComponentExpression, type ComponentName, type ComponentSyntax, type Literal, type PropertyName, type HybridComponentSyntax, type HybridComponentExpression, type GdscriptExpressionSyntax, type GdscriptExpression, type HybridModuleSyntax, type HybridModule, type Span, type HybridAttribute } from "./model.ts";

/** Explicit built-ins, not an extensible import/reflection system. */
export const COMPONENT_CLASSES: Readonly<Record<ComponentName, string>> = {
    VBox: "EstragonVBox", HBox: "EstragonHBox", Rect: "EstragonRect",
    Text: "EstragonText", Button: "EstragonButton",
};
export const PROPERTY_TYPES: Readonly<Record<PropertyName, string>> = {
    width: "float", height: "float", gap: "float", fill_width: "bool", fill_height: "bool",
    fill: "Color", text: "String", font_size: "int", color: "Color", disabled: "bool",
};
const COMMON = new Set(["width", "height", "fill_width", "fill_height"]);
const NUMBER = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/;
const COLOR = /^#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$/;

function literal(attribute: AttributeSyntax, sourceName: string): Literal {
    const { name, value, valueSpan: span } = attribute;
    const fail = (detail: string): never => { throw new GogoCompileError(sourceName, span, detail); };
    if (name === "text") return { kind: "string-literal", value, span };
    if (name === "font_size") {
        const number = Number(value);
        if (NUMBER.exec(value)?.[0] !== value || !Number.isInteger(number) || number <= 0 || number > 2147483647) fail("font_size requires a positive 32-bit integer");
        return { kind: "integer-literal", value: number, span };
    }
    if (name === "fill_width" || name === "fill_height" || name === "disabled") {
        if (value !== "true" && value !== "false") fail(`${name} requires true or false`);
        return { kind: "boolean-literal", value: value === "true", span };
    }
    if (name === "fill" || name === "color") {
        if (COLOR.exec(value)?.[0] !== value) fail(`${name} requires #RRGGBB or #RRGGBBAA`);
        return { kind: "color-literal", value: value.toLowerCase() + (value.length === 7 ? "ff" : ""), span };
    }
    if ((name === "width" || name === "height") && value === "auto") {
        return { kind: "number-literal", value: -1, numberToken: "-1.0", span };
    }
    if (NUMBER.exec(value)?.[0] !== value) fail(`${name} requires a finite nonnegative number${name === "gap" ? "" : " or auto"}`);
    const number = Number(value);
    if (!Number.isFinite(number) || !Number.isFinite(Math.fround(number)) || number < 0) {
        fail(`${name} must be nonnegative and finite in runtime geometry${name === "gap" ? "" : "; use auto for intrinsic sizing"}`);
    }
    return { kind: "number-literal", value: number === 0 ? 0 : number, numberToken: number === 0 ? "0.0" : normalizeNumber(value), span };
}

function componentName(name: string, nameSpan: Span, sourceName: string): ComponentName {
    if (name.includes(":")) throw new GogoCompileError(sourceName, nameSpan, "Namespace-prefixed components are not supported");
    if (!Object.hasOwn(COMPONENT_CLASSES, name)) {
        throw new GogoCompileError(sourceName, nameSpan, `Unknown component ${JSON.stringify(name)}; expected VBox, HBox, Rect, Text or Button`);
    }
    return name as ComponentName;
}

function checkAttribute(name: string, span: Span, seen: Set<string>, sourceName: string): void {
    if (name === "xmlns" || name.includes(":")) throw new GogoCompileError(sourceName, span, "Namespaces and prefixed properties are not supported");
    if (seen.has(name)) throw new GogoCompileError(sourceName, span, `Duplicate property or signal ${name}`);
    seen.add(name);
}

function propertyName(component: ComponentName, name: string, span: Span, sourceName: string): PropertyName {
    const text = component === "Text" || component === "Button";
    if (!COMMON.has(name) && !((component === "VBox" || component === "HBox") && name === "gap")
        && !(component === "Rect" && name === "fill")
        && !(text && ["text", "font_size", "color"].includes(name))
        && !(component === "Button" && name === "disabled")) {
        throw new GogoCompileError(sourceName, span, `Unsupported property or signal ${JSON.stringify(name)} on ${component}`);
    }
    return name as PropertyName;
}

function isLeaf(component: ComponentName): boolean { return component !== "VBox" && component !== "HBox"; }

export function validateComponent(node: ComponentSyntax, sourceName = "<source>"): ComponentExpression {
    const component = componentName(node.name, node.nameSpan, sourceName);
    const seen = new Set<string>();
    const properties = node.attributes.map(attribute => {
        checkAttribute(attribute.name, attribute.nameSpan, seen, sourceName);
        if (component === "Button" && attribute.name === "pressed") {
            throw new GogoCompileError(sourceName, attribute.valueSpan, "pressed requires a {Callable expression} in a GDScript-first module");
        }
        return { name: propertyName(component, attribute.name, attribute.nameSpan, sourceName), value: literal(attribute, sourceName) };
    });
    if (isLeaf(component) && node.children.length > 0) {
        throw new GogoCompileError(sourceName, node.children[0]!.nameSpan, `${component} is a leaf and cannot contain components`);
    }
    return { kind: "component-expression", component, properties, children: node.children.map(child => validateComponent(child, sourceName)), span: node.span };
}

function validateExpression(node: GdscriptExpressionSyntax, sourceName: string): GdscriptExpression {
    return { ...node, parts: node.parts.map(part => part.kind === "gdscript-source" ? part : validateHybridComponent(part, sourceName)) };
}

export function validateHybridComponent(node: HybridComponentSyntax, sourceName: string): HybridComponentExpression {
    const component = componentName(node.name, node.nameSpan, sourceName);
    const seen = new Set<string>();
    const attributes: HybridAttribute[] = node.attributes.map(attribute => {
        checkAttribute(attribute.name, attribute.nameSpan, seen, sourceName);
        if (component === "Button" && attribute.name === "pressed") {
            if (typeof attribute.value === "string") throw new GogoCompileError(sourceName, attribute.valueSpan, "pressed requires a {Callable expression}, not a quoted method name");
            return { kind: "signal", name: "pressed", value: validateExpression(attribute.value, sourceName) };
        }
        const name = propertyName(component, attribute.name, attribute.nameSpan, sourceName);
        const value = typeof attribute.value === "string"
            ? literal({ ...attribute, value: attribute.value }, sourceName)
            : validateExpression(attribute.value, sourceName);
        return { kind: "property", name, value };
    });
    if (isLeaf(component) && node.children.length) {
        const child = node.children[0]!;
        throw new GogoCompileError(sourceName, child.kind === "component-expression" ? child.nameSpan : child.span, `${component} is a leaf and cannot contain components`);
    }
    return { kind: "component-expression", component, attributes, span: node.span,
        children: node.children.map(child => child.kind === "component-expression" ? validateHybridComponent(child, sourceName) : validateExpression(child, sourceName)) };
}

export function validateHybrid(module: HybridModuleSyntax, sourceName: string): HybridModule {
    return { ...module, parts: module.parts.map(part => part.kind === "gdscript-source" ? part : validateHybridComponent(part, sourceName)) };
}
