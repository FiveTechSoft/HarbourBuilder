"""Extract LoginHtml / DashboardHtml TEXT blocks from FWH login.prg into www/."""
from pathlib import Path

src = Path(r"C:\fwteam\samples\DesktopWeb\login.prg")
dst = Path(r"C:\harbourbuilder\samples\projects\FiveTech_ERP\www")
dst.mkdir(parents=True, exist_ok=True)

lines = src.read_text(encoding="utf-8", errors="replace").splitlines()

def extract_text_into(start_func_name: str) -> str:
    # find FUNCTION line
    start = None
    for i, ln in enumerate(lines):
        if f"FUNCTION {start_func_name}" in ln and "STATIC" in ln:
            start = i
            break
    if start is None:
        raise SystemExit(f"function {start_func_name} not found")
    # find TEXT INTO
    ti = None
    for i in range(start, min(start + 30, len(lines))):
        if lines[i].strip().upper().startswith("TEXT INTO"):
            ti = i
            break
    if ti is None:
        raise SystemExit(f"TEXT INTO not found for {start_func_name}")
    # content after TEXT INTO until ENDTEXT
    body = []
    for i in range(ti + 1, len(lines)):
        if lines[i].strip().upper() == "ENDTEXT":
            break
        body.append(lines[i])
    return "\n".join(body) + "\n"

login = extract_text_into("LoginHtml")
dash = extract_text_into("DashboardHtml")

(dst / "login.html").write_text(login, encoding="utf-8")
print("login.html", len(login), "bytes", (dst / "login.html").stat().st_size)

# FiveTech_ERP maintains its own dashboard UI (status bar, collapsible menu,
# pagination, …). Never overwrite www/dashboard.html from FWH TEXT blocks.
# Keep a reference copy only for diffs / re-import.
ref = dst / "dashboard.fwh-ref.html"
ref.write_text(dash, encoding="utf-8")
print("dashboard.fwh-ref.html", len(dash), "bytes (reference only)")
dash_path = dst / "dashboard.html"
if dash_path.exists():
    print("dashboard.html PRESERVED (not overwritten):", dash_path.stat().st_size, "bytes")
else:
    # First bootstrap only — seed from FWH when missing
    dash_path.write_text(dash, encoding="utf-8")
    print("dashboard.html seeded from FWH:", dash_path.stat().st_size, "bytes")
print("dashboard.html", len(dash), "bytes", (dst / "dashboard.html").stat().st_size)
# sample placeholders
for ph in ["__USER__", "__APP_JSON__", "__MODULES_JSON__", "__APPTDATA__", "fetch("]:
    print(ph, "in dash", ph in dash)
