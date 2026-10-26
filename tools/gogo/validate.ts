import { GogoCompileError, type AttributeSyntax, type ComponentExpression, type ComponentName, type ComponentSyntax, type Literal, type PropertyName } from "./model.ts";

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

export function validateComponent(node: ComponentSyntax, sourceName = "<source>"): ComponentExpression {
    if (node.name.includes(":")) throw new GogoCompileError(sourceName, node.nameSpan, "Namespace-prefixed components are not supported");
    if (!Object.hasOwn(COMPONENT_CLASSES, node.name)) {
        throw new GogoCompileError(sourceName, node.nameSpan, `Unknown component ${JSON.stringify(node.name)}; expected VBox, HBox or Rect`);
    }
    const component = node.name as ComponentName;
    const seen = new Set<string>();
    const properties: ComponentExpression["properties"][number][] = [];
    for (const attribute of node.attributes) {
        if (attribute.name === "xmlns" || attribute.name.includes(":")) {
            throw new GogoCompileError(sourceName, attribute.nameSpan, "Namespaces and prefixed properties are not supported");
        }
        if (seen.has(attribute.name)) throw new GogoCompileError(sourceName, attribute.nameSpan, `Duplicate property ${attribute.name}`);
        seen.add(attribute.name);
        if (!COMMON.has(attribute.name) && attribute.name !== (component === "Rect" ? "fill" : "gap")) {
            throw new GogoCompileError(sourceName, attribute.nameSpan, `Unsupported property ${JSON.stringify(attribute.name)} on ${component}`);
        }
        properties.push({ name: attribute.name as PropertyName, value: literal(attribute, sourceName) });
    }
    if (component === "Rect" && node.children.length > 0) {
        throw new GogoCompileError(sourceName, node.children[0]!.nameSpan, "Rect is a leaf and cannot contain components");
    }
    return { kind: "component-expression", component, properties, children: node.children.map(child => validateComponent(child, sourceName)), span: node.span };
}
