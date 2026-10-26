import { describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { compileSource, GogoError, serializeIr } from "../tools/gogo.ts";

const PREFIX = '<gogo:View xmlns:gogo="urn:estragon:gogo:1" width="100" height="80">';
const SUFFIX = "</gogo:View>";
const sampleSource = fileURLToPath(new URL("../examples/hello/Main.gogo", import.meta.url));
const sampleIr = fileURLToPath(new URL("../examples/hello/generated/Main.gogo.json", import.meta.url));
const compiler = fileURLToPath(new URL("../tools/gogo.ts", import.meta.url));

function compileChild(content: string) {
    return compileSource(PREFIX + content + SUFFIX);
}

describe("stage-0 Gogo compiler", () => {
    test("compiles a Rect into independent UI IR, not Godot nodes", () => {
        const ir = compileChild(
            '<gogo:Rect id="r" x="2" y="3" width="20" height="12" fill="#AABBCC" />'
        );
        expect(ir.format).toBe("estragon.gogo.ir");
        expect(ir.version).toBe(1);
        expect(ir.root.type).toBe("View");
        expect(ir.root.children).toEqual([{
            type: "Rect",
            id: "r",
            props: { x: 2, y: 3, width: 20, height: 12, fill: "#aabbccff" },
        }]);
        expect(JSON.stringify(ir)).not.toContain("Control");
    });

    test("defaults positions and preserves fractional dimensions and alpha", () => {
        const ir = compileChild('<gogo:Rect width="1.5" height="2" fill="#11223380" />');
        expect(ir.root.children[0]?.props).toEqual({
            x: 0, y: 0, width: 1.5, height: 2, fill: "#11223380",
        });
    });

    test("permits an empty View", () => {
        expect(compileChild("").root.children).toEqual([]);
    });

    test("accepts an alternative namespace prefix", () => {
        const ir = compileSource(
            '<ui:View xmlns:ui="urn:estragon:gogo:1" width="1" height="2">' +
            '<ui:Rect width="3" height="4" fill="#abcdef" /></ui:View>'
        );
        expect(ir.root.children[0]?.type).toBe("Rect");
    });

    test("accepts a default namespace without a prefix", () => {
        const ir = compileSource(
            '<View xmlns="urn:estragon:gogo:1" width="1" height="2">' +
            '<Rect width="3" height="4" fill="#abcdef" /></View>'
        );
        expect(ir.root.children).toHaveLength(1);
    });

    test("recognizes character entities in IDs", () => {
        const ir = compileChild('<gogo:Rect id="A&amp;B" width="1" height="1" fill="#123456" />');
        expect(ir.root.children[0]?.id).toBe("A&B");
    });

    test("rejects unknown components", () => {
        expect(() => compileChild("<gogo:Button />")).toThrow("Unsupported Gogo component");
    });

    test("rejects Godot widget names", () => {
        expect(() => compileChild("<gogo:VBoxContainer />")).toThrow("Unsupported Gogo component");
    });

    test("rejects duplicate and blank component IDs", () => {
        expect(() => compileChild(
            '<gogo:Rect id="same" width="1" height="1" fill="#ffffff" />' +
            '<gogo:Rect id="same" width="1" height="1" fill="#000000" />'
        )).toThrow("Duplicate component id");
        expect(() => compileChild(
            '<gogo:Rect id="  " width="1" height="1" fill="#ffffff" />'
        )).toThrow("cannot be blank");
    });

    test("rejects malformed colors and accepts eight-digit hex", () => {
        expect(() => compileChild(
            '<gogo:Rect width="1" height="1" fill="red" />'
        )).toThrow("#RRGGBB");
        expect(compileChild(
            '<gogo:Rect width="1" height="1" fill="#aBcDeF01" />'
        ).root.children[0]?.props.fill).toBe("#abcdef01");
    });

    test("rejects zero and negative dimensions", () => {
        for (const width of ["0", "-1"]) {
            expect(() => compileChild(
                '<gogo:Rect width="' + width + '" height="1" fill="#ffffff" />'
            )).toThrow("positive");
        }
    });

    test("rejects non-finite numbers", () => {
        for (const width of ["NaN", "inf", "-Infinity", "1e309"]) {
            expect(() => compileChild(
                '<gogo:Rect width="' + width + '" height="1" fill="#ffffff" />'
            )).toThrow("finite");
        }
    });

    test("rejects invalid numerals rather than silently coercing them", () => {
        for (const width of ["", "0x10", " ", "nope", "{count}"]) {
            expect(() => compileChild(
                '<gogo:Rect width="' + width + '" height="1" fill="#ffffff" />'
            )).toThrow("must be a number");
        }
    });

    test("rejects missing required properties", () => {
        expect(() => compileChild('<gogo:Rect width="1" fill="#ffffff" />'))
            .toThrow("requires 'height'");
        expect(() => compileSource('<gogo:View xmlns:gogo="urn:estragon:gogo:1" width="1" />'))
            .toThrow("requires 'height'");
    });

    test("rejects unsupported attributes, including namespace-qualified ones", () => {
        expect(() => compileChild(
            '<gogo:Rect width="1" height="1" fill="#ffffff" godot_node="true" />'
        )).toThrow("unsupported attributes");
        expect(() => compileChild(
            '<gogo:Rect xmlns:other="urn:other" other:id="x" width="1" height="1" fill="#ffffff" />'
        )).toThrow("unsupported attributes");
    });

    test("rejects nested containers and Rect children", () => {
        expect(() => compileChild('<gogo:View width="1" height="1" />'))
            .toThrow("Unsupported Gogo component");
        expect(() => compileChild(
            '<gogo:Rect width="1" height="1" fill="#ffffff">' +
            '<gogo:Rect width="1" height="1" fill="#000000" />' +
            "</gogo:Rect>"
        )).toThrow("cannot have child components");
    });

    test("rejects non-whitespace text and CDATA in components", () => {
        expect(() => compileChild("not allowed")).toThrow("does not support text content");
        expect(() => compileChild("<![CDATA[not allowed]]>"))
            .toThrow("does not support text content");
        expect(() => compileChild(
            '<gogo:Rect width="1" height="1" fill="#ffffff" />tail'
        )).toThrow("does not support text content");
    });

    test("rejects malformed XML and multiple roots", () => {
        expect(() => compileSource("<broken")).toThrow("Malformed Gogo XML");
        expect(() => compileSource(PREFIX + SUFFIX + PREFIX + SUFFIX))
            .toThrow("Malformed Gogo XML");
    });

    test("rejects the wrong namespace and wrong document root", () => {
        expect(() => compileSource('<View width="1" height="1" />'))
            .toThrow("Gogo namespace");
        expect(() => compileSource(
            '<gogo:Rect xmlns:gogo="urn:estragon:gogo:1" width="1" height="1" fill="#ffffff" />'
        )).toThrow("document root");
    });

    test("rejects XML DOCTYPE declarations", () => {
        expect(() => compileSource(
            '<!DOCTYPE View [<!ENTITY x "oops">]>' + PREFIX + SUFFIX
        )).toThrow("DOCTYPE is not supported");
    });

    test("raises GogoError for invalid input", () => {
        expect(() => compileSource("<bad")).toThrow(GogoError);
    });

    test("produces deterministic, alphabetically keyed JSON with a final newline", () => {
        const ir = compileChild(
            '<gogo:Rect id="x" width="1" height="2" fill="#ABCDEF" />'
        );
        const text = serializeIr(ir);
        expect(text.endsWith("\n")).toBe(true);
        expect(text).toBe(serializeIr(compileChild(
            '<gogo:Rect fill="#ABCDEF" height="2" width="1" id="x" />'
        )));
        expect(text.indexOf('"format"')).toBeLessThan(text.indexOf('"root"'));
    });

    test("escapes non-ASCII IDs like the original JSON compiler", () => {
        const ir = compileChild('<gogo:Rect id="café" width="1" height="1" fill="#abcdef" />');
        expect(serializeIr(ir)).toContain('"caf\\u00e9"');
    });

    test("matches the committed stage-0 sample byte for byte", () => {
        const actual = serializeIr(compileSource(readFileSync(sampleSource, "utf8")));
        expect(actual).toBe(readFileSync(sampleIr, "utf8"));
    });
});

describe("Gogo CLI", () => {
    test("writes deterministic IR to a requested output path", () => {
        const directory = mkdtempSync(join(tmpdir(), "estragon-gogo-"));
        try {
            const output = join(directory, "nested", "result.json");
            const result = Bun.spawnSync(
                [process.execPath, compiler, sampleSource, "--output", output],
                { stdout: "pipe", stderr: "pipe" },
            );
            expect(result.exitCode).toBe(0);
            expect(readFileSync(output, "utf8")).toBe(readFileSync(sampleIr, "utf8"));
        } finally {
            rmSync(directory, { recursive: true, force: true });
        }
    });

    test("returns a failure without overwriting output on invalid source", () => {
        const directory = mkdtempSync(join(tmpdir(), "estragon-gogo-"));
        try {
            const input = join(directory, "invalid.gogo");
            const output = join(directory, "result.json");
            writeFileSync(input, "<broken", "utf8");
            writeFileSync(output, "keep me", "utf8");
            const result = Bun.spawnSync(
                [process.execPath, compiler, input, "-o", output],
                { stdout: "pipe", stderr: "pipe" },
            );
            expect(result.exitCode).toBe(1);
            expect(new TextDecoder().decode(result.stderr)).toContain("gogo:");
            expect(readFileSync(output, "utf8")).toBe("keep me");
        } finally {
            rmSync(directory, { recursive: true, force: true });
        }
    });

    test("requires a source and output argument", () => {
        const result = Bun.spawnSync([process.execPath, compiler], { stderr: "pipe" });
        expect(result.exitCode).toBe(1);
        expect(new TextDecoder().decode(result.stderr)).toContain("Usage:");
    });
});
