---
version: alpha
name: Orbit Cloudron package
description: Package hero and store slides; Orbit's own logo and web UI are unchanged
colors:
  primary: "#f2458f"
  secondary: "#742f4d"
  background: "#170c12"
  track: "#4b2537"
  on-surface: "#f7eef2"
  body: "#cdb6c1"
typography:
  body-md:
    fontFamily: system-ui
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
rounded:
  md: 12px
spacing:
  unit: 6px
---

# Orbit package artwork

## Overview

Dark, blocky artwork in the style of Orbit's own pixel logo. The package does
not re-theme or modify Orbit's web UI. Store slides pair short copy with real
screenshots of that unmodified UI.

## Colors and shapes

The pink (`#f2458f`) and plum (`#742f4d`) are Orbit's logo colours; the
background (`#170c12`) is close to the dark plum of Orbit's sidebar. Shapes are
square blocks on a grid, each with a plum shadow one block down and to the
right, as in the logo. No gradients, photographs, third-party marks or font
dependencies.

## Icon

`logo.png` is Orbit's logo: upstream `apps/web/public/logo.svg` at commit
`fe9dce7`, rendered at 208×208 and centred on a 256×256 transparent canvas so
it keeps clear of the edges at Cloudron launcher sizes.
`media/upstream/orbit-logo-1024.png` is upstream's
`marketing/brand/orbit-logo-1024.png` at the same commit, kept for reference.
Both belong to the Orbit project; they identify the app and are not package
artwork.

## Hero

`media/hero.png` is 1188×396 and has no text. Orbit's logo, drawn from the same
`logo.svg` geometry, sits at the left end of a dotted elliptical orbit. A task
card, a doc page and a chat bubble, made of 6px blocks in the logo's style, sit
on the orbit. A few faint blocks fill the background. The blocks and their
positions are fixed, so re-rendering gives the same image.

## Store slides

`media/listing-1-tasks.png` to `media/listing-4-mcp.png` are the first four
Cloudron `mediaLinks`, in that order, followed by the hero. Each is 2400×800: a
1200×400 layout (Cloudron's recommended 3:1) rendered at 2× for high-density
screens. The left third holds copy on the background colour: a pink uppercase
eyebrow ("Orbit on Cloudron"), a short pink rule, a 35px bold headline in
on-surface and a 16.5px body line in the body colour, all in the system UI
font. The right two thirds frame a crop of a real screenshot at 78% scale, with
a 12px top-left radius, a track-coloured border and a soft shadow, bleeding off
the right and bottom edges.

| Slide | Screenshot | Copy claims checked against |
|---|---|---|
| Tasks on boards | Board of the "Website relaunch" project | Sidebar lists (My tasks, This week, Overdue, Due soon) and the assignee badge |
| Team docs | A page in the General teamspace | Add icon and Add cover, the Private section, headings and lists on the page |
| Team chat built in | The #general channel | Channels, Threads and Direct messages in the sidebar; attach, emoji and mention buttons |
| Connect AI tools | Settings → Agentic | The page's Claude, Codex and Grok commands and its API token note |

The screenshots show Orbit 0.2.1 (commit `fe9dce7`) running in this package's
image on a disposable local install, with a made-up workspace ("Acme Studio",
user "Alex Morgan"). The Settings → Agentic page shows the server address, so
it was taken on a copy of that install whose public origin was set to
`https://orbit.example.com`. They were reviewed before use: no credentials,
links, real people, private hostnames or private data are visible.

## Provenance

The hero and slides were made on 2026-11-06 by AI DevOps. Screenshots were
taken with headless Chromium (Playwright) at 1600×1000 CSS pixels and 2× scale.
The hero is an SVG drawn in code and the slides an HTML layout, both rendered
by the same browser. No generative-image service was used. The Orbit
interface shown is the upstream project's Apache-2.0 work, and the logo is
Orbit's; the hero's composition, the slide layout and the copy are this
package's, under the repository's MIT license.

To refresh the slides after a visible upstream UI change, recapture from a
disposable install, keep this layout and order, repeat the privacy and claims
review, and pin the new `mediaLinks` to the commit that adds the images.
