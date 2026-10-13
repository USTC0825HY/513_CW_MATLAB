"""Add print/filter settings unsupported by the artifact quick API.

Only worksheet print metadata and workbook defined names are edited.
Cell values, style references and calibration records are preserved.
"""
import sys,zipfile,os,tempfile
from xml.etree import ElementTree as ET
path=sys.argv[1]
ns='http://schemas.openxmlformats.org/spreadsheetml/2006/main'
ET.register_namespace('',ns)
q=lambda name:'{'+ns+'}'+name
with zipfile.ZipFile(path) as z:parts={n:z.read(n) for n in z.namelist()}
book=ET.fromstring(parts['xl/workbook.xml'])
names=book.find(q('definedNames'))
if names is None:names=ET.SubElement(book,q('definedNames'))
for idx,(name,n) in enumerate([('鉴定件',27),('电性加强件',28)]):
    part=f'xl/worksheets/sheet{idx+1}.xml'
    root=ET.fromstring(parts[part]);end=7+n;last=end+10
    # Insert elements in the SpreadsheetML schema sequence.
    order=['sheetPr','dimension','sheetViews','sheetFormatPr','cols','sheetData','sheetCalcPr','sheetProtection','protectedRanges','scenarios','autoFilter','sortState','dataConsolidate','customSheetViews','mergeCells','phoneticPr','conditionalFormatting','dataValidations','hyperlinks','printOptions','pageMargins','pageSetup','headerFooter','rowBreaks','colBreaks','customProperties','cellWatches','ignoredErrors','smartTags','drawing','legacyDrawing','legacyDrawingHF','picture','oleObjects','controls','webPublishItems','tableParts','extLst']
    def put(tag,attrs):
        el=root.find(q(tag))
        if el is None:
            el=ET.Element(q(tag));pos=next((i for i,c in enumerate(root) if c.tag.split('}')[-1] in order and order.index(c.tag.split('}')[-1])>order.index(tag)),len(root));root.insert(pos,el)
        el.attrib.update(attrs);return el
    put('autoFilter',{'ref':f'A7:L{end}'})
    pr=put('sheetPr',{});ps=pr.find(q('pageSetUpPr'))
    if ps is None:ps=ET.SubElement(pr,q('pageSetUpPr'))
    ps.set('fitToPage','1')
    put('printOptions',{'horizontalCentered':'1'})
    put('pageMargins',{'left':'0.25','right':'0.25','top':'0.35','bottom':'0.35','header':'0.15','footer':'0.15'})
    put('pageSetup',{'paperSize':'8','orientation':'landscape','fitToWidth':'1','fitToHeight':'0'})
    hf=put('headerFooter',{});footer=ET.SubElement(hf,q('oddFooter'));footer.text='&L'+name+'刻度归档&R第 &P 页 / 共 &N 页'
    for key,value in [('_xlnm.Print_Area',f"'{name}'!$A$1:$L${last}"),('_xlnm.Print_Titles',f"'{name}'!$7:$7")]:
        for old in list(names):
            if old.get('name')==key and old.get('localSheetId')==str(idx):names.remove(old)
        ET.SubElement(names,q('definedName'),{'name':key,'localSheetId':str(idx)}).text=value
    parts[part]=ET.tostring(root,encoding='utf-8',xml_declaration=True)
parts['xl/workbook.xml']=ET.tostring(book,encoding='utf-8',xml_declaration=True)
fd,tmp=tempfile.mkstemp(suffix='.xlsx',dir=os.path.dirname(os.path.abspath(path)));os.close(fd)
try:
    with zipfile.ZipFile(tmp,'w',zipfile.ZIP_DEFLATED) as z:
        for n,data in parts.items():z.writestr(n,data)
    os.replace(tmp,path)
finally:
    if os.path.exists(tmp):os.unlink(tmp)
