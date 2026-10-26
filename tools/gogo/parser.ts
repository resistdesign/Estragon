import { GogoCompileError, type AttributeSyntax, type ComponentSyntax, type Position, type Span } from "./model.ts";

/** Recursive-descent parser for the T04 markup island only. No GDScript rewriting. */
class MarkupParser {
    private offset = 0;
    private line = 1;
    private column = 1;

    constructor(private readonly source: string, private readonly sourceName: string, start: number) {
        if (!Number.isInteger(start) || start < 0 || start > source.length) {
            throw new RangeError("Markup start offset is outside the source");
        }
        while (this.offset < start) this.advance();
    }

    private position(): Position { return { offset: this.offset, line: this.line, column: this.column }; }
    private span(start: Position): Span { return { start, end: this.position() }; }
    private at(text: string): boolean { return this.source.startsWith(text, this.offset); }
    private current(): string { return this.source[this.offset] ?? ""; }
    private advance(): void {
        const char = this.source[this.offset++];
        if (char === "\r" || (char === "\n" && this.source[this.offset - 2] !== "\r")) {
            this.line++;
            this.column = 1;
        } else if (char !== "\n") this.column++;
    }
    private fail(detail: string, start = this.position()): never {
        throw new GogoCompileError(this.sourceName, this.span(start), detail);
    }
    private expect(text: string): void {
        if (!this.at(text)) this.fail(`Expected ${JSON.stringify(text)}`);
        for (let i = 0; i < text.length; i++) this.advance();
    }
    private whitespace(): boolean {
        const start = this.offset;
        while (this.current() !== "" && /[ \t\r\n]/.test(this.current())) this.advance();
        return this.offset !== start;
    }
    trivia(): void {
        this.whitespace();
        while (this.at("<!--")) {
            const start = this.position();
            this.expect("<!--");
            while (!this.at("-->")) {
                if (this.offset >= this.source.length) this.fail("Unterminated comment", start);
                this.advance();
            }
            this.expect("-->");
            this.whitespace();
        }
    }
    private name(): { text: string; span: Span } {
        const start = this.position();
        if (!/[A-Za-z_]/.test(this.current()) || this.current() === "") this.fail("Expected component or property name");
        this.advance();
        while (this.current() !== "" && /[A-Za-z0-9_.:-]/.test(this.current())) this.advance();
        return { text: this.source.slice(start.offset, this.offset), span: this.span(start) };
    }
    private attribute(): AttributeSyntax {
        const name = this.name();
        this.whitespace();
        this.expect("=");
        this.whitespace();
        const quote = this.current();
        if (quote !== '"' && quote !== "'") this.fail("Expected a quoted literal property value; expressions are not supported in T04");
        this.advance();
        const start = this.position();
        while (this.current() !== quote) {
            if (this.offset >= this.source.length) this.fail("Unterminated property value", start);
            if (this.current() === "<" || this.current() === "&" || this.current() === "\\") {
                this.fail("Markup delimiters, entities and escapes are not supported in literal values");
            }
            this.advance();
        }
        const valueSpan = this.span(start);
        const value = this.source.slice(start.offset, this.offset);
        this.advance();
        return { name: name.text, nameSpan: name.span, value, valueSpan };
    }
    component(depth = 0): ComponentSyntax {
        this.trivia();
        const start = this.position();
        if (depth >= 256) this.fail("Component nesting exceeds the T04 limit of 256");
        this.expect("<");
        const name = this.name();
        const attributes: AttributeSyntax[] = [];
        const children: ComponentSyntax[] = [];
        while (true) {
            const separated = this.whitespace();
            if (this.at("/>")) {
                this.expect("/>");
                return { kind: "component-expression", name: name.text, nameSpan: name.span, attributes, children, span: this.span(start) };
            }
            if (this.at(">")) { this.expect(">"); break; }
            if (!separated) this.fail("Expected whitespace before a property, or a tag terminator");
            attributes.push(this.attribute());
        }
        this.trivia();
        while (!this.at("</")) {
            if (this.offset >= this.source.length) this.fail(`Missing closing tag </${name.text}>`);
            if (!this.at("<")) this.fail("Only component children are supported; text and GDScript belong to later slices");
            children.push(this.component(depth + 1));
            this.trivia();
        }
        this.expect("</");
        const closing = this.name();
        if (closing.text !== name.text) this.fail(`Expected </${name.text}>, found </${closing.text}>`, closing.span.start);
        this.whitespace();
        this.expect(">");
        return { kind: "component-expression", name: name.text, nameSpan: name.span, attributes, children, span: this.span(start) };
    }
    requireEnd(): void {
        this.trivia();
        if (this.offset !== this.source.length) this.fail("Expected one component expression; trailing source is not supported in T04");
    }
}

/** Future hybrid parsers can consume a markup expression at an existing offset. */
export function parseMarkupExpressionAt(source: string, start: number, sourceName = "<source>"): ComponentSyntax {
    return new MarkupParser(source, sourceName, start).component();
}

export function parseMarkup(source: string, sourceName = "<source>"): ComponentSyntax {
    const parser = new MarkupParser(source, sourceName, 0);
    const expression = parser.component();
    parser.requireEnd();
    return expression;
}
