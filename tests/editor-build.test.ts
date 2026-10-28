import { afterEach, describe, expect, test } from "bun:test";
import { mkdir, mkdtemp, readFile, rm, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { buildProject, discoverSources, outputFor } from "../tools/build-gogo.ts";
const folders: string[] = [];
afterEach(async () => { for (const path of folders.splice(0)) await rm(path, { recursive: true, force: true }); });
async function fixture() {
    const path = await mkdtemp(join(tmpdir(), 'estragon-build-')); folders.push(path);
    await mkdir(join(path, 'ui'), { recursive: true });
    await writeFile(join(path, 'gogo.config.json'), JSON.stringify({ version: 1, source_roots: ['ui'] }));
    await writeFile(join(path, 'ui/Screen.gogo'), 'extends EstragonSurface\nfunc _init():\n    set_root(<Text text="hello"/>)\n');
    return path;
}

describe('T08 project builds', () => {
    test('discovers sorted deduplicated roots and excludes irrelevant directories', async () => {
        const path = await fixture();
        for (const name of ['generated', 'node_modules', 'tests', 'vendor', '.cache']) {
            await mkdir(join(path, 'ui', name)); await writeFile(join(path, 'ui', name, 'Invalid.gogo'), 'invalid');
        }
        await mkdir(join(path, 'ui/nested')); await writeFile(join(path, 'ui/nested/A.gogo'), '<Rect/>');
        await writeFile(join(path, 'gogo.config.json'), JSON.stringify({ version: 1, source_roots: ['ui/nested', 'ui'] }));
        expect(await discoverSources(path)).toEqual(['ui/Screen.gogo', 'ui/nested/A.gogo']);
        expect(outputFor('ui/nested/A.gogo')).toBe('ui/nested/generated/A.gd');
    });
    test('preserves deterministic code/maps, authored source and unchanged output timestamps', async () => {
        const path = await fixture(); const source = await readFile(join(path, 'ui/Screen.gogo'), 'utf8');
        const first = await buildProject(path); expect(first.ok).toBe(true); expect(first.changed).toEqual(['ui/generated/Screen.gd']);
        const generated = join(path, first.outputs[0]!); const code = await readFile(generated, 'utf8');
        const map = await readFile(generated + '.map.json', 'utf8'); const time = (await stat(generated)).mtimeMs;
        expect(JSON.parse(map).sourceName).toBe('ui/Screen.gogo');
        const second = await buildProject(path); expect(second.ok).toBe(true); expect(second.changed).toEqual([]);
        expect(await readFile(generated, 'utf8')).toBe(code); expect(await readFile(generated + '.map.json', 'utf8')).toBe(map);
        expect((await stat(generated)).mtimeMs).toBe(time); expect(await readFile(join(path, 'ui/Screen.gogo'), 'utf8')).toBe(source);
    });
    test('compiles all sources before touching any existing output on frontend failure', async () => {
        const path = await fixture(); await buildProject(path);
        const previous = await readFile(join(path, 'ui/generated/Screen.gd'), 'utf8');
        await writeFile(join(path, 'ui/Screen.gogo'), '<Rect width="12"/>');
        await writeFile(join(path, 'ui/Invalid.gogo'), '<Unknown/>');
        const result = await buildProject(path); expect(result.ok).toBe(false); expect(result.changed).toEqual([]);
        expect(result.diagnostics[0]).toContain('ui/Invalid.gogo:1:2: Unknown component');
        expect(await readFile(join(path, 'ui/generated/Screen.gd'), 'utf8')).toBe(previous);
        await rm(join(path, 'ui/Invalid.gogo')); expect((await buildProject(path)).ok).toBe(true);
        expect(await Bun.file(join(path, 'ui/generated/Screen.gd.map.json')).exists()).toBe(false);
    });
    test.each([{}, {version: 2, source_roots: ['ui']}, {version:1, source_roots: []}, {version:1, source_roots:['../ui']}, {version:1,source_roots:['tests']}, {version:1,source_roots:['ui'], unknown:true}])('rejects invalid config %j', async config => {
        const path = await fixture(); await writeFile(join(path, 'gogo.config.json'), JSON.stringify(config));
        expect((await buildProject(path)).ok).toBe(false);
    });
    test('rejects missing config/root and paths outside project', async () => {
        const path = await fixture(); await rm(join(path, 'gogo.config.json')); expect((await buildProject(path)).ok).toBe(false);
        await writeFile(join(path, 'gogo.config.json'), JSON.stringify({version:1, source_roots:['missing']})); expect((await buildProject(path)).ok).toBe(false);
        expect((await buildProject(path + '-missing')).ok).toBe(false);
    });
    test('rejects source and output symlinks without modifying external files', async () => {
        const path = await fixture(); const outside = join(path, 'original'); await writeFile(outside, 'keep');
        await symlink(outside, join(path, 'ui/Symlink.gogo')); expect((await buildProject(path)).ok).toBe(false);
        await rm(join(path, 'ui/Symlink.gogo')); await mkdir(join(path, 'ui/generated'));
        await symlink(outside, join(path, 'ui/generated/Screen.gd')); expect((await buildProject(path)).ok).toBe(false);
        expect(await readFile(outside, 'utf8')).toBe('keep');
    });
    test('refuses to overwrite authored source or config with a CLI report', async () => {
        const path = await fixture();
        for (const report of ['ui/Screen.gogo', 'gogo.config.json']) {
            const target = join(path, report); const original = await readFile(target, 'utf8');
            const child = Bun.spawn([process.execPath, resolve('tools/build-gogo.ts'), '--project', path, '--report', target], { stdout: 'pipe', stderr: 'pipe' });
            expect(await child.exited).toBe(1);
            expect(await readFile(target, 'utf8')).toBe(original);
        }
    });
    test('reports missing Godot executable as build failure and writes CLI report', async () => {
        const path = await fixture(); const result = await buildProject(path, join(path, 'not-godot'));
        expect(result.ok).toBe(false); expect(result.diagnostics.length).toBeGreaterThan(0);
        const report = join(path, 'report.json');
        const child = Bun.spawn([process.execPath, resolve('tools/build-gogo.ts'), '--project', path, '--report', report]);
        expect(await child.exited).toBe(0); expect(JSON.parse(await readFile(report, 'utf8')).ok).toBe(true);
    });
});
