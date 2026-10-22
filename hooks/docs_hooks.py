"""MkDocs hooks for the Dox docs (see mkdocs.yml, `hooks:`).

- `reference/changelog.md` is made at build time from `packages/*/CHANGELOG.md`
  (3.x sections only). So the page is never out of date.
- `llms.txt` and `llms-full.txt` are written next to the site: the docs as
  plain Markdown, for AI tools. See https://llmstxt.org.
"""

import re
from pathlib import Path

from mkdocs.structure.files import File

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = ROOT / "packages"

# ---- changelog ---------------------------------------------------------


def _pub_name(package: Path) -> str:
    match = re.search(r"^name:\s*(\S+)", (package / "pubspec.yaml").read_text(), re.M)
    return match.group(1) if match else package.name


def _sections(text: str):
    """(version, body) for every `## version` part of a CHANGELOG."""
    for part in re.split(r"^## +", text, flags=re.M)[1:]:
        head, _, body = part.partition("\n")
        yield head.strip(), body.strip()


def _changelog() -> str:
    out = [
        "# Changelog",
        "",
        "What changed in each package, newest first. This page is made from the",
        "`CHANGELOG.md` files in the repo when the docs are built.",
        "",
    ]
    for package in sorted(PACKAGES.iterdir()):
        changelog = package / "CHANGELOG.md"
        if not changelog.is_file():
            continue
        kept = [
            (version, body)
            for version, body in _sections(changelog.read_text())
            if version.startswith("3.") or version.lower() == "unreleased"
        ]
        if not kept:
            continue
        out += [f"## {_pub_name(package)}", ""]
        for version, body in kept:
            out += [f"### {version}", "", body, ""]
    return "\n".join(out)


def on_files(files, config):
    files.append(File.generated(config, "reference/changelog.md", content=_changelog()))
    return files


# ---- llms.txt ----------------------------------------------------------

_MARKDOWN: dict = {}  # page src_uri -> markdown
_NAV_PAGES: list = []  # pages in nav order


def on_pre_build(config):
    _MARKDOWN.clear()
    _NAV_PAGES.clear()


def on_nav(nav, config, files):
    _NAV_PAGES.extend(nav.pages)
    return nav


def on_page_markdown(markdown, page, config, files):
    _MARKDOWN[page.file.src_uri] = markdown
    return markdown


def on_post_build(config):
    site = Path(config["site_dir"])
    # the docs of the newest version live under /latest/ (see mike in docs.yaml)
    base = config["site_url"].rstrip("/") + "/latest/"
    index = [
        "# Dox",
        "",
        "> Dox is a web backend framework for Dart, like Laravel: routing, an ORM,",
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
