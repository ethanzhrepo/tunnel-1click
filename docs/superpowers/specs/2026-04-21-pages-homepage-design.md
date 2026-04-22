# Pages Homepage Design

## Goal

Replace the current GitHub Pages default README-style homepage with a dedicated landing page for `0x99.link`.

The homepage should:

- lead with the installer command
- present the project as a practical Xray REALITY deployment tool
- keep the README as the full technical document
- preserve the existing Pages distribution files:
  - `install.sh`
  - `update.sh`
  - `tunnel-1click-main.tar.gz`

## Chosen Direction

The approved direction is:

- layout: command-first landing page
- language: English
- visual style: "Field Manual"

This means the homepage should feel practical and slightly tactile rather than generic docs or glossy marketing.

## Content Structure

The root `index.html` should contain four sections.

### 1. Hero

The first screen should include:

- project label
- short headline
- short supporting sentence
- primary install command in a copy-friendly code block
- secondary actions linking to:
  - update command
  - README
  - GitHub repository

The hero should optimize for one immediate action: copy the install command.

### 2. What It Sets Up

A compact three-card section describing the installer outcome:

- pinned Xray release
- REALITY target and connection output
- `systemd` service and logs

This section should help users understand the script without reading the README first.

### 3. Quick Use

A practical section for common operator tasks:

- install command
- update command
- service control commands
- log inspection commands

This content should match the current README and generated connection output.

### 4. Docs And Source

A final section with links to:

- `README.md`
- GitHub repository
- `install.sh`
- `update.sh`

This section keeps the homepage lightweight while preserving discoverability of the full technical documentation.

## Visual Design

The page should follow a "Field Manual" style:

- warm paper-like background tones
- dark terminal-style command blocks
- compact spacing and clear hierarchy
- strong typography without looking like a generic docs theme

The design should remain light-mode-first and avoid a dashboard or console aesthetic.

## Implementation Notes

- Add a root `index.html` for GitHub Pages.
- Keep the page fully static with inline CSS and minimal JavaScript.
- Do not convert the site into a multi-page app or introduce a frontend build step.
- Do not replace or restructure `README.md`.
- Keep the generated archive workflow and Pages distribution behavior unchanged.

## Testing

Add a lightweight test that verifies:

- `index.html` exists
- it includes the main install command
- it links to `README.md`
- it links to `install.sh` and `update.sh`

Manual verification after push should confirm that `https://0x99.link/` opens the landing page instead of the README rendering.
