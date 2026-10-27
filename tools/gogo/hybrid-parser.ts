import type { GdscriptExpressionSyntax, HybridComponentSyntax, HybridModuleSyntax, HybridSyntaxPart } from "./model.ts";
import { parseMarkupExpressionAt } from "./parser.ts";
import { SourceFile } from "./source.ts";

const OPERAND_KEYWORDS = new Set(["return", "yield", "await", "if", "elif", "else", "while", "in", "and", "or", "not", "assert", "match"]);
const OPEN: Readonly<Record<string, string>> = { "(": ")", "[": "]", "{": "}" };
const MULTI_OPERATORS = ["**=", "<<=", ">>=", ":=", "==", "!=", "<=", ">=", "<<", ">>", "**", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "&&", "||", "->"];
const identifierStart = (char: string) => char !== "" && /[\p{L}_]/u.test(char);
const identifierPart = (char: string) => char !== "" && /[\p{L}\p{N}\p{M}_]/u.test(char);

/** Lexical composition, not a replacement GDScript semantic parser. */
export class HybridParser {
    readonly identifiers = new Set<string>();
    private depth = 0;
    constructor(readonly file: SourceFile) {}

    private component(offset: number): HybridComponentSyntax {
        if (++this.depth > 256) this.file.fail("Hybrid expression nesting exceeds 256", offset);
        try {
            return parseMarkupExpressionAt(this.file.text, offset, this.file.name, start => this.expression(start));
        } finally { this.depth--; }
    }

    private stringEnd(start: number): number {
        const text = this.file.text, quote = text[start]!;
        const delimiter = text.startsWith(quote.repeat(3), start) ? quote.repeat(3) : quote;
        let offset = start + delimiter.length;
        while (offset < text.length) {
            if (text.startsWith(delimiter, offset)) return offset + delimiter.length;
            if (text[offset] === "\\") {
                offset++;
                if (text[offset] === "\r" && text[offset + 1] === "\n") offset++;
                offset++;
            } else {
                if (delimiter.length === 1 && (text[offset] === "\n" || text[offset] === "\r")) {
                    this.file.fail("Unterminated GDScript string", start, offset);
                }
                offset++;
            }
        }
        this.file.fail("Unterminated GDScript string", start, offset);
    }

    private expression(start: number): GdscriptExpressionSyntax {
        const scanned = this.scan(start + 1, true);
        if (!scanned.hasToken) this.file.fail("Expected a GDScript expression inside braces", start, scanned.end);
        return { kind: "gdscript-expression", parts: scanned.parts, span: this.file.span(start, scanned.end + 1) };
    }

    private scan(start: number, braced: boolean): { parts: HybridSyntaxPart[]; end: number; hasToken: boolean } {
        const text = this.file.text;
        const point = (index: number) => index < text.length ? String.fromCodePoint(text.codePointAt(index)!) : "";
        const parts: HybridSyntaxPart[] = [];
        const stack: { close: string; start: number }[] = [];
        let offset = start, copied = start, operand = true, hasToken = false;
        const flush = () => {
            if (copied < offset) parts.push({ kind: "gdscript-source", span: this.file.span(copied, offset) });
        };
        while (offset < text.length) {
            const char = point(offset);
            if (char === " " || char === "\t") { offset++; continue; }
            if (char === "\r" || char === "\n") {
                if (stack.length === 0 && !braced) operand = true;
                offset++;
                continue;
            }
            if (char === "#") { while (offset < text.length && text[offset] !== "\n" && text[offset] !== "\r") offset++; continue; }
            if (char === "\\" && (text[offset + 1] === "\n" || text[offset + 1] === "\r")) {
                offset += text[offset + 1] === "\r" && text[offset + 2] === "\n" ? 3 : 2;
                continue;
            }
            if (braced && stack.length === 0 && char === "}") { flush(); return { parts, end: offset, hasToken }; }
            hasToken = true;
            if (char === '"' || char === "'") { offset = this.stringEnd(offset); operand = false; continue; }
            if (char === "<" && operand && identifierStart(point(offset + 1))) {
                flush();
                const component = this.component(offset);
                parts.push(component);
                offset = component.span.end.offset;
                copied = offset;
                operand = false;
                continue;
            }
            if (identifierStart(char)) {
                const from = offset;
                offset += char.length;
                while (identifierPart(point(offset))) offset += point(offset).length;
                const word = text.slice(from, offset);
                this.identifiers.add(word);
                operand = OPERAND_KEYWORDS.has(word);
                continue;
            }
            if (/[0-9]/.test(char)) {
                offset++;
                while (offset < text.length && /[A-Za-z0-9_.]/.test(text[offset]!)) offset++;
                operand = false;
                continue;
            }
            if (OPEN[char]) { stack.push({ close: OPEN[char]!, start: offset }); offset++; operand = true; continue; }
            if (char === ")" || char === "]" || char === "}") {
                const expected = stack.pop();
                if (expected?.close !== char) this.file.fail(`Unmatched GDScript delimiter ${char}`, offset);
                offset++; operand = false; continue;
            }
            const operator = MULTI_OPERATORS.find(value => text.startsWith(value, offset));
            offset += operator?.length ?? char.length;
            operand = char !== ".";
        }
        if (stack.length) this.file.fail(`Unclosed GDScript delimiter; expected ${stack.at(-1)!.close}`, stack.at(-1)!.start, offset);
        if (braced) this.file.fail("Unterminated GDScript expression; expected }", start - 1, offset);
        flush();
        return { parts, end: offset, hasToken };
    }

    module(): HybridModuleSyntax {
        const scanned = this.scan(0, false);
        return { parts: scanned.parts, identifiers: this.identifiers };
    }
}

export function parseHybrid(source: string, sourceName = "<source>"): HybridModuleSyntax {
    return new HybridParser(new SourceFile(source, sourceName)).module();
}
