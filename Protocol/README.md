# Modular LaTeX Protocol Template

This repository contains a modular protocol template for writing lab reports or protocol documents in LaTeX. The project is organized so that each assignment is kept in a separate file and included from a single main document.

## Repository layout

```text
Protocol/
  main.tex
  protocolstyle.sty
  assignments/
    assignment01.tex
    assignment02.tex
```

- `main.tex` — project entry point and document wrapper.
- `protocolstyle.sty` — shared style definitions and formatting settings.
- `assignments/` — folder containing one subfolder per assignment.

## How to add a new assignment

1. Create a new assignment folder inside `assignments/`.

```text
assignments/assignment03/
```

2. Add files for each section inside the new folder. For example:

```text
assignments/assignment03/introduction.tex
assignments/assignment03/methods.tex
assignments/assignment03/results.tex
assignments/assignment03/conclusion.tex
```

3. Create a master file for the assignment that assembles the section files. For example:

```latex
% assignments/assignment03/assignment03.tex
\chapter{Title of the Assignment}\label{sec:assignment03}
\subfile{assignments/assignment03/introduction}
\subfile{assignments/assignment03/methods}
\subfile{assignments/assignment03/results}
\subfile{assignments/assignment03/conclusion}
```

4. Include the assignment master file in `main.tex`.

```latex
\input{assignments/assignment03/assignment03}
```

5. Write the content for each section file separately.

```latex
% assignments/assignment03/introduction.tex
\subsection{Introduction}
Your introduction text here.
```

## Editing guidelines

- Keep `main.tex` limited to document metadata, title page, table of contents, and `\subfile{...}` includes.
- Put assignment-specific text and figures inside the corresponding file in `assignments/`.
- Use consistent section labels like `sec:assignment03` for cross-references.

## Compiling the document

Compile `main.tex` with your preferred LaTeX toolchain, for example:

```bash
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```

Or use an editor workflow that supports `subfiles` and automatic compilation.

## Notes

- `protocolstyle.sty` contains the shared formatting rules and should be loaded from `main.tex`.
- If you add new packages or custom commands, prefer placing them in `protocolstyle.sty` so they apply consistently.
