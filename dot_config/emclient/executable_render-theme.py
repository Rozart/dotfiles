#!/usr/bin/env python3
"""Render an eM Client theme from a shared palette.

usage: render-theme.py <palette.css> <out.emtheme> <light|dark>

Called by theme.fish. Polarity is an argument rather than a lookup table here
because theme.fish already carries $dark index-matched to $slugs, and a second
copy of that list is precisely the drift its own header comment warns about.

The rendered theme is always named "System" so eM Client keeps one stable theme
identity in its picker and only the colours underneath it change -- the same
trick ~/.claude/themes/system.json and btop's active.theme use.
"""
import os
import re
import sys

TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "theme.emtheme.template")


def main(palette, out, polarity):
    if polarity not in ("light", "dark"):
        sys.exit("polarity must be light or dark, got %r" % polarity)

    with open(palette, encoding="utf-8") as fh:
        roles = dict(re.findall(r"--th-([a-z0-9-]+):\s*(#[0-9a-fA-F]{6})", fh.read()))

    dark = polarity == "dark"
    values = dict(roles)
    values["name"] = "System"
    values["author"] = os.path.basename(palette).removesuffix(".css")
    values["isdark"] = str(dark)
    # Toolbar and menu glyphs are monochrome and get inverted to sit on a dark
    # surface. Left True on a light palette, the whole toolbar is white on white.
    values["invert"] = str(dark)

    with open(TEMPLATE, encoding="utf-8") as fh:
        text = fh.read()

    missing = sorted(set(re.findall(r"\{\{([a-z0-9-]+)\}\}", text)) - set(values))
    if missing:
        sys.exit("%s is missing role(s): %s" % (palette, ", ".join(missing)))

    text = re.sub(r"\{\{([a-z0-9-]+)\}\}", lambda m: values[m.group(1)], text)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(text)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
