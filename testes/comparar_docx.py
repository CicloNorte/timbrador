"""Compara dois .docx parte a parte (XML canonizado; mídia byte a byte). Ignora só as datas de criação/modificação."""
import sys, zipfile, re, xml.etree.ElementTree as ET
a, b = sys.argv[1], sys.argv[2]
za, zb = zipfile.ZipFile(a), zipfile.ZipFile(b)
na, nb = set(za.namelist()), set(zb.namelist())
dif = 0
for n in sorted(na ^ nb): print("  só em", "página" if n in na else "gerador", ":", n); dif += 1
for n in sorted(na & nb):
    x, y = za.read(n), zb.read(n)
    if n.endswith((".xml", ".rels")):
        cx, cy = (ET.canonicalize(v.decode("utf8")) for v in (x, y))
        if n == "docProps/core.xml":
            cx, cy = (re.sub(r"<dcterms:(created|modified)[^>]*>[^<]*", "", c) for c in (cx, cy))
        if cx != cy:
            dif += 1
            i = next(k for k in range(min(len(cx), len(cy))) if cx[k] != cy[k]) if cx[:min(len(cx),len(cy))] != cy[:min(len(cx),len(cy))] else min(len(cx), len(cy))
            print(f"  DIFERE {n} (pos {i}):\n    página : …{cx[max(0,i-150):i+150]}…\n    gerador: …{cy[max(0,i-150):i+150]}…")
    elif x != y: print("  DIFERE (binário)", n); dif += 1
print(f"{'IGUAIS' if not dif else str(dif) + ' diferença(s)'}: {len(na & nb)} partes comparadas")
sys.exit(1 if dif else 0)
