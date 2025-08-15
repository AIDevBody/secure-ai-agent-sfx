# secure-ai-agent-sfx · Self-Extracting, Encrypted Context Packager for AI/LLM Agents

[![Sponsor on GitHub Sponsors](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-fafbfc?logo=github&labelColor=181717)](https://github.com/sponsors/aidevbody)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#license)
![Platform](https://img.shields.io/badge/platform-macOS%20|%20Linux%20|%20Windows-informational)
![Python](https://img.shields.io/badge/python-3.9%2B-informational)

**Secure, self-extracting (SFX) packager for AI/LLM agents.** Interactively select exactly which files/folders to share from your repo, **skip `.git` and honor `.gitignore` by default**, redact with **mapping rules**, then **compress (xz)** and **encrypt (AES-256-GCM)** into a portable **Agent.AI** file. Round-trip ready: `unpack → edit → repack → apply` with **inverse mapping** to restore originals safely.

> **Keywords (SEO):** self-extracting, SFX, AI agent, LLM, secure context, encryption, AES-GCM, scrypt, xz compression, git-aware, .gitignore, redaction, mapping, inverse mapping, DevSecOps, data minimization, code security, selective sharing

---

## Support this project ❤️

This project grows **through your donations on GitHub Sponsors**. If you find it useful, please **[sponsor me](https://github.com/sponsors/aidevbody)** to fund development.

- ☕ **$2/mo – Coffee**: a thank-you and your name in the README “Backers”.
- 🙌 **$9/mo – Individual**: backer credit + priority on small feature requests.
- 🛠️ **$25/mo – Team**: priority triage on issues + quarterly roadmap vote.
- 🧭 **$99/mo – Company**: logo in README + roadmap influence + early previews.

> Can’t sponsor? You can still help! **Star** the repo, **share** it, open **issues** with feedback, and improve docs/tests.

---

## Table of contents
- [Why this exists](#why-this-exists)
- [Features](#features)
- [How it works](#how-it-works)
- [Install](#install)
- [Quick start](#quick-start)
- [CLI usage](#cli-usage)
- [Mapping & inverse mapping](#mapping--inverse-mapping)
- [Git / .gitignore behavior](#git--gitignore-behavior)
- [Security model](#security-model)
- [Examples](#examples)
- [Frequently asked questions](#frequently-asked-questions)
- [Troubleshooting](#troubleshooting)
- [Roadmap (funding goals)](#roadmap-funding-goals)
- [Contributing](#contributing)
- [Sponsors & Backers](#sponsors--backers)
- [License](#license)
- [Suggested GitHub topics (SEO)](#suggested-github-topics-seo)
- [Discoverability suggestions](#discoverability-suggestions)

---

## Why this exists

Modern AI/LLM agents are powerful, but **handing over your entire repo is risky and noisy**. This tool enforces **least-privilege sharing**: you pick exactly what goes, defaults avoid VCS/secrets, and sensitive identifiers can be **mapped/redacted**. Content is **compressed and optionally encrypted**, and the recipient gets a **self-extracting (SFX) agent** that’s easy to unpack, edit, and **re-package** back to you. When you apply changes locally, **inverse mapping** restores your original names, namespaces, versions, and comments.

---

## Features

- **Self-extracting (SFX) agent**: one file (`Agent.AI`) the AI can run to unpack and later repack.
- **Encrypted & compressed**: xz compression + AES-256-GCM (scrypt KDF).
- **Git-aware & .gitignore-aware**: skips `.git` internals and ignored paths by default.
- **Interactive, selective sharing**: prompts per folder/file so you never overshare.
- **Redaction mapping + inverse mapping**: string & regex rules for safe round-trips.
- **Round-trip workflow**: `inspect`, `unpack`, `repack`, `apply`.
- **Cross-platform**: macOS, Linux, Windows (Python required).
- **No cloud dependency**: runs locally; ship the artifact however you like.

---

## How it works

1. From repo root, **select** files/folders to include (defaults skip `.git` and `.gitignore` entries).
2. Optional **mapping** transforms text (e.g., `AcmeCorp` → `ANON_CO`) before packaging.
3. Data is **tarred + xz-compressed**, then **optionally AES-GCM encrypted** (scrypt-derived key).
4. A single **self-extracting Python script** is generated: `Agent.AI`.
5. The AI (or you) runs `Agent.AI` to **inspect / unpack** into a work dir.
6. After edits, run `Agent.AI repack` to produce `Agent_return.AI`.
7. Back on your machine, `Agent_return.AI apply` **inverse-maps** and writes changes to your repo.

---

## Install

**Requirements**
- Python **3.9+**
- Optional: `cryptography` for AES-GCM encryption

```bash
pip install -U cryptography
````

> If you skip `cryptography`, you can still make an **unencrypted** SFX (`--no-encrypt`).

This repo provides a single entry script (e.g., `agent_packager.py`). You can vendor it directly into other projects.

---

## Quick start

From your **repo root**:

```bash
# Create a secure, self-extracting (SFX) agent
python agent_packager.py pack --out Agent.AI
```

* You’ll be prompted per folder/file.
* By default, `.git` and `.gitignore` matches are **excluded**.
* Add a mapping file: `--map mappings.json`
* Stronger security (don’t embed key): `--ask-pass --no-embed-key`

**On the AI side (or locally to test):**

```bash
python Agent.AI inspect
python Agent.AI unpack --to ./work
# ... AI edits content under ./work ...
python Agent.AI repack --out Agent_return.AI
```

**Back on your machine:**

```bash
python Agent_return.AI apply --to .
```

---

## CLI usage

```bash
python agent_packager.py pack --out Agent.AI \
  [--include-git] [--include-gitignore] \
  [--map mappings.json] \
  [--ask-pass | --no-encrypt] [--no-embed-key]
```

* `--include-git` – include `.git` and git dotfiles if you really want them
* `--include-gitignore` – include files matched by `.gitignore`
* `--map` – JSON mapping rules (see below)
* `--ask-pass` – prompt for passphrase (recommended)
* `--no-encrypt` – produce an **unencrypted** SFX
* `--no-embed-key` – don’t embed the key; safer if you’ll share the passphrase out-of-band

**Agent commands (inside `Agent.AI` / `Agent_return.AI`):**

```bash
python Agent.AI inspect
python Agent.AI unpack --to ./work
python Agent.AI repack --out Agent_return.AI
python Agent_return.AI apply --to .
```

---

## Mapping & inverse mapping

Supply a JSON file:

```json
{
  "rules": [
    { "type": "sub",   "pattern": "AcmeCorp", "replace": "ANON_CO" },
    { "type": "regex", "pattern": "(?m)^API_KEY=.*$", "replace": "API_KEY=REDACTED", "inverse": null }
  ]
}
```

**Notes**

* `type: "sub"` — exact substring replacement. **Invertible** if each `replace` value is unique.
* `type: "regex"` — Python regex substitution. For **invertible** behavior, provide an `"inverse"` replacement.
* Non-UTF8 files are passed through unchanged (no mapping).

**Invertibility rules**

* Make `replace` values unique for `sub` rules (avoid collisions).
* Provide `inverse` for any `regex` rule you want to restore precisely.
* Non-invertible rules are fine for one-way redaction (skipped on `apply`).

---

## Git / .gitignore behavior

* **Default:** `.git` directories and common git dotfiles are **excluded**.
* **Default:** files matched by `.gitignore` are **excluded** (uses `git check-ignore` when available; otherwise a simple matcher).
* Override with `--include-git` and/or `--include-gitignore` only if you understand the risks.

This reduces the chance of shipping **secrets, caches, build artifacts, or large blobs** to an AI/LLM.

---

## Security model

* **Encryption:** AES-256-GCM with **scrypt** key derivation; GCM tag provides tamper evidence.
* **Compression first:** compress with xz (size reduction), then encrypt (confidentiality).
* **Key handling:**

  * **Best**: `--ask-pass --no-embed-key` → share passphrase out-of-band.
  * **Convenient**: embed a random passphrase for auto-decrypt on the AI side (not confidential—key sits with ciphertext).
* **Threat model:** protects data **in transit/at rest** in the SFX file. Once executed on a third-party system, content is decrypted on that machine; trust that runtime.

---

## Examples

**1) Encrypted SFX with out-of-band key**

```bash
python agent_packager.py pack --out Agent.AI --ask-pass --no-embed-key
```

**2) Include `.gitignore` matches (still skip `.git`)**

```bash
python agent_packager.py pack --out Agent.AI --include-gitignore
```

**3) Redact namespaces & company names, restore on apply**

```bash
cat > mappings.json <<'JSON'
{
  "rules": [
    {"type":"sub","pattern":"com.acme.product","replace":"org.redacted.pkg"},
    {"type":"sub","pattern":"AcmeCorp","replace":"ANON_CO"}
  ]
}
JSON

python agent_packager.py pack --out Agent.AI --map mappings.json --ask-pass --no-embed-key
```

---

## Frequently asked questions

**Does encryption reduce size?**
No. **Compression** reduces size; encryption provides confidentiality. We compress first (xz), then encrypt.

**Can an AI auto-decrypt the package?**
Yes **if** you embed the key. That’s convenient but not confidential. For true confidentiality, don’t embed the key and provide it separately.

**What if my mapping isn’t invertible?**
It still works. Non-invertible rules are skipped during `apply`. Use invertible rules for items you need restored exactly.

**Why a self-extracting (SFX) Python script?**
It’s portable, single-file, and easy to run anywhere with Python 3.9+. No extra tooling required.

**Windows support?**
Yes. Use `py` launcher or `python` in PowerShell; paths are handled cross-platform.

---

## Troubleshooting

* **“cryptography not installed”** → `pip install cryptography` or run with `--no-encrypt`.
* **“Decryption failed”** → check passphrase; ensure salt/nonce weren’t altered.
* **Non-UTF8 files unchanged** → mapping applies to UTF-8 text only; binaries are preserved.
* **.gitignore mismatch** → ensure repo root; we call `git check-ignore` when available.

---

## Roadmap (funding goals)

Your sponsorship directly funds the following:

* ✅ **Core SFX packager** (current)
* 🔜 **TUI selector** (fuzzy search, multi-select, previews)
* 🔜 **Patch/diff preview** before `apply` + rollback
* 🔜 **Key vaults** (1Password, OS keychain, env) for passphrases
* 🔜 **MCP adapter** to expose only selected files to agents
* 🔜 **GUI** (cross-platform) for click-driven packaging
* 🔜 **CI integration** (policy files, approvals, artifact signing)
* 🔜 **Windows EXE stub** (native self-extracting launcher)

> Roadmap order is prioritized by **Sponsors**. Vote in discussions or sponsor to influence priorities.

---

## Contributing

Issues and PRs are welcome! Please:

* Keep changes small and focused.
* Add tests where relevant.
* Document new flags and update examples.
* Be respectful—this is a safe space for newcomers.

To enable funding buttons on forks, add a `.github/FUNDING.yml`:

```yaml
github: [AIDevBody]
```

---

## Sponsors & Backers

**Thank you!** This project is made possible by generous support.

* *Your name or company here* – become a sponsor: **[https://github.com/sponsors/YOUR\_GITHUB\_HANDLE](https://github.com/sponsors/aidevbody)**

---

## License

MIT — see `LICENSE`.

---

## Suggested GitHub topics (SEO)

```
ai llm agent self-extracting sfx packager packaging encryption aes-gcm scrypt compression xz security privacy redaction mapping inverse-mapping git gitignore devsecops data-minimization code-security context-pack selective-sharing least-privilege sponsor donations
```

---

## Discoverability suggestions

* **Add topics** (above) to the repo.
* **About blurb:**
  *“Self-extracting (SFX), encrypted context packager for AI/LLM agents — git/.gitignore-aware with redaction mapping + inverse mapping for safe, round-trip edits.”*
* **Badges:** keep the **Sponsor** badge visible near the title.
* **Pinned issue:** “How to Sponsor & What You Fund”.
* **Release notes:** include SEO terms (self-extracting, encryption, redaction).
* **Screenshots/GIFs:** show interactive selection + unpack/repack/apply flow.
* **Blog/Dev.to/Medium post:** link back to the repo with the same keywords.

```
