/** E02 focused native editor proof. No exhaustive/release profile or Docker. */
import * as fs from 'node:fs';
import * as path from 'node:path';
import {ROOT,parseCLI,newSandbox,copyTree,runCommand,writeJSON,gitHead,gitDirty,sha256,ERROR} from './compat-kit.ts';
import {packAddon} from './pack-addon.ts';
const options=parseCLI(process.argv.slice(2));
if(process.platform!=='linux')throw Error('E02 native acceptance uses approved Linux engines only');
fs.mkdirSync(options.output,{recursive:true});
for(const selection of options.engines){
 const box=newSandbox(selection),out=path.join(options.output,selection.label),results:Record<string,any>={};
 fs.mkdirSync(out,{recursive:true});
 try{
  writeJSON(path.join(out,'provenance.json'),{sourceHead:gitHead(),sourceDirty:gitDirty(),version:box.version,original_binary_sha256:box.inputHash});
  async function command(name:string,args:string[],env=box.env,marker?:string,negative=false){
   const log=path.join(out,name+'.log');
   const stage=await runCommand(args,name==='install'?box.project:box.workspace,env,log,marker,{abortOnError:!negative,expectedErrors:negative,timeout:negative?180000:60000});
   const text=fs.readFileSync(log,'utf8');process.stdout.write(text);
   if(negative){
    let unsavable=false;
    stage.unexpected_errors=text.split(/\r?\n/).filter(line=>{
     if(line==='E02_EXPECTED_UNSAVABLE_BEGIN')unsavable=true;
     if(line==='E02_EXPECTED_UNSAVABLE_END')unsavable=false;
     return ERROR.test(line) && line!=='ERROR: An EditorPlugin build callback failed.' && !(unsavable && line==="ERROR: Cannot save text file 'res://app/Screens/Home.gogo'.");
    });
    if((stage.unexpected_errors as string[]).length || /E02_EDITOR_CHECK .*: false/.test(text))stage.status='FAIL';
   }
   results[name]=stage;writeJSON(path.join(out,'results.json'),results);
   if(stage.status!=='PASS')throw Error('E02 '+name+' failed');
  }
  const packed=packAddon(path.join(out,'packed'),true);results.pack={status:'PASS',tarball_sha256:packed.manifest.tarball_sha256};
  fs.mkdirSync(box.project,{recursive:true});
  writeJSON(path.join(box.project,'package.json'),{name:'e02-direct-yarn-consumer',private:true,packageManager:'yarn@1.22.22'});
  await command('install',['corepack','yarn@1.22.22','add','--offline','--exact','--ignore-scripts','--non-interactive','--cache-folder',path.join(box.workspace,'yarn-cache'),'file:'+packed.tarball],process.env);
  const addonRoot='node_modules/@papercraftgames/estragon/addons/estragon';
  const installed=path.join(box.project,'node_modules/@papercraftgames/estragon');
  for(const [name,hash]of Object.entries(packed.manifest.files))if(sha256(path.join(installed,name))!==hash)throw Error('Installed byte mismatch: '+name);
  fs.mkdirSync(path.join(box.project,'app/Screens'),{recursive:true});
  fs.writeFileSync(path.join(box.project,'app/Existing.gogo'),'extends Node2D\nvar existing: int = 1\n');
  fs.writeFileSync(path.join(box.project,'app/Ordinary.gd'),'extends Node\nvar ordinary: int = 1\n');
  writeJSON(path.join(box.project,'gogo.config.json'),{version:1,source_roots:['app']});
  copyTree(path.join(ROOT,'tests/editor_ux'),path.join(box.project,'tests/editor_ux'));
  function configure(root:string){for(const name of ['driver.gd','probe.gd']){
   const original=fs.readFileSync(path.join(ROOT,'tests/editor_ux',name),'utf8');
   fs.writeFileSync(path.join(box.project,'tests/editor_ux',name),original.replaceAll('res://addons/estragon','res://'+root));
  }}
  configure(addonRoot);
  const settings='config_version=5\n[application]\nconfig/name="E02 direct Yarn editor"\nconfig/features=PackedStringArray("4.0", "GL Compatibility")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
  fs.writeFileSync(path.join(box.project,'project.godot'),settings);
  await command('lexical-and-template',[box.binary,'--headless','--audio-driver','Dummy','--path',box.project,'--script','res://tests/editor_ux/probe.gd'],box.env,'E02_PROBE_OK');
  fs.copyFileSync(path.join(box.project,'e03-capabilities.json'),path.join(out,'capabilities.json'));
  // Probe outputs are disposable and must not add un-authored fixtures to builds.
  fs.rmSync(path.join(box.project,'app/Screens/generated'),{recursive:true,force:true});
  fs.appendFileSync(path.join(box.project,'project.godot'),'\n[editor_plugins]\nenabled=PackedStringArray("res://'+addonRoot+'/editor/plugin.cfg", "res://tests/editor_ux/plugin.cfg")\n[editor]\nrun/main_run_args="--audio-driver Dummy --rendering-method gl_compatibility --rendering-driver opengl3"\n');
  await command('editor',[box.binary,'--audio-driver','Dummy','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--path',box.project,'--editor'],box.env,'E02_EDITOR_OK',true);
  fs.copyFileSync(path.join(box.project,'e03-editor-capabilities.json'),path.join(out,'editor-capabilities.json'));
  await command('editor-restart',[box.binary,'--audio-driver','Dummy','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--path',box.project,'--editor'],box.env,'E02_EDITOR_OK',true);
  for(const file of fs.readdirSync(box.project).filter(name=>/^e0[23]-.*\.png$/.test(name)))fs.copyFileSync(path.join(box.project,file),path.join(out,file.slice(4)));
  for(const [name,hash]of Object.entries(packed.manifest.files))if(sha256(path.join(installed,name))!==hash)throw Error('Editor changed installed package bytes/UIDs: '+name);
  if(fs.existsSync(path.join(box.project,'addons/estragon')) || fs.existsSync(path.join(box.project,'node_modules/.gdignore')))throw Error('Forbidden copy/ignore fallback');
  // Focused template-only path proofs; no repeated three-layout editor suites.
  let previous=path.join(box.project,addonRoot);
  for(const [label,root]of [['relocated','modules/UI toolkit'],['standard','addons/estragon']]){
   const target=path.join(box.project,root!);fs.mkdirSync(path.dirname(target),{recursive:true});fs.renameSync(previous,target);previous=target;
   configure(root!);fs.writeFileSync(path.join(box.project,'project.godot'),settings);fs.rmSync(path.join(box.project,'.godot'),{recursive:true,force:true});
   await command('template-'+label,[box.binary,'--headless','--audio-driver','Dummy','--path',box.project,'--script','res://tests/editor_ux/probe.gd'],box.env,'E02_PROBE_OK');
  }
  writeJSON(path.join(out,'consumer.json'),{source:gitHead(),tarball_sha256:packed.manifest.tarball_sha256,direct_yarn:true,package_unchanged:true,template_layouts:['direct','relocated','standard'],external_compiler:false});
 }finally{
  // Preserve actual graphics even when a later native/lifecycle assertion fails.
  if(fs.existsSync(box.project))for(const file of fs.readdirSync(box.project).filter(name=>/^e0[23]-.*\.png$/.test(name)))fs.copyFileSync(path.join(box.project,file),path.join(out,file.slice(4)));
  for(const relative of ['app/Screens/Home.gogo','app/Screens/Spatial.gogo','app/Screens/generated/Home.gd']){
   const file=path.join(box.project,relative);if(fs.existsSync(file)&&fs.statSync(file).isFile())fs.copyFileSync(file,path.join(out,relative.replaceAll('/','-')));
  }
  writeJSON(path.join(out,'results.json'),results);box.dispose();
 }
}
