# Markdown to DOCX Tools

This directory contains two small Markdown-to-Word converters.

## Python Command-Line Version

Install the dependency:

```powershell
python -m pip install python-docx
```

Convert a document:

```powershell
python tools/md_to_docx.py docs/engineering_changes_2026-06-18.md
```

Specify an output file:

```powershell
python tools/md_to_docx.py docs/engineering_changes_2026-06-18.md docs/engineering_changes_2026-06-18.docx
```

Supported features:

- Headings
- Paragraphs
- Unordered and ordered lists
- Quotes
- Fenced code blocks
- Simple pipe tables
- Bold, italic, inline code, and link text

## Browser Version

Open:

```text
tools/md_to_docx.html
```

Choose an `.md` file or paste Markdown, then click `Download DOCX`.

The browser version loads the `docx` library from a CDN and therefore requires
an internet connection. Use the Python version in an offline environment.
