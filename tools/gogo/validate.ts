import { GogoCompileError, type AttributeSyntax, type ComponentExpression, type ComponentName, type ComponentSyntax, type Literal, type PropertyName, type HybridComponentSyntax, type HybridComponentExpression, type GdscriptExpressionSyntax, type GdscriptExpression, type HybridModuleSyntax, type HybridModule, type Span } from "./model.ts";

/** Explicit T04 target registry, not an extensible import/reflection system. */
export const COMPONENT_CLASSES: Readonly<Record<ComponentName, string>> = {
    VBox: "EstragonVBox", HBox: "EstragonHBox", Rect: "EstragonRect",
};
const COMMON = new Set(["width", "height", "fill_width", "fill_height"]);
const NUMBER = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/;
const COLOR = /^#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$/;

function literal(attribute: AttributeSyntax, sourceName: string): Literal {
    const { name, value, valueSpan: span } = attribute;
    const fail = (detail: string): never => { throw new GogoCompileError(sourceName, span, detail); };
    if (name === "fill_width" || name === "fill_height") {
        if (value !== "true" && value !== "false") fail(`${name} requires true or false`);
        return { kind: "boolean-literal", value: value === "true", span };
    }
    if (name === "fill") {
        if (COLOR.exec(value)?.[0] !== value) fail("fill requires #RRGGBB or #RRGGBBAA");
        return { kind: "color-literal", value: value.toLowerCase() + (value.length === 7 ? "ff" : ""), span };
    }
    if ((name === "width" || name === "height") && value === "auto") {
        return { kind: "number-literal", value: -1, span };
    }
    if (NUMBER.exec(value)?.[0] !== value) fail(`${name} requires a finite nonnegative number${name === "gap" ? "" : " or auto"}`);
    const number = Number(value);
    if (!Number.isFinite(number) || !Number.isFinite(Math.fround(number)) || number < 0) {
        fail(`${name} must be nonnegative and finite in runtime geometry${name === "gap" ? "" : "; use auto for intrinsic sizing"}`);
    }
    return { kind: "number-literal", value: number === 0 ? 0 : number, span };
}

function componentName(name: string, nameSpan: Span, sourceName: string): ComponentName {
    if (name.includes(":")) throw new GogoCompileError(sourceName, nameSpan, "Namespace-prefixed components are not supported");
    if (!Object.hasOwn(COMPONENT_CLASSES, name)) {
        throw new GogoCompileError(sourceName, nameSpan, `Unknown component ${JSON.stringify(name)}; expected VBox, HBox or Rect`);
    }
    return name as ComponentName;
}

function propertyName(component: ComponentName, name: string, span: Span, seen: Set<string>, sourceName: string): PropertyName {
    if (name === "xmlns" || name.includes(":")) throw new GogoCompileError(sourceName, span, "Namespaces and prefixed properties are not supported");
    if (seen.has(name)) throw new GogoCompileError(sourceName, span, `Duplicate property ${name}`);
    seen.add(name);
    if (!COMMON.has(name) && name !== (component === "Rect" ? "fill" : "gap")) {
        throw new GogoCompileError(sourceName, span, `Unsupported property ${JSON.stringify(name)} on ${component}`);
    }
    return name as PropertyName;
}

export function validateComponent(node: ComponentSyntax, sourceName = "<source>"): ComponentExpression {
    const component = componentName(node.name, node.nameSpan, sourceName);
    const seen = new Set<string>();
    const properties = node.attributes.map(attribute => ({
        name: propertyName(component, attribute.name, attribute.nameSpan, seen, sourceName),
        value: literal(attribute, sourceName),
    }));
    if (component === "Rect" && node.children.length > 0) {
        throw new GogoCompileError(sourceName, node.children[0]!.nameSpan, "Rect is a leaf and cannot contain components");
    }
    return { kind: "component-expression", component, properties, children: node.children.map(child => validateComponent(child, sourceName)), span: node.span };
}

function validateExpression(node: GdscriptExpressionSyntax, sourceName: string): GdscriptExpression {
    return { ...node, parts: node.parts.map(part => part.kind === "gdscript-source" ? part : validateHybridComponent(part, sourceName)) };
}

export function validateHybridComponent(node: HybridComponentSyntax, sourceName: string): HybridComponentExpression {
    const component = componentName(node.name, node.nameSpan, sourceName);
    const seen = new Set<string>();
    const properties = node.attributes.map(attribute => {
        const name = propertyName(component, attribute.name, attribute.nameSpan, seen, sourceName);
        const value = typeof attribute.value === "string"
            ? literal({ ...attribute, value: attribute.value }, sourceName)
            : validateExpression(attribute.value, sourceName);
        return { name, value };
    });
    if (component === "Rect" && node.children.length) {
        const child = node.children[0]!;
        throw new GogoCompileError(sourceName, child.kind === "component-expression" ? child.nameSpan : child.span, "Rect is a leaf and cannot contain components");
    }
    return { kind: "component-expression", component, properties, span: node.span,
        children: node.children.map(child => child.kind === "component-expression" ? validateHybridComponent(child, sourceName) : validateExpression(child, sourceName)) };
}

export function validateHybrid(module: HybridModuleSyntax, sourceName: string): HybridModule {
    return { ...module, parts: module.parts.map(part => part.kind === "gdscript-source" ? part : validateHybridComponent(part, sourceName)) };
}
