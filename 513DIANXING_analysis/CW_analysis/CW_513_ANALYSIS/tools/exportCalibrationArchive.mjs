// Run from a workspace with @oai/artifact-tool available in node_modules.
// Usage: node exportCalibrationArchive.mjs --python <python> [--preview <dir>]
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';
const require=createRequire(path.join(process.cwd(),'package.json'));
const {Workbook,SpreadsheetFile}=await import(pathToFileURL(require.resolve('@oai/artifact-tool')).href);
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.dirname(here);
const arg=(key,otherwise)=>{const i=process.argv.indexOf(key);return i<0?otherwise:process.argv[i+1];};
const python=arg('--python','python');
const out=arg('--output',path.join(root,'docs/20261012_board_calibration/两套板卡刻度归档_20261004.xlsx'));
const preview=arg('--preview',null);
const csv=path.join(root,'_shared/+converter/+calibration/report_calibrations_20261004.csv');
const source=await Workbook.fromCSV((await fs.readFile(csv,'utf8')).replace(/^\uFEFF/,''),{sheetName:'source'});
const matrix=source.worksheets.getItemAt(0).getUsedRange().values;
const records=matrix.slice(1).filter(r=>r[0]).map(r=>Object.fromEntries(matrix[0].map((k,i)=>[k,r[i]??''])));
if(records.length!==55)throw new Error(`Expected 55 bound report rows, got ${records.length}; review archive version before updating.`);
const w=Workbook.create();
const heads=['器件','接口','改焊状态','默认采用','斜率 k（V/code）','截距 b（V）','刻度频率（Hz）','点数','日期','码幅定义','报告章节 / 表行','备注'];
const order=['AD2208','AD9245','AD677','DA9726','DA766'];
const widths=[12,17,15,11,24,24,19,8,14,22,27,28];
const stateNames={after:'改焊后',before:'改焊前',unspecified:'报告未注明'};
const defaults=(r,list)=>{const peers=list.filter(x=>x.device===r.device&&x.channel===r.channel);return peers.some(x=>x.calibrationState==='after')?r.calibrationState==='after':peers.length===1;};
const number=x=>x===''||x===null?null:Number(x);
for(const [board,name,expected] of [['jianding','鉴定件',27],['jiaqiang','电性加强件',28]]){
  const all=records.filter(r=>r.boardType===board);
  if(all.length!==expected)throw new Error(`Row count ${board}`);
  all.sort((a,b)=>order.indexOf(a.device)-order.indexOf(b.device)||a.channel.localeCompare(b.channel,'en',{numeric:true})||Number(defaults(b,all))-Number(defaults(a,all))||a.calibrationState.localeCompare(b.calibrationState));
  const sh=w.worksheets.add(name);sh.showGridLines=false;sh.tabColor='#17365D';
  const end=7+all.length,last=end+12;
  sh.getRange(`A1:L${last}`).format={font:{name:'Microsoft YaHei',size:10,color:'#202B38'},fill:'#FFFFFF',verticalAlignment:'center',rowHeight:24};
  widths.forEach((width,i)=>sh.getRangeByIndexes(0,i,last,1).format.columnWidth=width);
  const band=(row,text,size=10)=>{sh.mergeCells(`A${row}:L${row}`);sh.getRange(`A${row}`).values=[[text]];sh.getRange(`A${row}:L${row}`).format.font={name:'Microsoft YaHei',size,color:row===2?'#17365D':'#526174',bold:row===2};};
  band(2,`${name}刻度归档`,16);sh.getRange('A2:L2').format.rowHeight=32;
  band(3,`来源：${all[0].sourceDocument}    共${expected}条记录`);
  band(4,'默认选择：优先改焊后；仅一版时采用该记录。改焊前后记录全部保留。');
  band(5,'CSV供分析程序读取；本表为同源归档。空白为报告未提供，R²未设展示列。');
  sh.getRange('A7:L7').values=[heads];
  sh.getRange('A7:L7').format={fill:'#17365D',font:{bold:true,color:'#FFFFFF'},wrapText:true,rowHeight:36,horizontalAlignment:'center'};
  const data=all.map(r=>{
    const definition=r.device.startsWith('AD')?'ADC码峰峰值':r.device==='DA9726'?'无符号码幅设定值':'2×|16位有符号码幅|';
    const ds=String(r.calibrationDate).replace(/^(\d{4})(\d{2})(\d{2})$/,'$1-$2-$3');
    const date=ds?new Date(`${ds}T00:00:00Z`):null;
    const note=({'JG18 1.001 MHz; other interfaces approximately 1 MHz':'JG18为1.001 MHz；其余接口约1 MHz','approximately 1.525 kHz':'约1.525 kHz'})[r.frequencyNote]??r.frequencyNote??'';
    return [r.device,r.channel,stateNames[r.calibrationState]||r.calibrationState,defaults(r,all)?'是':'',number(r.slopeVPerCode),number(r.interceptV),number(r.calibrationFrequencyHz),number(r.pointCount),date,definition,`${r.sourceSection}\n表${r.sourceTable} · 行${r.sourceRow}`,note];
  });
  sh.getRange(`A8:L${end}`).values=data;
  sh.getRange(`A8:L${end}`).format={wrapText:true,rowHeight:42,borders:{preset:'all',style:'thin',color:'#DFE5EB'}};
  sh.getRange(`E8:H${end}`).format.horizontalAlignment='right';
  sh.getRange(`E8:F${end}`).setNumberFormat('0.000000000E+00');
  sh.getRange(`G8:H${end}`).setNumberFormat('#,##0');
  sh.getRange(`I8:I${end}`).setNumberFormat('yyyy-mm-dd');
  all.forEach((r,i)=>{
    const row=8+i;
    sh.getRange(`A${row}:L${row}`).format.fill=r.calibrationState==='after'?'#E5EFF9':r.calibrationState==='before'?'#FBE9E7':i%2?'#F5F7FA':'#FFFFFF';
    if(defaults(r,all))sh.getRange(`D${row}`).format.font.bold=true;
  });
  // Native filtering, page setup and repeated print headers are applied by
  // the small OOXML helper; it never rewrites cell values or styles.
  sh.freezePanes.freezeRows(7);
  const notes=[
    '码幅与拟合定义',
    'ADC：Vpp = k×CodePp + b，CodePp为ADC码峰峰值。',
    'DA9726：Vpp = k×C_set + b，C_set为无符号码幅设定值。',
    'DA766：Vpp = k×CodePp + b，CodePp = 2×|16位有符号码幅|。',
    '来源定位：表号按Word正文表格顺序计数，行号包含表头；日期仅填写可确认值。',
    '报告 SHA-256',all[0].sourceDocumentSha256,
    '归档依据：report_calibrations_20261004.csv；生成工具 exportCalibrationArchive.mjs。',
    '版本选择说明：current优先after，否则采用唯一记录；before/after要求对应记录存在。'
  ];
  notes.forEach((txt,i)=>band(end+2+i,txt));
  sh.getRange(`A${end+2}:L${end+2}`).format.font.bold=true;
  sh.getRange(`A${end+8}:L${end+8}`).format.font={name:'Consolas',size:10,color:'#526174'};
}
w.recalculate();
if(preview){
  await fs.mkdir(preview,{recursive:true});
  for(const name of ['鉴定件','电性加强件']){
    const blob=await w.render({sheetName:name,range:'A1:L21',scale:1.3,format:'png'});
    await fs.writeFile(path.join(preview,`${name}.png`),new Uint8Array(await blob.arrayBuffer()));
  }
  const inspect=await w.inspect({kind:'table',range:'鉴定件!A7:L10',include:'values',tableMaxRows:4,tableMaxCols:12,maxChars:2500});
  await fs.writeFile(path.join(preview,'artifact_inspect.ndjson'),inspect.ndjson);
}
const errors=await w.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#NUM!',options:{useRegex:true,maxResults:20},maxChars:1000});
console.log(errors.ndjson);
await fs.mkdir(path.dirname(out),{recursive:true});
await (await SpreadsheetFile.exportXlsx(w)).save(out);
const sidecar=out+'.inspect.ndjson';
try { await fs.rename(sidecar,path.join(preview??process.cwd(),path.basename(sidecar))); }
catch(error) { if(error.code!=='ENOENT')throw error; }
execFileSync(python,[path.join(here,'calibrationArchivePrint.py'),out],{stdio:'inherit'});
console.log(`Saved ${out}; 27 + 28 rows`);
