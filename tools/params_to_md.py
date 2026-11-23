#!/usr/bin/env python3
"""Строит markdown-таблицы параметров из data/*_params.gd (для заметок Obsidian «Технология/…»).

Запуск из корня проекта:  python3 tools/params_to_md.py data/wave_params.gd
Без аргументов — все наборы. Печатает в stdout.
Таблица собирается из @export_group, @export-строк и констант LABELS / UNITS / HINTS,
поэтому документация всегда совпадает с тем, что видно на панели.
"""
import re
import sys
import glob


def parse_dict(src, name):
    m = re.search(r"const " + name + r"\s*:?=\s*\{(.*?)\}", src, re.S)
    if not m:
        return {}
    return dict(re.findall(r'"(\w+)"\s*:\s*"((?:[^"\\]|\\.)*)"', m.group(1)))


def fmt_num(x):
    x = x.strip()
    try:
        v = float(x)
        return str(int(v)) if v == int(v) else ("%g" % v)
    except ValueError:
        return x


def table(path):
    src = open(path, encoding="utf-8").read()
    labels, units, hints = parse_dict(src, "LABELS"), parse_dict(src, "UNITS"), parse_dict(src, "HINTS")
    out = []
    for line in src.splitlines():
        g = re.match(r'@export_group\("(.*)"\)', line)
        if g:
            out.append(f"\n**{g.group(1)}**\n")
            out.append("| Параметр | Имя в коде | Ход ползунка | По умолч. | Пояснение |")
            out.append("|---|---|---|---|---|")
            continue
        m = re.match(r'@export(\w*)(?:\((.*)\))?\s+var\s+(\w+)\s*:\s*(\w+)\s*=\s*(.+)$', line)
        if not m:
            continue
        kind, args, name, typ, default = m.groups()
        unit = units.get(name, "")
        if kind == "_range":
            parts = [p.strip() for p in args.split(",")]
            rng = f"{fmt_num(parts[0])} … {fmt_num(parts[1])}"
        elif kind == "_enum":
            opts = re.findall(r'"([^"]*)"', args)
            rng = " / ".join(f"{i} {o}" for i, o in enumerate(opts))
        elif typ == "bool":
            rng = "вкл / выкл"
        elif typ == "Color":
            rng = "цвет"
        else:
            rng = ""
        d = default.strip()
        if typ == "bool":
            d = "вкл" if d == "true" else "выкл"
        elif typ in ("float", "int"):
            d = fmt_num(d)
        if unit and typ in ("float", "int"):
            d += " " + unit
        hint = hints.get(name, "").replace("|", "/")
        out.append(f"| {labels.get(name, name)} | `{name}` | {rng} | {d} | {hint} |")
    return "\n".join(out).strip() + "\n"


if __name__ == "__main__":
    files = sys.argv[1:] or sorted(glob.glob("data/*_params.gd"))
    for f in files:
        if len(files) > 1:
            print(f"\n## {f}\n")
        print(table(f))
