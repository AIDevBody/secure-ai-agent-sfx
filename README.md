# Secure AI Agent SFX (Self-Extracting)

[![Sponsor on GitHub Sponsors](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-fafbfc?logo=github&labelColor=181717)](https://github.com/sponsors/aidevbody)
[![License: AAL](https://img.shields.io/badge/License-AAL-blue.svg)](#license)
![Platform](https://img.shields.io/badge/platform-macOS%20|%20Linux%20|%20Windows-informational)
![Script](https://img.shields.io/badge/script-bash-informational)

Package and **sanitize your code for AI assistants** — interactively select files, honor `.gitignore`, and **redact secrets via mapping** before sharing. The tool creates a **self‑extracting `.AI` script** that **rebuilds your project** later (and can restore original values when you provide the mapping).

---

## Table of contents

- [Overview](#overview)
- [Quick start](#quick-start)
- [Why do I need it?](#why-do-i-need-it)
- [Features](#features)
- [Usage](#usage)
- [Mapping example](#mapping-example)
- [Roadmap](#roadmap)
- [Tests](#tests)
- [FAQ](#faq)
- [Security model](#security-model)
- [Contributing & Support](#contributing--support)
- [Maintainer note](#maintainer-note)
- [License](#license)

## Overview

**Secure AI Agent SFX** helps developers safely share project code with AI assistants. It walks your repository, lets you choose exactly what to include, applies an optional mapping to replace sensitive tokens with placeholders, and builds a **standalone, self‑extracting `.AI` script** containing your selected files (Base64‑encoded). The generated agent can **reconstruct the project** and supports reversing the mapping to restore original values.

Use it when you want **gitignore‑aware packaging**, **secret redaction**, and **reproducible reconstruction** — across macOS, Linux, and Windows (Git Bash/WSL).

## Quick start

```bash
# From your project root
./CreateAgentInfoFile.sh -n "MyProject.AI" -m mapping-example.json

# Later, to reconstruct (with secrets restored via mapping):
chmod +x MyProject.AI   # macOS/Linux
./MyProject.AI --mapping mapping-example.json
```

See the full guide in [docs/USAGE.md](docs/USAGE.md).

## Why do I need it?

- **Protect secrets**: keep credentials and private values out of what you share.
- **Control scope**: include only what’s necessary; honor `.gitignore` by default.
- **Redact & restore**: swap sensitive strings for placeholders during packaging, then restore them during reconstruction when you provide the mapping.
- **Reproducibility**: a single `.AI` script can re‑create the files on another machine.

## Features

- **Interactive selection**: step through files and folders; include/exclude with confidence.
- **Mapping support**: JSON‑based substitutions; optional folder‑ignore list.
- **Dependency handling**: if you use mapping, the agent can prompt to install `jq` and `perl`.
- **`.gitignore` aware**: by default, ignored files are skipped; opt in if you need them.
- **Cross‑platform**: Bash on macOS, Linux, and Windows (Git Bash/WSL).

## Usage

```bash
./CreateAgentInfoFile.sh   [-n "AgentFileName.AI"]   [--include git] [--include gitignore]   [--mapping mapping-example.json]
```

**Options**

- `-n, --name` — output file name (default: `AgentYYYYMMDD-HHMMSS.AI`).
- `--include git` *(alias: `-ig`)* — include `.git/` metadata (still respects `.gitignore`).
- `--include gitignore` *(alias: `-igi`)* — include files normally excluded by `.gitignore`.
  - Use **both** `--include git --include gitignore` to include **everything**.
- `-m, --mapping` — path to a JSON mapping file defining substitutions and ignored folders.

> **Dependencies**: `jq` and `perl` are **only** required if you use `--mapping`. The agent will offer to install them where possible.

## Mapping example

**Minimal mapping file** (`mapping-example.json`):

```json
{
  "description": "Example mapping file for secure-ai-agent-sfx. Replace sensitive strings with placeholders and ignore selected folders.",
  "map": [
    { "scope": ".", "list": [
      {"AIDevBody GmbH": "Company Inc"},
      {"sk_live_": "STRIPE_KEY"}
    ]}
  ]
}
```

- `description`: Just to make sure what is it or which project this mapping belong.
- `map`: a list of `scope`d substitutions. Use `scope: "."` for whole‑project replacements, or a specific file path for targeted replacements.

## Roadmap

- CLI parity ports for **Python** and **PowerShell**.
- A **cross‑platform desktop app** (GUI) for non‑CLI workflows.
- A stable **API** for generating and consuming secure agent files.
- Comprehensive **unit tests** and CI workflows.

## Tests

A `test/` folder contains dummy files for unit tests. Run the script at the repo root and pass `--mapping` to exercise substitutions:

```bash
./CreateAgentInfoFile.sh -n "Test.AI" --mapping mapping-example.json
```

## FAQ

**Will my mapping file be embedded in the agent?**
No — by design, it is never packaged.

**Do I need `jq`/`perl` installed?**
Only if you use `--mapping`. The agent can prompt to install them when missing.

**Windows support?**
Yes — via Git Bash (MSYS2) or WSL. See troubleshooting in [docs/USAGE.md](docs/USAGE.md).

**Where does reconstruction happen?**
In the **current working directory** where you execute the `.AI` script.

## Security model

This tool improves **sharing hygiene**; it does **not**: (a) analyze code semantics to detect sensitive logic, (b) protect runtime secrets or network traffic, or (c) prevent malicious code execution. Keep mapping files private; avoid pasting real secrets into code; and review selections before packaging.

## Contributing & Support

Contributions, feature requests, and bug reports are welcome via GitHub issues. If this project helps you, please consider **[sponsoring](https://github.com/sponsors/aidevbody)** to support ongoing work (including Python/PowerShell ports and the future GUI).

## Maintainer note

I build this in my spare time and will respond as I’m able — thanks for your patience!

## License

Licensed under the **Attribution Assurance License (AAL)**. Redistribution requires an attribution banner per §2.

**Required attribution string:**
**“AIDevBody — Dr. Ali Jenabidehkordi — https://github.com/sponsors/aidevbody”**

See [LICENSE](LICENSE) for full terms.
