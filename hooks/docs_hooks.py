"""MkDocs hooks for the Dox docs (see mkdocs.yml, `hooks:`).

- `llms.txt` and `llms-full.txt` are written next to the site: the docs as
  plain Markdown, for AI tools. See https://llmstxt.org.
- Every page gets a meta description from its first paragraph.

The blog (blog/mkdocs.yml) uses this file too. It gets only the meta
description, not the llms files.
"""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def _is_docs(config) -> bool:
    """False for the blog build, which has its own docs_dir."""
    return Path(config["docs_dir"]).resolve() == ROOT / "docs"

# ---- llms.txt ----------------------------------------------------------

_MARKDOWN: dict = {}  # page src_uri -> markdown
_NAV_PAGES: list = []  # pages in nav order


def on_pre_build(config):
    _MARKDOWN.clear()
    _NAV_PAGES.clear()


def on_nav(nav, config, files):
    _NAV_PAGES.extend(nav.pages)
    return nav


def _summary(markdown: str) -> str:
    """The first paragraph after the H1, as plain text, at most ~160 chars."""
    lines = markdown.split("\n")
    start = next((i for i, l in enumerate(lines) if l.startswith("# ")), -1) + 1
    para, in_code = [], False
    for line in lines[start:]:
        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        text = line.strip()
        if not text:
            if para:
                break
            continue
        if text[0] in "<#!|-*>=" or text[0].isdigit() and ". " in text[:4]:
            if para:
                break
            continue
        para.append(text)
    text = " ".join(para)
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)  # links, images
    text = re.sub(r"[`*]", "", text)
    text = re.sub(r"\{[^}]*\}", "", text)  # attr lists
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > 160:
        text = text[:157].rsplit(" ", 1)[0].rstrip(",.:;") + "..."
    return text


def on_page_markdown(markdown, page, config, files):
    _MARKDOWN[page.file.src_uri] = markdown
    if not page.meta.get("description"):
        summary = _summary(markdown)
        if summary:
            page.meta["description"] = summary
    return markdown


def on_post_build(config):
    if not _is_docs(config):
        return
    site = Path(config["site_dir"])
    # mike sets site_url to https://dartondox.dev/latest (no last slash)
    base = config["site_url"].rstrip("/") + "/"
    index = [
        "# Dox",
        "",
        "> Dox is a web backend framework for Dart: routing, an ORM,",
        "> migrations, typed validation, auth and a CLI. It runs on a Rust HTTP",
        "> server, one isolate per CPU core, and builds to one native binary.",
        "",
        "The full docs as one file: " + base + "llms-full.txt",
        "",
        "## Pages",
        "",
    ]
    full = ["# Dox documentation", "", "Source: " + base, ""]
    for page in _NAV_PAGES:
        markdown = _MARKDOWN.get(page.file.src_uri)
        if markdown is None:
            continue
        link = base + page.url
        index.append(f"- [{page.title}]({link})")
        full += ["", "---", "", f"# {page.title}", "", f"Source: {link}", "", markdown]
    (site / "llms.txt").write_text("\n".join(index) + "\n")
    (site / "llms-full.txt").write_text("\n".join(full) + "\n")
