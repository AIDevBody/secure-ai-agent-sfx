# Secure AI Agent SFX

## Overview

This project provides a Bash script (**`CreateAgentInfoFile.sh`**) that helps developers securely transmit their project code to AI assistants. The script walks your project directory, lets you choose which files and folders to include, applies an optional mapping to replace sensitive tokens with placeholders and builds a standalone `.AI` file containing your project's source encoded in Base64. The generated agent can reconstruct the project later and supports reversing the mapping to restore the original tokens.

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

Contributions, feature requests, and bug reports are welcome through GitHub issues. If you find this project useful, please consider [sponsoring us](https://github.com/AIDevBody/secure-ai-agent-sfx) or making a donation to help support continued development and the addition of more language environments. A portion of donations will fund development of Python and PowerShell versions and a future cross‑platform GUI.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
