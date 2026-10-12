"""Audit literal UI copy; interpolated strings are separately covered by UI tests."""
import re, pathlib, json
root=pathlib.Path(__file__).resolve().parents[1]
p=root/'MadeRoom/UI'
known=set()
for f in p.glob('AppLanguage*.swift'):
    known.update(re.findall(r'"((?:[^"\\]|\\.)*)"\s*:',f.read_text()))
allowed=set('Dana Brooks|Elena Cruz|Jordyn Park|Lena Park|Lily Tran|Marcus Lee|Marisol Vega|Nora Lane|Priya Shah|Sam Rivera|Tessa Kim|Tessa Moore|Yuna Kim|English|Made Room|Made Room Studio|San Francisco, CA|EditorialAssets|Made-Room-data.json|nora lane maker|reading corner room space| weaving woven| copy'.split('|'))
missing={}
for f in p.glob('*.swift'):
    if f.name.startswith('AppLanguage'): continue
    for value in re.findall(r'"((?:[^"\\]|\\.)*)"',f.read_text()):
        if value in known or value in allowed or '\\(' in value: continue
        if re.fullmatch(r'\d+(h ago|d ago| min)',value): continue
        if value.startswith(('Use ','init(','Fatal','tab-')): continue
        if re.search('[A-Za-z]',value) and (' ' in value or (value[:1].isupper() and len(value)>4)):
            missing.setdefault(str(f.relative_to(root)),[]).append(value)
report={'translation_keys':len(known),'missing_literal_candidates':missing,'note':'Brand/person names and user-entered content remain unchanged. Dynamic text is validated in UI tests.'}
print(json.dumps(report,ensure_ascii=False,indent=2))
raise SystemExit(bool(missing))
