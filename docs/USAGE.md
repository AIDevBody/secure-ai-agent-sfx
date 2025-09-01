# Usage Guide

## Table of contents

- [Creating an Agent File](#creating-an-agent-file)
- [Reconstructing a Project](#reconstructing-a-project)
- [Troubleshooting](#troubleshooting)
- [Notes](#notes)

---

This document expands on the quick usage provided in the README and gives examples for creating an agent file and reconstructing your project.

## Creating an Agent File

1. Navigate to the root of your project:

   ```bash
   cd /path/to/your/project
   ```

2. Create an agent named `MyProject.AI` using a mapping file:

   ```bash
   ./CreateAgentInfoFile.sh -n "MyProject.AI" -m mapping-example.json

   Before scanning your project, the script validates the JSON syntax of the mapping file. If it detects invalid JSON—most commonly trailing commas before a closing `]` or `}`—it offers to automatically correct the file by removing those commas. If you decline the correction, the script aborts so you can fix the file manually.
   ```

3. Follow the prompts. The script will walk through your project and ask whether to include or exclude files and directories. Answer `y` to include and `n` to exclude. Selecting "Add all files" for a directory will include all files within that directory while still respecting `.gitignore` and your mapping file's ignored folders.

4. Upon completion, the script generates `MyProject.AI`. This file contains a Base64‑encoded snapshot of your selected project files, with sensitive strings replaced by placeholders as defined in your mapping file. Keep this file safe — it can reconstruct your project.

## Reconstructing a Project

To reconstruct the project from an agent file:

1. Copy the generated `.AI` file to your working directory.
2. On macOS/Linux, ensure it’s executable:

   ```bash
   chmod +x MyProject.AI
   ```

3. Run the agent. If you used a mapping file when creating the agent, supply the same mapping file so that placeholders are replaced with their original values:

   ```bash
   ./MyProject.AI --mapping mapping-example.json
   ```

4. The agent will recreate all included files and directories **relative to the current directory**.

## Troubleshooting

- **Missing dependency: jq** (Windows Git Bash):  
  Install via MSYS2 pacman:
  ```bash
  pacman -S mingw-w64-x86_64-jq
  ```
  Ensure Git Bash can find it on `PATH`. Alternatively, use WSL and install with your distro’s package manager.

- **Missing dependency: perl**:  
  Install from your platform’s package manager (e.g., `sudo apt-get install perl`, `brew install perl`, or MSYS2 pacman).

- **Permission denied (macOS/Linux)** when running `.AI` files:  
  ```bash
  chmod +x MyProject.AI
  ```

- **Mapping not applied during reconstruction**:  
  Be sure to pass the same mapping file path: `./MyProject.AI --mapping mapping-example.json`

## Notes

- If dependencies (`jq` and `perl`) are missing and you provided a mapping file, the agent attempts to install them and will prompt before doing so.
- The mapping file is **never** packaged into the agent file for security reasons. Keep your mapping file safe (ideally private).
- You can combine `--include git` and `--include gitignore` to include **everything**, including Git metadata and files normally excluded by `.gitignore`.