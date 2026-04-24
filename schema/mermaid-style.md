---
type: schema
created: 2026-04-15
updated: 2026-04-15
---

# Mermaid Style Guide

Style rules applied to every Mermaid diagram inside the wiki.

## init block

```
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'primaryColor': '#ede9fe',
    'primaryTextColor': '#1e1b4b',
    'primaryBorderColor': '#a78bfa',
    'lineColor': '#a78bfa',
    'fontSize': '13px',
    'actorTextColor': '#1e1b4b',
    'signalTextColor': '#64748b',
    'noteTextColor': '#64748b',
    'labelTextColor': '#64748b',
    'loopTextColor': '#64748b',
    'actorLineColor': '#c4b5fd',
    'signalColor': '#a78bfa',
    'messageLine0': '#a78bfa',
    'messageLine1': '#a78bfa',
    'labelBoxBorderColor': '#a78bfa',
    'labelBoxBkgColor': '#ede9fe'
  }
}}%%
```

**Why the extra variables (required for sequenceDiagram — harmless for other types):**

- `actorTextColor` stays dark navy on the lavender actor-box fill.
- `signalTextColor` / `noteTextColor` / `labelTextColor` / `loopTextColor` use slate-500 (`#64748b`), which stays readable on both light and dark editor backgrounds (mermaid's sequence canvas is transparent, so the ambient theme shows through). `loopTextColor` specifically colors the `loop XXX` label text — without it, mermaid falls back to `primaryTextColor` (dark navy) which is invisible on dark editor backgrounds.
- `actorLineColor` fixes the actor lifeline (vertical line), which otherwise falls back to a dark default and disappears on dark backgrounds. Uses a lighter violet (`#c4b5fd`) than the message arrows so the lifeline recedes visually and the horizontal messages stay in the foreground.
- `signalColor` / `messageLine0` / `messageLine1` color the message arrows between actors — `lineColor` alone does not cover them.
- `labelBoxBorderColor` / `labelBoxBkgColor` apply the same purple / lavender palette to `loop` / `par` / `alt` blocks so they match the rest of the diagram instead of defaulting to dark borders.

## classDef (node colors)

| Name   | fill       | stroke     | color      | Example use                          |
|--------|------------|------------|------------|--------------------------------------|
| blue   | `#dbeafe`  | `#60a5fa`  | `#1e3a5f`  | Entities, technical components       |
| yellow | `#fef3c7`  | `#fbbf24`  | `#78350f`  | Guides, modules                      |
| pink   | `#fce7f3`  | `#f472b6`  | `#831843`  | Infrastructure, core layer           |
| green  | `#d1fae5`  | `#34d399`  | `#064e3b`  | Data, databases                      |
| purple | `#ede9fe`  | `#a78bfa`  | `#1e1b4b`  | Reserved for an extra 5th+ group     |

All nodes: `stroke-width:2px,rx:12`

## subgraph style (group background)

| Name   | fill       | stroke     |
|--------|------------|------------|
| blue   | `#eff6ff`  | `#60a5fa`  |
| yellow | `#fffbeb`  | `#fbbf24`  |
| pink   | `#fdf2f8`  | `#f472b6`  |
| green  | `#ecfdf5`  | `#34d399`  |
| purple | `#f5f3ff`  | `#a78bfa`  |

All subgraphs: `stroke-width:2px,rx:16`

## Principles

- Nodes `rx:12`, subgraphs `rx:16` (rounded corners)
- The group background uses a lighter shade of the same hue as its nodes
- Default to the 4-color palette; add purple only when there are 5 or more groups
- Pick the diagram type that best fits the content (graph, sequence, classDiagram, ...)
