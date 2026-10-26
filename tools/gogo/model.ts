/** Coordinates are 1-based UTF-16 columns; offsets are zero-based, with exclusive span ends. */
export interface Position { readonly offset: number; readonly line: number; readonly column: number }
export interface Span { readonly start: Position; readonly end: Position }

export class GogoCompileError extends Error {
    constructor(readonly sourceName: string, readonly span: Span, detail: string) {
        super(`${sourceName}:${span.start.line}:${span.start.column}: ${detail}`);
        this.name = "GogoCompileError";
    }
}

export interface AttributeSyntax {
    readonly name: string;
    readonly nameSpan: Span;
    readonly value: string;
    readonly valueSpan: Span;
}

/** A markup expression, not an XML document or the legacy serialized UI IR. */
export interface ComponentSyntax {
    readonly kind: "component-expression";
    readonly name: string;
    readonly nameSpan: Span;
    readonly attributes: readonly AttributeSyntax[];
    readonly children: readonly ComponentSyntax[];
    readonly span: Span;
}

export type Literal =
    | { readonly kind: "number-literal"; readonly value: number; readonly span: Span }
    | { readonly kind: "boolean-literal"; readonly value: boolean; readonly span: Span }
    | { readonly kind: "color-literal"; readonly value: string; readonly span: Span };

export type ComponentName = "VBox" | "HBox" | "Rect";
export type PropertyName = "width" | "height" | "fill_width" | "fill_height" | "gap" | "fill";
export interface ComponentExpression {
    readonly kind: "component-expression";
    readonly component: ComponentName;
    readonly properties: readonly { readonly name: PropertyName; readonly value: Literal }[];
    readonly children: readonly ComponentExpression[];
    readonly span: Span;
}
