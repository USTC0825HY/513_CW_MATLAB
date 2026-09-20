function writeSummaryXlsx(filePath, sheets)
%WRITESUMMARYXLSX Write compact numeric XLSX sheets without Excel or toolboxes.
%   SHEETS has name, title, note, headers and data fields. Numeric cells stay
%   numeric; nonfinite values are blank. Detailed evidence remains in CSV/MAT.
parent = fileparts(filePath);
stage = tempname(parent); mkdir(stage);
cleanup = onCleanup(@() removeStage(stage)); %#ok<NASGU>
mkdir(fullfile(stage, '_rels')); mkdir(fullfile(stage, 'xl'));
mkdir(fullfile(stage, 'xl', '_rels')); mkdir(fullfile(stage, 'xl', 'worksheets'));
types = ['<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' ...
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' ...
    '<Default Extension="xml" ContentType="application/xml"/>' ...
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' ...
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'];
book = ['<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' ...
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'];
rels = '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">';
files = {'[Content_Types].xml','_rels/.rels','xl/workbook.xml','xl/styles.xml','xl/_rels/workbook.xml.rels'};
for k = 1:numel(sheets)
    name = regexprep(char(sheets(k).name), '[\\/:?*\[\]]', '_');
    name = name(1:min(31,numel(name)));
    book = [book sprintf('<sheet name="%s" sheetId="%d" r:id="rId%d"/>', esc(name), k, k)]; %#ok<AGROW>
    rels = [rels sprintf('<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%d.xml"/>', k, k)]; %#ok<AGROW>
    types = [types sprintf('<Override PartName="/xl/worksheets/sheet%d.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>', k)]; %#ok<AGROW>
    file = sprintf('xl/worksheets/sheet%d.xml', k);
    writeUtf8(fullfile(stage,file), sheetXml(sheets(k)));
    files{end+1} = file; %#ok<AGROW>
end
rels = [rels '<Relationship Id="styles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>'];
writeUtf8(fullfile(stage,'[Content_Types].xml'), [types '</Types>']);
writeUtf8(fullfile(stage,'xl','workbook.xml'), [book '</sheets></workbook>']);
writeUtf8(fullfile(stage,'xl','_rels','workbook.xml.rels'), rels);
writeUtf8(fullfile(stage,'_rels','.rels'), ['<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' ...
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>']);
styles = ['<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' ...
    '<numFmts count="2"><numFmt numFmtId="164" formatCode="0.000000E+00"/><numFmt numFmtId="165" formatCode="0.########"/></numFmts>' ...
    '<fonts count="2"><font><sz val="11"/><name val="Microsoft YaHei"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Microsoft YaHei"/></font></fonts>' ...
    '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF24577A"/><bgColor indexed="64"/></patternFill></fill></fills>' ...
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' ...
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' ...
    '<cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"><alignment vertical="center" wrapText="1"/></xf>' ...
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0"><alignment vertical="center" wrapText="1"/></xf>' ...
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' ...
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>' ...
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>'];
writeUtf8(fullfile(stage,'xl','styles.xml'), styles);
zipFile = [tempname(parent) '.zip'];
zip(zipFile, files, stage);
movefile(zipFile, filePath);
end

function xml = sheetXml(sheet)
n = numel(sheet.headers); last = columnName(n);
xml = ['<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' ...
    '<sheetViews><sheetView workbookViewId="0" showGridLines="0"><pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>' ...
    '<sheetFormatPr defaultRowHeight="24"/><cols>'];
for c = 1:n
    width = 22; if c==1, width=25; end
    if contains(sheet.headers{c}, '备注') || contains(sheet.headers{c}, '状态'), width=38; end
    xml = [xml sprintf('<col min="%d" max="%d" width="%d" customWidth="1"/>',c,c,width)]; %#ok<AGROW>
end
xml = [xml '</cols><sheetData>' rowXml(1,{sheet.title},false) rowXml(2,{sheet.note},false) rowXml(4,sheet.headers,true)];
for r=1:size(sheet.data,1)
    xml = [xml rowXml(r+4,sheet.data(r,:),false)]; %#ok<AGROW>
end
xml = [xml sprintf('</sheetData><autoFilter ref="A4:%s%d"/><mergeCells count="2"><mergeCell ref="A1:%s1"/><mergeCell ref="A2:%s2"/></mergeCells>',last,max(4,4+size(sheet.data,1)),last,last) ...
    '<pageSetup orientation="landscape" paperSize="9" fitToWidth="1" fitToHeight="0"/></worksheet>'];
end

function xml = rowXml(row, values, header)
height=30; if row==2, height=48; elseif header, height=42; end
xml=sprintf('<row r="%d" ht="%d" customHeight="1">',row,height);
for c=1:numel(values)
    value=values{c}; ref=sprintf('%s%d',columnName(c),row);
    if isempty(value), continue; end
    if (isnumeric(value) || islogical(value)) && isscalar(value)
        if ~isfinite(value), continue; end
        style=2;
        if value~=0 && (abs(value)<0.01 || abs(value)>=1e7), style=3; end
        xml=[xml sprintf('<c r="%s" s="%d"><v>%.17g</v></c>',ref,style,double(value))]; %#ok<AGROW>
    else
        if isstring(value) && ismissing(value), continue; end
        xml=[xml sprintf('<c r="%s" s="%d" t="inlineStr"><is><t xml:space="preserve">%s</t></is></c>',ref,double(header),esc(char(string(value))))]; %#ok<AGROW>
    end
end
xml=[xml '</row>'];
end

function value=esc(value)
value=strrep(value,'&','&amp;'); value=strrep(value,'<','&lt;');
value=strrep(value,'>','&gt;'); value=strrep(value,'"','&quot;');
value=regexprep(value,'[\x00-\x08\x0B\x0C\x0E-\x1F]','');
end
function name=columnName(index)
name='';
while index>0
    digit=mod(index-1,26); name=[char(65+digit) name]; %#ok<AGROW>
    index=floor((index-1)/26);
end
end
function writeUtf8(file,value)
fid=fopen(file,'w','n','UTF-8');
if fid<0, error('converter:report:XlsxWriteFailed','Cannot write %s',file); end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',value);
end
function removeStage(stage)
if isfolder(stage), rmdir(stage,'s'); end
end
