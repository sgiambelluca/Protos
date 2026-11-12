#!/usr/bin/env python3
"""Convierte un apunte .md en un PDF con el estilo de la "Hoja de Referencia".

Uso (en la Mac, necesita Google Chrome):
    python3 scripts/md-a-pdf.py apuntes/21-hoja-de-comandos.md referencias/hoja-de-comandos.pdf
    python3 scripts/md-a-pdf.py entrada.md salida.pdf --html     # además deja el .html al lado

Entiende el Markdown que usan los apuntes: títulos #, ##, ###; párrafos; listas con - y 1.;
citas con >; tablas con |; bloques ``` (los comentarios #, ; o // salen en gris); y `código`,
**negrita**, *cursiva* y [links](url) dentro del texto. Las líneas que empiezan con <p o <div
pasan tal cual (así se arma la línea de "chips" de debajo del título).
"""
import html
import pathlib
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

CSS = r"""
:root {
  --ink: #1f1e1c; --muted: #6f6d66; --faint: #9a978f;
  --code-bg: #f6f5f1; --inline-bg: #efede6; --rule: #e4e1d8; --accent: #b4532a;
}
@page {
  size: A4;
  margin: 19mm 17mm 17mm 17mm;
  @top-left { content: "__RUNNING__"; font: 7.2pt -apple-system, "Helvetica Neue", sans-serif; color: #9a978f; }
  @bottom-right { content: "Página " counter(page) " de " counter(pages); font: 7.2pt -apple-system, "Helvetica Neue", sans-serif; color: #9a978f; }
}
* { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body {
  margin: 0; color: var(--ink); background: #fff;
  font: 9.6pt/1.45 -apple-system, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
}
h1, h2, h3 { font-family: "Tiempos Text", ui-serif, "New York", Charter, Georgia, serif; font-weight: 400; color: var(--ink); break-after: avoid; }
h1 { font-size: 25pt; line-height: 1.12; margin: 0 0 8pt; letter-spacing: -0.01em; }
h2 { font-size: 16pt; margin: 20pt 0 6pt; padding-top: 2pt; }
h3 { font-family: -apple-system, "SF Pro Text", "Helvetica Neue", sans-serif; font-weight: 650; font-size: 10pt; margin: 12pt 0 4pt; }
p { margin: 4pt 0 6pt; }
.meta { margin: 0 0 10pt; color: var(--faint); }
.meta span { display: inline-block; background: var(--inline-bg); color: var(--muted); border-radius: 4px; padding: 1pt 6pt; font-size: 8.4pt; }
strong { font-weight: 650; }
a { color: inherit; }
code, pre { font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace; }
code { font-size: 8.4pt; background: var(--inline-bg); border-radius: 3px; padding: 0.5pt 3pt; overflow-wrap: anywhere; }
pre {
  background: var(--code-bg); border-radius: 7px; padding: 8pt 10pt; margin: 5pt 0 8pt;
  font-size: 7.6pt; line-height: 1.42; white-space: pre-wrap; overflow-wrap: anywhere;
  break-inside: avoid;
}
pre code { background: none; padding: 0; font-size: inherit; border-radius: 0; }
pre .c { color: #8b887f; }
ul, ol { margin: 4pt 0 7pt; padding-left: 16pt; }
li { margin: 1.5pt 0; }
blockquote { margin: 6pt 0 8pt; padding: 5pt 10pt; border-left: 3px solid var(--accent); background: #fbf7f2; border-radius: 0 6px 6px 0; }
blockquote p { margin: 0; }
table { width: 100%; border-collapse: collapse; margin: 5pt 0 9pt; font-size: 8.6pt; line-height: 1.35; }
th, td { text-align: left; vertical-align: top; padding: 3.2pt 6pt; border-bottom: 1px solid var(--rule); }
th { font-weight: 650; color: var(--muted); font-size: 7.8pt; text-transform: uppercase; letter-spacing: 0.04em; border-bottom: 1.4px solid #cfcbbf; }
tr { break-inside: avoid; }
td code { font-size: 7.9pt; }
th code { text-transform: none; letter-spacing: 0; }
h2 + *, h3 + * { break-before: avoid; }
"""


