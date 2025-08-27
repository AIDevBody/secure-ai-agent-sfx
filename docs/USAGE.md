# Usage Guide

## Table of contents

- [Creating an Agent File](#creating-an-agent-file)
- [Reconstructing a Project](#reconstructing-a-project)
- [Notes](#notes)

---

This document expands on the quick usage provided in the README and gives examples for creating an agent file and reconstructing your project.

## Creating an Agent File

1. Navigate to the root of your project:

   ```bash
   cd /path/to/your/project
   ```

2. Run the script with your desired options. For example, to create an agent called `MyProject.AI` while ignoring any Git metadata and using a mapping file:

   ```bash
   ./CreateAgentInfoFile.sh -n "MyProject.AI" -m mapping-example.json
   ```

3. Follow the prompts. The script will walk through your project and ask whether to include or exclude files and directories. Answer `y` to include and `n` to exclude. Selecting "Add all files" for a directory will include all files within that directory while still respecting `.gitignore` and your mapping file's ignored folders.

4. Upon completion, the script generates `MyProject.AI`. This file contains a Base64‑encoded snapshot of your selected project files, with sensitive strings replaced by placeholders as defined in your mapping file. Keep this file safe — it can reconstruct your project.

## Reconstructing a Project

To reconstruct the project from an agent file:

1. Copy the generated `.AI` file to your working directory.
2. Run the agent script. If you used a mapping file when creating the agent, supply the same mapping file so that placeholders are replaced with their original values:

   ```bash
   ./MyProject.AI --mapping mapping-example.json
   ```

3. The agent will recreate all included files and directories relative to the current directory.

## Notes

- If dependencies (`jq` and `perl`) are missing on your machine and you provided a mapping file, the agent attempts to install them for you. It prompts before installation.
- The mapping file is never packaged into the agent file for security reasons. Keep your mapping file safe and version‑controlled in a private repository.
- You can combine `--include --git` and `--include --gitignore` options to include everything, including Git metadata and files normally excluded by `.gitignore`.

