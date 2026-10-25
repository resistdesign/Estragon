/**
 * Stage-0 Gogo compiler: strict namespace-aware markup -> Estragon-owned JSON IR.
 * This is build tooling, not part of the Godot runtime.
 */
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { SaxesParser } from "saxes";

export const GOGO_NAMESPACE = "urn:estragon:gogo:1";
export const IR_FORMAT = "estragon.gogo.ir";
export const IR_VERSION = 1;

const XMLNS_NAMESPACE = "http://www.w3.org/2000/xmlns/";
const COLOR_RE = /^#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$/;
const NUMBER_RE = /^[+-]?(?:(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|inf(?:inity)?|nan)$/i;

export class GogoError extends Error {
    constructor(message: string) {
        super(message);
        this.name = "GogoError";
    }
}

interface SourceElement {
    name: string;
    namespace: string;
    attributes: Record<string, string>;
    children: SourceElement[];
}

export interface IrRect {
    type: "Rect";
    id?: string;
    props: {
        x: number;
        y: number;
        width: number;
        height: number;
        fill: string;
    };
}

export interface IrView {
    type: "View";
    id?: string;
    props: {
        width: number;
        height: number;
    };
    children: IrRect[];
}

export interface GogoIr {
    format: typeof IR_FORMAT;
    version: typeof IR_VERSION;
    root: IrView;
}

/** Parse real XML, retaining resolved namespace URIs and original attributes. */
function parseXml(source: string): SourceElement {
    const parser = new SaxesParser({ xmlns: true });
    const stack: SourceElement[] = [];
    let root: SourceElement | undefined;

    parser.on("opentag", (tag) => {
        const attributes: Record<string, string> = Object.create(null) as Record<string, string>;
        for (const attribute of Object.values(tag.attributes)) {
            // Namespace declarations are XML syntax, not Gogo component properties.
            if (attribute.uri !== XMLNS_NAMESPACE) {
                attributes[attribute.name] = attribute.value;
            }
        }
        const element: SourceElement = {
            name: tag.local,
            namespace: tag.uri,
            attributes,
            children: [],
        };

        const parent = stack[stack.length - 1];
        if (parent !== undefined) {
            parent.children.push(element);
        } else if (root === undefined) {
            root = element;
        } else {
            throw new GogoError("Malformed Gogo XML: multiple document roots");
        }
        stack.push(element);
    });

    parser.on("closetag", () => {
        stack.pop();
    });

    const rejectText = (value: string): void => {
        if (value.trim() === "") {
            return;
        }
        const current = stack[stack.length - 1];
        if (current === undefined) {
            throw new GogoError("Malformed Gogo XML: text outside the document root");
        }
        throw new GogoError("<" + current.name + "> does not support text content");
    };
    parser.on("text", rejectText);
    parser.on("cdata", rejectText);
    parser.on("doctype", () => {
        throw new GogoError("Malformed Gogo XML: DOCTYPE is not supported");
    });
    parser.on("error", (error) => {
        throw error;
    });

    try {
        parser.write(source).close();
    } catch (error) {
        if (error instanceof GogoError) {
            throw error;
        }
        const message = error instanceof Error ? error.message : String(error);
        throw new GogoError("Malformed Gogo XML: " + message);
    }

    if (root === undefined) {
        throw new GogoError("Malformed Gogo XML: missing document root");
    }
    return root;
}

function componentName(element: SourceElement): string {
    if (element.namespace !== GOGO_NAMESPACE) {
        throw new GogoError(
            "Every component must be in the Gogo namespace (" +
            GOGO_NAMESPACE + "); found <" + element.name + ">"
        );
    }
    return element.name;
}

function validateAttributes(element: SourceElement, allowed: ReadonlySet<string>): void {
    const unexpected = Object.keys(element.attributes).filter((key) => !allowed.has(key));
    if (unexpected.length > 0) {
        throw new GogoError(
            "<" + componentName(element) + "> has unsupported attributes: " +
            unexpected.sort().join(", ")
        );
    }
}

function required(element: SourceElement, name: string): string {
    const value = element.attributes[name];
    if (value === undefined) {
        throw new GogoError("<" + componentName(element) + "> requires '" + name + "'");
    }
    return value;
}

function numberProperty(
    element: SourceElement,
    name: string,
    options: { defaultValue?: number; strictlyPositive?: boolean } = {},
): number {
    const raw = element.attributes[name];
    if (raw === undefined && options.defaultValue === undefined) {
        throw new GogoError("<" + componentName(element) + "> requires '" + name + "'");
    }
    const value = raw === undefined ? options.defaultValue! : raw.trim();
    if (typeof value === "string" && !NUMBER_RE.test(value)) {
        throw new GogoError(
            "<" + componentName(element) + "> '" + name +
            "' must be a number, got " + JSON.stringify(raw)
        );
    }
    const parsed = typeof value === "number" ? value : Number(value);
    if (!Number.isFinite(parsed)) {
        throw new GogoError("<" + componentName(element) + "> '" + name + "' must be finite");
    }
    if (options.strictlyPositive === true && parsed <= 0) {
        throw new GogoError("<" + componentName(element) + "> '" + name + "' must be positive");
    }
    return parsed;
}

function fillColor(element: SourceElement): string {
    const raw = required(element, "fill");
    if (!COLOR_RE.test(raw)) {
        throw new GogoError(
            "<" + componentName(element) + "> 'fill' must be #RRGGBB or #RRGGBBAA"
        );
    }
    const normalized = raw.toLowerCase();
    return normalized.length === 7 ? normalized + "ff" : normalized;
}

function registerId(element: SourceElement, seen: Set<string>): string | undefined {
    const id = element.attributes.id;
    if (id !== undefined) {
        if (id.trim() === "") {
            throw new GogoError("<" + componentName(element) + "> 'id' cannot be blank");
        }
        if (seen.has(id)) {
            throw new GogoError("Duplicate component id: " + JSON.stringify(id));
        }
        seen.add(id);
    }
    return id;
}

const VIEW_ATTRIBUTES = new Set(["id", "width", "height"]);
const RECT_ATTRIBUTES = new Set(["id", "x", "y", "width", "height", "fill"]);

function compileRect(element: SourceElement, seen: Set<string>): IrRect {
    const name = componentName(element);
    const id = registerId(element, seen);
    if (name !== "Rect") {
        throw new GogoError("Unsupported Gogo component <" + name + "> at child level");
    }
    validateAttributes(element, RECT_ATTRIBUTES);
    if (element.children.length !== 0) {
        throw new GogoError("<Rect> cannot have child components");
    }
    const rect: IrRect = {
        type: "Rect",
        props: {
            x: numberProperty(element, "x", { defaultValue: 0 }),
            y: numberProperty(element, "y", { defaultValue: 0 }),
            width: numberProperty(element, "width", { strictlyPositive: true }),
            height: numberProperty(element, "height", { strictlyPositive: true }),
            fill: fillColor(element),
        },
    };
    if (id !== undefined) {
        rect.id = id;
    }
    return rect;
}

export function compileSource(source: string): GogoIr {
    const element = parseXml(source);
    const name = componentName(element);
    const seen = new Set<string>();
    const id = registerId(element, seen);
    if (name !== "View") {
        throw new GogoError("Unsupported Gogo component <" + name + "> at document root");
    }
    validateAttributes(element, VIEW_ATTRIBUTES);
    const root: IrView = {
        type: "View",
        props: {
            width: numberProperty(element, "width", { strictlyPositive: true }),
            height: numberProperty(element, "height", { strictlyPositive: true }),
        },
        children: element.children.map((child) => compileRect(child, seen)),
    };
    if (id !== undefined) {
        root.id = id;
    }
    return { format: IR_FORMAT, version: IR_VERSION, root };
}

/** Match the original canonical, alphabetically keyed, two-space JSON fixture. */
function sorted(value: unknown): unknown {
    if (Array.isArray(value)) {
        return value.map(sorted);
    }
    if (value !== null && typeof value === "object") {
        return Object.fromEntries(
            Object.entries(value).sort(([a], [b]) => a.localeCompare(b, "en")).map(
                ([key, nested]) => [key, sorted(nested)]
            )
        );
    }
    return value;
}

export function serializeIr(ir: GogoIr): string {
    // The previous compiler escaped non-ASCII code units by default.
    const json = JSON.stringify(sorted(ir), null, 2);
    return json.replace(/[\u007f-\uffff]/g, (char) =>
        "\\u" + char.charCodeAt(0).toString(16).padStart(4, "0")
    ) + "\n";
}

function parseArgs(argv: string[]): { source: string; output: string } {
    let source: string | undefined;
    let output: string | undefined;
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i]!;
        if (arg === "-o" || arg === "--output") {
            output = argv[++i];
        } else if (arg.startsWith("--output=")) {
            output = arg.slice("--output=".length);
        } else if (arg.startsWith("-") || source !== undefined) {
            throw new GogoError("Usage: bun run tools/gogo.ts <source.gogo> --output <output.json>");
        } else {
            source = arg;
        }
    }
    if (!source || !output) {
        throw new GogoError("Usage: bun run tools/gogo.ts <source.gogo> --output <output.json>");
    }
    return { source, output };
}

export async function runCli(argv: string[] = process.argv.slice(2)): Promise<number> {
    try {
        const args = parseArgs(argv);
        const source = await readFile(args.source, "utf8");
        const ir = compileSource(source);
        await mkdir(dirname(args.output), { recursive: true });
        await writeFile(args.output, serializeIr(ir), "utf8");
        console.log("Generated " + args.output);
        return 0;
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error("gogo: " + message);
        return 1;
    }
}

if (import.meta.main) {
    process.exitCode = await runCli();
}
