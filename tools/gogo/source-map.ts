import type { Position, Span } from "./model.ts";
import { SourceFile } from "./source.ts";

export interface SourceMapSegment { readonly generated: Span; readonly original: Span; readonly kind: "copied" | "generated" }
export interface GogoSourceMap {
    readonly format: "estragon.gogo.source-map";
    readonly version: 1;
    readonly sourceName: string;
    readonly sourceContent: string;
    readonly segments: readonly SourceMapSegment[];
}
export interface Compilation { readonly mode: "markup" | "hybrid"; readonly code: string; readonly sourceMap: GogoSourceMap }

/** All emission goes through ranges, never search-and-replace of authored code. */
export class MappedWriter {
    private text = "";
    private readonly pending: { from: number; to: number; original: Span; kind: SourceMapSegment["kind"] }[] = [];
    constructor(private readonly source: SourceFile) {}
    append(text: string, original?: Span, copied = false): void {
        const from = this.text.length;
        this.text += text;
        if (original && text.length) this.pending.push({ from, to: this.text.length, original, kind: copied ? "copied" : "generated" });
    }
    finish(): { code: string; sourceMap: GogoSourceMap } {
        const generated = new SourceFile(this.text, "<generated>");
        return { code: this.text, sourceMap: {
            format: "estragon.gogo.source-map", version: 1, sourceName: this.source.name, sourceContent: this.source.text,
            segments: this.pending.map(item => ({ generated: generated.span(item.from, item.to), original: item.original, kind: item.kind })),
        } };
    }
}

export function originalPosition(result: Pick<Compilation, "code" | "sourceMap">, line: number, column = 1): Position | undefined {
    const offset = new SourceFile(result.code, "<generated>").offset(line, column);
    const segment = result.sourceMap.segments.find(item => item.generated.start.offset <= offset && offset < item.generated.end.offset)
        ?? result.sourceMap.segments.find(item => item.generated.start.line <= line && line <= item.generated.end.line);
    if (!segment) return undefined;
    if (segment.kind === "generated") return segment.original.start;
    return new SourceFile(result.sourceMap.sourceContent, result.sourceMap.sourceName).position(
        segment.original.start.offset + Math.min(segment.original.end.offset - segment.original.start.offset, Math.max(0, offset - segment.generated.start.offset)));
}

export function serializeSourceMap(map: GogoSourceMap): string { return JSON.stringify(map) + "\n"; }

/** Diagnostic adapter only; does not parse or rewrite GDScript source. */
export function traceGodotDiagnostics(output: string, compiled: ReadonlyMap<string, Compilation>): string {
    const traces = new Set<string>();
    for (const match of output.matchAll(/(res:\/\/[^\n]+?\.gd):(\d+)(?::(\d+))?/g)) {
        const result = compiled.get(match[1]!);
        if (!result) continue;
        const point = originalPosition(result, Number(match[2]), Number(match[3] ?? 1));
        if (point) traces.add(`Gogo source: ${result.sourceMap.sourceName}:${point.line}:${point.column} (generated ${match[1]}:${match[2]})`);
    }
    return output + (traces.size ? "\n" + [...traces].join("\n") : "");
}
