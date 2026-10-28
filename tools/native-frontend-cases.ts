/** Optional reference transcripts only; native tests read committed data, never Bun. */
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { parseMarkup } from "./gogo/parser.ts";
import { parseHybrid } from "./gogo/hybrid-parser.ts";
import { validateComponent, validateHybrid } from "./gogo/validate.ts";
import { GogoCompileError, type ComponentExpression, type HybridPart, type GdscriptExpression, type Literal, type Span } from "./gogo/model.ts";

const root = resolve(import.meta.dir, "..");
const output = resolve(root, "tests/fixtures/native-frontend.json");
const hybrid = (markup: string) => `extends RefCounted\nfunc build():\n    return ${markup}\n`;
const sources: [string, string][] = [
    ["empty-stack", '<HBox gap="0"/>'],
    ["literals", '<VBox width="auto" gap=".5"><Rect width="1e2" fill="#AABBCC80"/><Text text=\'🦎 "Hello"\nworld\' font_size="2.4e1"/><Button disabled="true"/></VBox>'],
    ["code-only", 'extends RefCounted\nfunc compare(𐐀, b):\n\treturn 𐐀<b and b <= 9 or b>>1\n'],
    ["contexts", 'extends RefCounted\nfunc build(flag):\n\tvar value := <Rect/>\n\tvar items = [<Rect/>, {"child": <HBox/>}]\n\tconsume(<VBox/>)\n\treturn <Rect/> if flag else <Rect/>\n'],
    ["boundaries", hybrid('<Rect width={calculate("\\\"}", r"\\\"}", """}\n<Rect/>""") # } ignored\n}/>')],
    ["continuation", hybrid('<Rect fill_width={value\n <threshold} width={value \\\n + 1}/>')],
    ["nested-expression", hybrid('<VBox>{<HBox>{make_child()}</HBox> if condition else <Rect/>}</VBox>')],
    ["unicode-crlf", 'extends RefCounted\r\n# 🦎\r\nfunc f(café, 阈值):\r\n    var é = café<阈值\r\n    return <Button text={"🦎"} pressed={callback}/>\r\n'],
    ["member-initializer", 'extends RefCounted\nvar view = (\n    <Text text="Hi"/>\n)\n'],
    ["inner-class-code", 'extends RefCounted\nclass Data:\n    func value():\n        return 42\nfunc outer():\n    return <Rect/>\n'],
    ["semantics-deferred", hybrid('<Rect width={unknown_name +}/>')],
    ["unknown-handler-deferred", hybrid('<Button pressed={missing_handler}/>')],
    ["child-type-deferred", hybrid('<VBox>{null}</VBox>')],
    ["string-indent", 'extends RefCounted\nconst TEXT = """\n    ignored indentation\n"""\nfunc build():\n\treturn <Rect/>\n'],
    ["nested-256", '<VBox>'.repeat(255) + '<Rect/>' + '</VBox>'.repeat(255)],
];
// Retain the original T04 and T07 rejection tables as measured reference inputs.
for (const file of ["tests/transpile-gogo.test.ts", "tests/signal-gogo.test.ts"]) {
    const content = await readFile(resolve(root, file), "utf8");
    // These test tables contain static JavaScript string literals, not GDScript
    // rewriting. Extract once with the TypeScript scanner rather than eval.
    const ts = await import("typescript");
    const syntax = ts.createSourceFile(file, content, ts.ScriptTarget.Latest, true);
    const visit = (node: import("typescript").Node) => {
        if (ts.isArrayLiteralExpression(node) && node.elements.length === 2 && node.elements.every(ts.isStringLiteral)) {
            const source = (node.elements[0] as import("typescript").StringLiteral).text;
            if (source.startsWith("<") || source === "" || source.startsWith("<!--") || source.startsWith("<?") || source.startsWith("<!DOCTYPE") || source.startsWith("extends VBox")) {
                const mixed = source.includes("={") || file.includes("signal-gogo") && source.includes('pressed="handler"');
                sources.push([`${file}:${node.pos}`, mixed && file.includes("signal-gogo") ? hybrid(source) : source]);
            }
        }
        ts.forEachChild(node, visit);
    };
    visit(syntax);
}
for (const [id, source] of [
    ["empty", ""], ["no-close", '<VBox>'], ["deep", '<VBox>'.repeat(257)],
    ["wrong-close", hybrid('<VBox></HBox>')], ["bad-child", hybrid('<VBox>{[1,2}</VBox>')],
    ["open-expression", hybrid('<Rect width={1/>')], ["open-string", hybrid('<Rect width={"unfinished}/>')],
    ["empty-comment-expression", hybrid('<Rect width={# comment\n}/>')],
    ["bare-markup", 'extends RefCounted\n<Rect/>'],
    ["class-markup", 'extends RefCounted\nclass Data:\n    func build():\n        return <Rect/>\n'],
    ["unclosed-paren", 'extends RefCounted\nvar x = (1\n'],
    ["unmatched", 'extends RefCounted\nvar x = ]\n'],
    ["bad-string", 'extends RefCounted\nvar x = "missing\n'],
    ["bom", '\ufeff<Rect/>'], ["unicode-trim", '\u00a0'],
] as [string,string][]) sources.push([id, source]);
for (const path of ["examples/compiled/Layout.gogo", "examples/mixed/Mixed.gogo", "examples/counter/Counter.gogo", "tests/fixtures/hybrid-edges.gogo", "tests/fixtures/signal-edges.gogo"]) sources.push([path, await readFile(resolve(root, path), "utf8")]);
const span = (value: Span) => ({ start: value.start, end: value.end });
type Normalized = {
    kind: string;
    span: Span;
    name?: string;
    attributes?: {kind: string; name: string; value: Normalized}[];
    children?: Normalized[];
    parts?: Normalized[];
    value?: string | number | boolean;
};
function normalize(node: HybridPart | ComponentExpression | GdscriptExpression | Literal): Normalized {
    if (node.kind === "component-expression") {
        const attributes = "attributes" in node ? node.attributes
            : node.properties.map(property => ({...property, kind: "property"}));
        return {
            kind: node.kind, name: node.component, span: span(node.span),
            attributes: attributes.map(attribute => ({
                kind: attribute.kind, name: attribute.name, value: normalize(attribute.value),
            })),
            children: node.children.map(normalize),
        };
    }
    if (node.kind === "gdscript-source") return {kind: node.kind, span: span(node.span)};
    if (node.kind === "gdscript-expression") {
        return {kind: node.kind, span: span(node.span), parts: node.parts.map(normalize)};
    }
    return {kind: node.kind, span: span(node.span), value: node.value};
}
const cases = sources.map(([id, source]) => {
    try {
        if (id === "nested-256") { validateComponent(parseMarkup(source, id), id); return {id,source,ok:true}; }
        if (source.trimStart().startsWith("<") || source.trim() === "") return {id, source, ok:true, tree:{mode:"markup", parts:[normalize(validateComponent(parseMarkup(source, id), id))],identifiers:[],indentation:"\t"}};
        const module = validateHybrid(parseHybrid(source, id), id);
        return {id,source,ok:true,tree:{mode:"hybrid",parts:module.parts.map(normalize),identifiers:[...module.identifiers],indentation:module.indentation}};
    } catch (error) {
        if (!(error instanceof GogoCompileError)) throw error;
        return {id,source,ok:false,position:error.span.start};
    }
});
const serialized = JSON.stringify(cases, null, 2) + "\n";
if (process.argv.includes("--write")) await writeFile(output, serialized);
else if (serialized !== await readFile(output,"utf8")) throw new Error("Native frontend corpus stale: bun tools/native-frontend-cases.ts --write");
console.log(`Native frontend reference cases: ${cases.length}`);
