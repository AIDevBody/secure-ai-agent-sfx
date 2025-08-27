# Secure AI Agent SFX

<!-- Badges -->
[![Sponsor on GitHub Sponsors](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-fafbfc?logo=github&labelColor=181717)](https://github.com/sponsors/aidevbody)
[![License: AAL](https://img.shields.io/badge/License-AAL-blue.svg)](#license)
![Platform](https://img.shields.io/badge/platform-macOS%20|%20Linux%20|%20Windows-informational)
![Script](https://img.shields.io/badge/script-bash-informational)

---

## Table of contents

- [Overview](#overview)
- [Why do I need it?](#why-do-i-need-it)
- [Features](#features)
- [Usage](#usage)
- [Roadmap](#roadmap)
- [Tests](#tests)
- [Contributing & Support](#contributing--support)
- [License](#license)

## Overview

This project provides a Bash script (**`CreateAgentInfoFile.sh`**) that helps developers securely transmit their project code to AI assistants. The script walks your project directory, lets you choose which files and folders to include, applies an optional mapping to replace sensitive tokens with placeholders and builds a standalone `.AI` file containing your project's source encoded in Base64. The generated agent can reconstruct the project later and supports reversing the mapping to restore the original tokens.

> **Note on tone** – This project is something I work on in my free time. I enjoy hacking on tools that protect developers' privacy, but I can’t guarantee that I’ll be able to respond to issues or add new languages at lightning speed. Please be patient; I'll do my best when time permits!

### Why do I need it?

* **Protect secrets:** using a `.gitignore` file prevents sensitive files (API keys, credentials, etc.) from being committed to your version control【590544821401444†L41-L55】【366296235028763†L67-L96】.
* **Replace sensitive values with placeholders:** the mapping mechanism allows you to avoid storing plaintext credentials in your scripts and instead substitute them with placeholders while the real secrets are stored securely【467935875021287†L501-L533】.
* **Keep your project structure private:** you can ignore whole folders (for example, `resources/licenses`) so that private project organization remains hidden when sharing code with an AI assistant.

## Features

* **Interactive file selection:** the script walks your project and prompts you to include or exclude each file or folder.
* **Mapping support:** provide a JSON file and define a list of substitutions; sensitive strings are replaced with neutral tokens before encoding and restored when reconstructing the project.
* **Optional installation of dependencies:** if you use mapping, the generated agent can auto‑install `jq` and `perl` on most operating systems.
* **Respect `.gitignore`:** by default, files ignored by `.gitignore` are skipped, helping you avoid committing or sharing unwanted files【366296235028763†L67-L96】.
* **Cross‑platform:** the script works on Linux, macOS and Windows environments with Bash.

## Usage

```bash
./CreateAgentInfoFile.sh [-n "AgentFileName.AI"] [-ig] [-igi] [-m map.json]
./CreateAgentInfoFile.sh [--include --git] [--include --gitignore] [--mapping map.json]
```

Options:

- **`-n`**: specify the output agent file name (defaults to a timestamped `AgentYYYYMMDD-HHMMSS.AI`).
- **`-ig` / `--include --git`**: include Git metadata (`.git/`), but still respect `.gitignore`.
- **`-igi` / `--include --gitignore`**: include files matched by `.gitignore`, but exclude Git metadata.
- Combine both flags to include everything.
- **`-m` / `--mapping map.json`**: path to a JSON mapping file that defines an array of replacements and folders to ignore.

An example mapping file is provided in [`mapping-example.json`](mapping-example.json). To create a mapping file, specify `ignore-folders` for directories to skip and `map` for text replacements scoped to specific files.

## Roadmap

This project currently supports Bash. If we receive support through GitHub Sponsors or donations, we plan to:

- Port the agent creation script to **Python**, **PowerShell**, and other languages.
- Provide a **cross‑platform desktop application** with a graphical interface.
- Expose a stable **API** so other tools can generate and consume secure agent files.
- Add comprehensive **unit tests** and continuous integration workflows.

Feel free to open issues or contribute if you'd like to see specific features added.

## Tests

The repository includes a `test/` folder with dummy files and directories used for unit tests. You can run your own tests by pointing the script at the root and using `--mapping` with the supplied `mapping-example.json`.

## Contributing & Support

Contributions, feature requests, and bug reports are welcome through GitHub issues. If you find this project useful, please consider [sponsoring me](https://github.com/sponsors/aidevbody) or making a donation to help support continued development and the addition of more language environments. A portion of donations will fund development of Python and PowerShell versions and a future cross‑platform GUI.

## License

This project is licensed under the **Attribution Assurance License (AAL)**. You are free to use and modify the code, but any redistribution or derivative work must clearly credit this project and display the attribution banner defined in the license【695430619762696†L82-L98】. See [LICENSE](LICENSE) for the full text.
