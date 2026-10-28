import type { GdscriptExpression, HybridComponentExpression, HybridModule, HybridPart, Span } from "./model.ts";
import { COMPONENT_CLASSES, PROPERTY_TYPES } from "./validate.ts";
import { emitLiteral } from "./emit-gdscript.ts";
import { MappedWriter } from "./source-map.ts";
import { SourceFile } from "./source.ts";

type Argument = { expression: GdscriptExpression; type: string; name: string };
type Factory = { name: string; root: HybridComponentExpression; arguments: Argument[] };

export function emitHybrid(module: HybridModule, file: SourceFile) {
    const writer = new MappedWriter(file);
    const factories: Factory[] = [];
    let sequence = 0;
    const argumentByExpression = new Map<GdscriptExpression, Argument>();
    const collect = (node: HybridComponentExpression, factory: Factory) => {
        const argument = (expression: GdscriptExpression, type: string) => {
            const item = { expression, type, name: `_gogo_value_${factory.arguments.length}` };
            factory.arguments.push(item);
            argumentByExpression.set(expression, item);
        };
        for (const attribute of node.attributes) if (attribute.value.kind === "gdscript-expression") argument(attribute.value, attribute.kind === "signal" ? "Callable" : PROPERTY_TYPES[attribute.name]);
        for (const child of node.children) {
            if (child.kind === "gdscript-expression") argument(child, "EstragonDisplayObject");
            else collect(child, factory);
        }
    };
    const parts = (items: readonly HybridPart[]) => {
        for (const item of items) {
            if (item.kind === "gdscript-source") writer.append(file.text.slice(item.span.start.offset, item.span.end.offset), item.span, true);
            else call(item);
        }
    };
    const call = (node: HybridComponentExpression) => {
        let name: string;
        do { name = `_gogo_build_${sequence++}`; } while (module.identifiers.has(name));
        const factory: Factory = { name, root: node, arguments: [] };
        factories.push(factory);
        collect(node, factory);
        const multiline = factory.arguments.length > 3;
        const lineStart = file.offset(node.span.start.line);
        let indentationEnd = lineStart;
        while (file.text[indentationEnd] === " " || file.text[indentationEnd] === "\t") indentationEnd++;
        const baseIndent = file.text.slice(lineStart, indentationEnd);
        writer.append(`${name}(`, node.span);
        factory.arguments.forEach((argument, index) => {
            if (index) writer.append(multiline ? "," : ", ", node.span);
            if (multiline) writer.append(`\n${baseIndent}${module.indentation}`, node.span);
            writer.append("(", argument.expression.span);
            parts(argument.expression.parts);
            writer.append(")", argument.expression.span);
        });
        writer.append(`${multiline ? "\n" + baseIndent : ""})`, node.span);
    };
    parts(module.parts);
    writer.append("\n");
    // Nested markup inside arguments can add factories while calls are emitted.
    for (const factory of factories) {
        writer.append(`\n\nstatic func ${factory.name}(`, factory.root.span);
        const multiline = factory.arguments.length > 3;
        factory.arguments.forEach((argument, index) => {
            if (index) writer.append(multiline ? "," : ", ", argument.expression.span);
            writer.append(`${multiline ? "\n" + module.indentation : ""}${argument.name}: ${argument.type}`, argument.expression.span);
        });
        writer.append(`${multiline ? "\n" : ""}) -> ${COMPONENT_CLASSES[factory.root.component]}:\n`, factory.root.span);
        let next = 0;
        const line = (text: string, span: Span) => writer.append(`${module.indentation}${text}\n`, span);
        const emit = (node: HybridComponentExpression): string => {
            const variable = `component_${next++}`, type = COMPONENT_CLASSES[node.component];
            line(`var ${variable}: ${type} = ${type}.new()`, node.span);
            for (const attribute of node.attributes) {
                const value = attribute.value;
                const argument = value.kind === "gdscript-expression" ? argumentByExpression.get(value)!.name : emitLiteral(value);
                if (attribute.kind === "property") line(`${variable}.${attribute.name} = ${argument}`, value.span);
                else {
                    const error = JSON.stringify(`${file.name}:${value.span.start.line}:${value.span.start.column}: Button.pressed requires a valid zero-argument Callable with a live target`);
                    line(`if not ${argument}.is_valid() or ${argument}.get_argument_count() != 0:`, value.span);
                    line(`${module.indentation}push_error(${error})`, value.span);
                    line(`elif ${argument}.get_object() is EstragonDisplayObject and (${argument}.get_object() as EstragonDisplayObject).is_disposed():`, value.span);
                    line(`${module.indentation}push_error(${error})`, value.span);
                    line(`elif ${variable}.pressed.connect(${argument}) != OK:`, value.span);
                    line(`${module.indentation}push_error(${error})`, value.span);
                }
            }
            for (const child of node.children) {
                const value = child.kind === "gdscript-expression" ? argumentByExpression.get(child)!.name : emit(child);
                line(`if ${variable}.add_child(${value}) != OK:`, child.span);
                line(`${module.indentation}push_error(${JSON.stringify(`${file.name}:${child.span.start.line}:${child.span.start.column}: Gogo child must be a live, uniquely owned component`)})`, child.span);
            }
            return variable;
        };
        const root = emit(factory.root);
        line(`return ${root}`, factory.root.span);
    }
    return writer.finish();
}
