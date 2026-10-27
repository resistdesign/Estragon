import { GogoCompileError, type Position, type Span } from "./model.ts";

/** Shared source indexing; UTF-16 offsets, 1-based coordinates, CRLF aware. */
export class SourceFile {
    private readonly lines = [0];
    constructor(readonly text: string, readonly name: string) {
        for (let i = 0; i < text.length; i++) {
            if (text[i] === "\r") {
                if (text[i + 1] === "\n") i++;
                this.lines.push(i + 1);
            } else if (text[i] === "\n") this.lines.push(i + 1);
        }
    }
    position(offset: number): Position {
        let low = 0, high = this.lines.length;
        while (low + 1 < high) {
            const mid = (low + high) >>> 1;
            if (this.lines[mid]! <= offset) low = mid; else high = mid;
        }
        return { offset, line: low + 1, column: offset - this.lines[low]! + 1 };
    }
    offset(line: number, column = 1): number {
        return Math.min(this.text.length, (this.lines[line - 1] ?? this.text.length) + column - 1);
    }
    span(start: number, end = start): Span { return { start: this.position(start), end: this.position(end) }; }
    fail(detail: string, start: number, end = start): never {
        throw new GogoCompileError(this.name, this.span(start, end), detail);
    }
}