def inline(text: str) -> str:
    codes: list[str] = []

    def keep_code(m: re.Match) -> str:
        codes.append("<code>" + html.escape(m.group(2), quote=False) + "</code>")
        return f"\x00{len(codes) - 1}\x00"

    text = re.sub(r"(`+)(.+?)\1", keep_code, text)
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w*])\*(?=\S)(.+?)(?<=\S)\*(?![\w*])", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], text)


def code_block(lines: list[str], lang: str) -> str:
    marker = {"dns": r";", "c": r"//"}.get(lang, r"#")
    comment = re.compile(r"(^|\s)(" + re.escape(marker) + r".*)$")
    out = []
    for line in lines:
        m = comment.search(line)
        if m:
            start = m.start(2)
            out.append(html.escape(line[:start], quote=False)
                       + '<span class="c">' + html.escape(line[start:], quote=False) + "</span>")
        else:
            out.append(html.escape(line, quote=False))
    return f'<pre class="lang-{lang or "text"}"><code>' + "\n".join(out) + "</code></pre>"


def split_row(row: str) -> list[str]:
    row = row.strip().strip("|")
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", row)]


def table(rows: list[str]) -> str:
    head = split_row(rows[0])
    body = [split_row(r) for r in rows[2:]]
    t = ["<table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head) + "</tr></thead><tbody>"]
    for r in body:
        t.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>")
    return "".join(t) + "</tbody></table>"


ITEM = re.compile(r"^(\d+\.|-)\s+")
BLOCK_START = re.compile(r"^(```|#{1,6}\s|\||-\s|\d+\.\s|>|<(p|div)\b)")


def convert(md: str) -> tuple[str, str]:
    lines = md.split("\n")
    out: list[str] = []
    title = "Apunte"
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("```"):
            lang = line[3:].strip()
            buf = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1
            out.append(code_block(buf, lang))
        elif re.match(r"#{1,6}\s", line):
            level = len(line) - len(line.lstrip("#"))
            text = line[level:].strip()
            if level == 1:
                title = text
            out.append(f"<h{level}>{inline(text)}</h{level}>")
            i += 1
        elif re.match(r"<(p|div)\b", line):
            out.append(line)
            i += 1
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(lines[i])
                i += 1
            out.append(table(rows))
        elif ITEM.match(line):
            tag = "ul" if line.startswith("-") else "ol"
            items: list[str] = []
            while i < len(lines) and (ITEM.match(lines[i]) or (items and lines[i].startswith("  ") and lines[i].strip())):
                if ITEM.match(lines[i]):
                    items.append(ITEM.sub("", lines[i]))
                else:
                    items[-1] += " " + lines[i].strip()
                i += 1
            out.append(f"<{tag}>" + "".join(f"<li>{inline(x)}</li>" for x in items) + f"</{tag}>")
        elif line.startswith(">"):
            buf = []
            while i < len(lines) and lines[i].startswith(">"):
                buf.append(lines[i][1:].strip())
                i += 1
            out.append(f"<blockquote><p>{inline(' '.join(buf))}</p></blockquote>")
        elif not line.strip():
            i += 1
        else:
            buf = []
            while i < len(lines) and lines[i].strip() and not (buf and BLOCK_START.match(lines[i])):
                buf.append(lines[i].strip())
                i += 1
            out.append(f"<p>{inline(' '.join(buf))}</p>")
    return title, "\n".join(out)


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        sys.exit(__doc__)
    src, dst = pathlib.Path(args[0]).resolve(), pathlib.Path(args[1]).resolve()
    title, body = convert(src.read_text(encoding="utf-8"))
    running = title.replace("\\", "\\\\").replace('"', '\\"')
    page = (
        "<!doctype html>\n<html lang=\"es\"><head><meta charset=\"utf-8\">"
        f"<title>{html.escape(title)}</title><style>{CSS.replace('__RUNNING__', running)}</style>"
        f"</head><body>\n{body}\n</body></html>\n"
    )
    with tempfile.TemporaryDirectory() as tmp:
        html_path = pathlib.Path(tmp) / "hoja.html"
        html_path.write_text(page, encoding="utf-8")
        if "--html" in sys.argv:
            dst.with_suffix(".html").write_text(page, encoding="utf-8")
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
             f"--user-data-dir={tmp}/perfil", f"--print-to-pdf={dst}", html_path.as_uri()],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    print(f"PDF: {dst}")


if __name__ == "__main__":
    main()
