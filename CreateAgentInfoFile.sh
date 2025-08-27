#!/usr/bin/env bash
#
# CreateAgentInfoFile.sh (auto-install + mapping support)
#
# Generate an Agent.AI script that can reconstruct the current project.
# Adds:
#   - -m FILE / --mapping FILE : JSON mapping to (a) ignore folders and
#                                (b) substitute sensitive strings BEFORE encoding.
#   - Auto-install prompts for jq/perl only when mapping is used.
#   - The generated Agent supports -m FILE and auto-installs jq/perl if needed,
#     but only when -m/--mapping is provided.
#
# Mapping JSON example:
# {
#   "description": "...",
#   "ignore-folders": ["resources/licenses", "docs"],
#   "map": [
#     { "scope": ".", "list": [ {"<your company name, e.g.: AIDevBody>":"Company"}, {"<your project name, e.g.: AIDevBody::secure-ai-agent-sfx>":"Company::Project_A"} ] },
#     { "scope": "scripts/run_smoke.sh", "list": [ {"cmake --preset release":"cmake release"} ] }
#   ]
# }
#
# Usage:
#   ./CreateAgentInfoFile.sh [-n "Custom Agent.AI"] [-ig] [-igi] [-m map.json]
#   ./CreateAgentInfoFile.sh [--include --git] [--include --gitignore] [--mapping map.json]

set -euo pipefail
# Fail fast: any error (-e), unset var (-u), and pipeline error propagation (-o pipefail).
# Important because this script performs interactive file walking and code generation.

AGENT_FILE_ARG=""
MAPPING_FILE=""

# -------------------------
# Usage / CLI help text
# -------------------------
print_usage() {
    cat <<'EOM'
Usage:
  ./CreateAgentInfoFile.sh [-n "Custom Agent.AI"] [-ig] [-igi] [-m map.json]
  ./CreateAgentInfoFile.sh [--include --git] [--include --gitignore] [--mapping map.json]

Options:
  -n STRING              Set the output Agent file name (e.g., -n "My Agent.AI")
  -m FILE, --mapping FILE
                         JSON mapping file to (1) ignore folders, (2) map sensitive text before encoding.
                         The generated Agent will accept -m FILE to invert the mapping on reconstruction.
  -h                     Show this help and exit

Inclusion controls (combine as needed):
  -ig                    Include Git things (.git/, .gitignore, etc.) but still ignore .gitignore matches
  -igi                   Include files matched by .gitignore but still ignore Git things
  --include --git        Same as -ig
  --include --gitignore  Same as -igi

Combining -ig and -igi (or both long forms) includes everything (Git + .gitignored).
EOM
}

# -------------------------
# Cross-platform installer helpers (best-effort)
# These helpers are only invoked when mapping is requested, to install jq/perl.
# The idea: try a bunch of package managers, don't crash if they fail, and
# attempt to discover binaries added to PATH during the current shell session.
# -------------------------
have() { command -v "$1" >/dev/null 2>&1; }
_have_pm() { have "$1" || have "$1.exe"; }

ask_yes_no() {
  # Minimal y/N prompt with default; any non-[yY] counts as "no".
  local prompt="$1" default_answer="${2:-n}" ans
  read -r -p "$prompt " ans || true
  ans=${ans:-$default_answer}
  case "$ans" in y|Y) return 0 ;; *) return 1 ;; esac
}

_run_allow_fail() {
  # Run a command but do not abort the whole script on failure.
  set +e
  bash -c "$*"
  local rc=$?
  set -e
  return $rc
}

is_windows() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0;; *) return 1;; esac; }
have() { command -v "$1" >/dev/null 2>&1; }  # redefined harmlessly; identical behavior

# Attempt to extend PATH in the current process with common Windows locations.
# This is useful because PMs like winget/choco/scoop may install but not refresh PATH in this shell.
_try_add_known_paths() {
  # Tries to add typical Windows install dirs to PATH for this process
  local tool="$1" added=0
  if is_windows; then
    local candidates=()
    # Common package-manager shims/dirs
    candidates+=("/c/ProgramData/chocolatey/bin")
    candidates+=("$HOME/scoop/shims")
    # Winget’s typical location for jq
    candidates+=("/c/Program Files/jq")
    candidates+=("/c/Program Files (x86)/jq")
    # MSYS2
    candidates+=("/c/msys64/usr/bin" "/c/msys64/mingw64/bin")
    # Git’s own usr/bin (rarely has jq, but harmless to include)
    candidates+=("/c/Program Files/Git/usr/bin")
    # Perl locations (only when resolving perl)
    if [[ "$tool" == "perl" ]]; then
      candidates+=("/c/Strawberry/perl/bin" "/c/Perl64/bin")
    fi
    for d in "${candidates[@]}"; do
      [[ -d "$d" ]] || continue
      case ":$PATH:" in *":$d:"*) ;; *) export PATH="$d:$PATH"; added=1;; esac
    done
  fi
  hash -r 2>/dev/null || true
  have "$tool"
}

_post_install_resolve() {
  # After attempting installation, try again to locate the tool (plus PATH hints).
  local tool="$1"
  hash -r 2>/dev/null || true
  have "$tool" && return 0
  _try_add_known_paths "$tool" && return 0
  return 1
}

# Best-effort installers: probe many PMs to install jq/perl.
# No single PM is assumed; this intentionally favors breadth over certainty.
_attempt_install_jq() {
  # Try platform-specific package names
  if _have_pm winget; then
    _run_allow_fail "winget install -e --id jqlang.jq" && return 0
  fi
  if _have_pm choco; then
    _run_allow_fail "choco install jq -y" && return 0
  fi
  if _have_pm scoop; then
    _run_allow_fail "scoop install jq" && return 0
  fi
  if _have_pm pacman; then
    # MSYS2 / Arch
    _run_allow_fail "pacman -S --noconfirm jq" || _run_allow_fail "pacman -S --noconfirm mingw-w64-x86_64-jq" && return 0
  fi
  if _have_pm apt-get; then
    _run_allow_fail "sudo apt-get update && sudo apt-get install -y jq" && return 0
  fi
  if _have_pm dnf; then
    _run_allow_fail "sudo dnf install -y jq" && return 0
  fi
  if _have_pm yum; then
    _run_allow_fail "sudo yum install -y jq" && return 0
  fi
  if _have_pm zypper; then
    _run_allow_fail "sudo zypper install -y jq" && return 0
  fi
  if _have_pm apk; then
    _run_allow_fail "sudo apk add jq" && return 0
  fi
  if _have_pm brew; then
    _run_allow_fail "brew install jq" && return 0
  fi
  if _have_pm port; then
    _run_allow_fail "sudo port install jq" && return 0
  fi
  return 1
}

_attempt_install_perl() {
  if _have_pm winget; then
    _run_allow_fail "winget install -e --id StrawberryPerl.StrawberryPerl" && return 0
  fi
  if _have_pm choco; then
    _run_allow_fail "choco install strawberryperl -y" && return 0
  fi
  if _have_pm scoop; then
    _run_allow_fail "scoop install perl" && return 0
  fi
  if _have_pm pacman; then
    _run_allow_fail "pacman -S --noconfirm perl" || _run_allow_fail "pacman -S --noconfirm mingw-w64-x86_64-perl" && return 0
  fi
  if _have_pm apt-get; then
    _run_allow_fail "sudo apt-get update && sudo apt-get install -y perl" && return 0
  fi
  if _have_pm dnf; then
    _run_allow_fail "sudo dnf install -y perl" && return 0
  fi
  if _have_pm yum; then
    _run_allow_fail "sudo yum install -y perl" && return 0
  fi
  if _have_pm zypper; then
    _run_allow_fail "sudo zypper install -y perl" && return 0
  fi
  if _have_pm apk; then
    _run_allow_fail "sudo apk add perl" && return 0
  fi
  if _have_pm brew; then
    _run_allow_fail "brew install perl" && return 0
  fi
  if _have_pm port; then
    _run_allow_fail "sudo port install perl5" && return 0
  fi
  return 1
}

# Only enforce jq/perl presence when mapping is requested.
# The prompts here intentionally explain PATH-refresh quirks on Windows.
ensure_mapping_deps_if_needed() {
    # Only prompt/install when mapping is used
    if [[ -z "${MAPPING_FILE:-}" ]]; then return 0; fi

    if ! have jq; then
        echo "Missing dependency: jq"
        if ask_yes_no "Attempt to install jq now? [y/N]" "n"; then
            if _attempt_install_jq && _post_install_resolve jq; then
              echo "jq available."
              if is_windows; then
                echo "restarting window is required! on the next usage as the windows PATH does not updates with out restating."
              fi
          else
              echo "jq seems installed but not visible in this shell."
              echo "Try restarting Git Bash, or add jq’s folder to PATH (e.g. C:\\Program Files\\jq or %USERPROFILE%\\scoop\\shims)."
              if is_windows; then
                  echo "Restart your OS to be sure."
              fi
              exit 2
          fi
        else
            echo "jq is required with -m/--mapping. Aborting."
            exit 2
        fi
    fi

    if ! have perl; then
        echo "Missing dependency: perl"
        if ask_yes_no "Attempt to install Perl now? [y/N]" "n"; then
            if _attempt_install_perl && _post_install_resolve perl; then
                echo "Perl available."
                if is_windows; then
                    echo "restarting window is required! on the next usage as the windows PATH does not updates with out restating."
                fi
            else
                echo "Perl seems installed but not visible in this shell."
                echo "Try restarting Git Bash, or add Perl’s bin (e.g. C:\\Strawberry\\perl\\bin) to PATH."
                if is_windows; then
                    echo "Restart your OS to be sure."
                fi
                exit 2
            fi
        else
            echo "Perl is required with -m/--mapping. Aborting."
            exit 2
        fi
    fi
}

# -------------------------
# Parse short options first (-n, -m, -h)
# -------------------------
while getopts ":n:m:h" opt; do
    case "$opt" in
        n) AGENT_FILE_ARG="$OPTARG" ;;
        m) MAPPING_FILE="$OPTARG" ;;
        h) print_usage; exit 0 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 2 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; print_usage; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

# -------------------------
# Parse remaining long/flag args (order-safe)
# This pass supports mixing flags like --include --git and --gitignore
# and also captures --mapping when provided after positionals.
# -------------------------
_have_include=0
_have_git=0
_have_gitignore=0

args=("$@")
i=0
while (( i < ${#args[@]} )); do
    arg="${args[$i]}"
    case "$arg" in
        -ig)   _have_include=1; _have_git=1 ;;
        -igi)  _have_include=1; _have_gitignore=1 ;;
        -i)    _have_include=1 ;;
        -g)    _have_git=1 ;;
        --include)    _have_include=1 ;;
        --git)        _have_git=1 ;;
        --gitignore)  _have_gitignore=1 ;;
        --mapping)
            ((i++))
            if (( i >= ${#args[@]} )); then echo "Error: --mapping requires a value" >&2; exit 2; fi
            MAPPING_FILE="${args[$i]}"
            ;;
        *) ;;
    esac
    ((i++))
done

# If mapping is requested, ensure deps (ask/install if missing)
ensure_mapping_deps_if_needed

# Convert the high-level include switches into concrete booleans.
INCLUDE_GIT=0
INCLUDE_GITIGNORE=0
if [[ $_have_include -eq 1 && $_have_git -eq 1 ]]; then
    INCLUDE_GIT=1
fi
if [[ $_have_include -eq 1 && $_have_gitignore -eq 1 ]]; then
    INCLUDE_GITIGNORE=1
fi

PROJECT_ROOT="$(pwd)"

# Compute a project-relative path to the mapping file (if it lives under the project).
# This allows later exclusion of the mapping file from the payload.
MAP_REL=""
if [[ -n "${MAPPING_FILE:-}" ]]; then
  # Compute absolute path of mapping file
  _map_abs="$(cd "$(dirname "$MAPPING_FILE")" 2>/dev/null && pwd -P)/$(basename "$MAPPING_FILE")"
  # If mapping file lives inside PROJECT_ROOT, compute its project-relative path
  case "$_map_abs" in
    "$PROJECT_ROOT"/*) MAP_REL="${_map_abs#"$PROJECT_ROOT"/}" ;;
  esac
fi

# -------------------------
# Optional mapping support
# If a mapping file was specified, parse it:
#  - Validate file exists
#  - Pull "ignore-folders" to skip entire directories during collection
# -------------------------
MAPPING_ENABLED=0
declare -a IGNORE_FOLDERS=()
if [[ -n "${MAPPING_FILE:-}" ]]; then
    if [[ ! -f "$MAPPING_FILE" ]]; then
        echo "Mapping file not found: $MAPPING_FILE" >&2
        exit 2
    fi
    MAPPING_ENABLED=1
    # Load ignore-folders (jq will exist if we reached here)
    mapfile -t IGNORE_FOLDERS < <(jq -r '."ignore-folders"[]? | ltrimstr("./")' "$MAPPING_FILE")
fi

# -------------------------
# Agent file name resolution
# If not provided, prompt and offer a timestamp-based default.
# -------------------------
if [[ -n "$AGENT_FILE_ARG" ]]; then
    AGENT_FILE="$AGENT_FILE_ARG"
else
    ts="$(date +%Y%m%d-%H%M%S)"
    default_name="Agent${ts}.AI"
    read -r -p "No agent name provided. Use autogenerated ${default_name}? [Y/n] " _ans
    case "${_ans:-Y}" in
        n|N)
            read -r -p "Enter Agent file name: " user_name
            user_name=${user_name:-$default_name}
            AGENT_FILE="$user_name"
            ;;
        *)
            AGENT_FILE="$default_name"
            ;;
    esac
fi

AGENT_FILE_BARE="${AGENT_FILE#./}"
AGENT_LABEL="$AGENT_FILE_BARE"

# -------------------------
# .gitignore support
# The script supports two ways to treat ignore rules:
#   1) If "git" is available, use `git check-ignore --no-index` for accuracy.
#   2) Otherwise, a lightweight parser handles simple patterns and directory ignores.
# -------------------------
GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"
declare -a GITIGNORE_PATTERNS=()
GITIGNORE_LOADED=0

load_gitignore() {
    # Load non-comment, non-empty lines; keep raw patterns for manual matching fallback.
    if [[ -f "$GITIGNORE_FILE" ]]; then
        GITIGNORE_LOADED=1
        while IFS= read -r line || [[ -n "${line:-}" ]]; do
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
            GITIGNORE_PATTERNS+=("$line")
        done < "$GITIGNORE_FILE"
    fi
}
load_gitignore

is_git_related() {
    # Treat VCS control files as "git things" that are excluded unless INCLUDE_GIT=1.
    local p="${1#./}"
    local base
    base="$(basename "$p")"
    case "$p" in
        .git|.git/*|*/.git|*/.git/*) return 0 ;;
    esac
    case "$base" in
        .gitignore|.gitattributes|.gitmodules|.gitkeep) return 0 ;;
    esac
    return 1
}

is_gitignored() {
    # Prefer git’s own matcher if available. Otherwise do a simplified match:
    #  - directory patterns ending with "/" match the dir and its descendants
    #  - exact path matches (with optional leading "/")
    local rel="${1#./}"
    if [[ $INCLUDE_GITIGNORE -eq 1 ]]; then
        return 1
    fi

    if command -v git >/dev/null 2>&1; then
        if (cd "$PROJECT_ROOT" && git check-ignore -q --no-index "$rel") 2>/dev/null; then
            return 0
        fi
    fi

    if [[ $GITIGNORE_LOADED -eq 1 ]]; then
        local pat raw
        for raw in "${GITIGNORE_PATTERNS[@]}"; do
            pat="$raw"
            if [[ "$pat" == */ ]]; then
                pat="${pat%/}"
                if [[ "$rel" == "$pat" || "$rel" == "$pat/"* ]]; then
                    return 0
                fi
                continue
            fi
            if [[ "${pat:0:1}" == "/" ]]; then
                pat="${pat#/}"
            fi
            if [[ "$rel" == $pat ]]; then
                return 0
            fi
        done
    fi

    return 1
}

# -------------------------
# Mapping helpers
# - path_is_under_ignored: consults mapping's "ignore-folders"
# - make_forward_perl_for_file: builds a temporary Perl script that applies
#   mapping substitutions FORWARD (from -> to) for a specific file scope.
#   This Perl runs at "creation" time before base64 encoding.
# -------------------------
path_is_under_ignored() {
    # returns 0 (true) if $1 is inside any ignore folder from mapping
    local rel="${1#./}"
    if [[ $MAPPING_ENABLED -eq 0 || ${#IGNORE_FOLDERS[@]} -eq 0 ]]; then
        return 1
    fi
    local ig
    for ig in "${IGNORE_FOLDERS[@]}"; do
        ig="${ig#./}"
        if [[ "$rel" == "$ig" || "$rel" == "$ig/"* || "$rel" == */"$ig"/* ]]; then
            return 0
        fi
    done
    return 1
}

# This generator uses jq to:
#  - Validate mapping structure
#  - Filter entries by scope so only relevant replacements apply to this file
#  - Emit Perl s/// rules (escaped with \Q...\E) sorted by decreasing 'from' length
#    to prevent shorter tokens from clobbering longer ones.
make_forward_perl_for_file() {
    local rel="$1"
    local tmp
    tmp="$(mktemp)"
    {
        echo 'use strict; use warnings; binmode STDIN; binmode STDOUT; undef $/; $_=<STDIN>;'
        # Robust jq: only accept objects having optional .scope and array .list
        jq -r --arg f "$rel" '
        (.map // [])
        | map(select(type=="object"))
        | map({scope: (.scope // "."), list: (.list // [])})
        | map(select(.list | type=="array"))
        | ($f | tostring | ltrimstr("./")) as $f
        | map(select(
            (.scope | tostring | ltrimstr("./")) as $s
            | ($s == "" or $s == "." or ($f == $s) or ($f | startswith(($s + "/"))))
          ))
        | map(
            .list[] | objects | to_entries[]
            | {from: (.key|tostring), to: (.value|tostring)}
          )
        | sort_by(-(.from|length))
        | .[]
        | "s|\\Q" + (.from|gsub("\\|";"\\|")) + "\\E|" + (.to|gsub("\\|";"\\|")) + "|g;"
      ' "$MAPPING_FILE" || { echo "Invalid mapping file format (expected .map to be an array of objects)."; rm -f "$tmp"; exit 2; }
        echo 'print $_;'
    } > "$tmp"
    printf '%s\n' "$tmp"
}

# -------------------------
# Exclusion predicate
# Centralized filtering that combines:
#   - Self-exclusion (this script and the output agent)
#   - Mapping ignore-folders
#   - Git metadata exclusion unless requested
#   - .gitignore matching unless requested
# -------------------------
should_exclude_path() {
    local rel="${1#./}"
    # Always exclude this script and the agent output file
    if [[ "$rel" == "CreateAgentInfoFile.sh" || "$rel" == "$AGENT_FILE_BARE" ]]; then
        return 0
    fi
    # Exclude the mapping file itself if it's inside the project
    if [[ -n "${MAP_REL:-}" && "$rel" == "$MAP_REL" ]]; then
        return 0
    fi
    # Mapping ignore-folders
    if path_is_under_ignored "$rel"; then
        return 0
    fi
    # Git bits
    if [[ $INCLUDE_GIT -eq 0 ]]; then
        if is_git_related "$rel"; then
            return 0
        fi
    fi
    # .gitignore matches
    if [[ $INCLUDE_GITIGNORE -eq 0 ]]; then
        if is_gitignored "$rel"; then
            return 0
        fi
    fi
    return 1
}

# -------------------------
# Interactive walk
# Recursively traverse the project, asking the user which dirs/files to include.
# Two modes:
#  - "include all" for a directory: bulk-add all files under it honoring exclusions
#  - per-file prompts
# Choices are also recorded for .ai_config later.
# -------------------------
declare -a INCLUDED_FILES
declare -A CHOICE_INCLUDE
declare -A CHOICE_EXCLUDE

process_directory() {
    local dir_rel="$1"
    local dir_key="${dir_rel#./}"
    local entries
    entries=()
    while IFS= read -r entry; do
        entries+=("$entry")
    done < <(ls -A "$PROJECT_ROOT/$dir_rel")

    local include_all=0
    local skip_dir=0

    if [[ "$dir_rel" != "." ]]; then
        if ! should_exclude_path "$dir_rel"; then
            : # keep
        else
            return
        fi
    fi

    if [[ "$dir_rel" != "." ]]; then
        if ask_yes_no "Add folder $dir_rel to $AGENT_LABEL? [y/N]" "n"; then
            CHOICE_INCLUDE["$dir_key"]=1
            if ask_yes_no "Add all files in $dir_rel to $AGENT_LABEL? [y/N]" "n"; then
                include_all=1
            else
                include_all=0
            fi
        else
            skip_dir=1
            CHOICE_EXCLUDE["$dir_key"]=1
        fi
    else
        include_all=0
    fi

    if [[ $skip_dir -eq 1 ]]; then
        return
    fi

    if [[ $include_all -eq 1 ]]; then
        while IFS= read -r f; do
            local rel
            rel="${f#$PROJECT_ROOT/}"
            rel="${rel#./}"
            rel="${rel#/}"
            if should_exclude_path "$rel"; then
                continue
            fi
            INCLUDED_FILES+=("$rel")
        done < <(find "$PROJECT_ROOT/$dir_rel" -type f)
    else
        for entry in "${entries[@]}"; do
            local path_rel
            path_rel="$dir_rel/$entry"
            if should_exclude_path "$path_rel"; then
                continue
            fi
            if [[ -d "$PROJECT_ROOT/$path_rel" ]]; then
                process_directory "$path_rel"
            else
                local rel_file
                rel_file="${path_rel#./}"
                if ask_yes_no "Add file $rel_file to $AGENT_LABEL? [y/N]" "n"; then
                    INCLUDED_FILES+=("$rel_file")
                    CHOICE_INCLUDE["$rel_file"]=1
                else
                    CHOICE_EXCLUDE["$rel_file"]=1
                fi
            fi
        done
    fi
}

process_directory "."

# Canonicalize collected paths: strip any leading "./" and leading "/" (defensive)
for i in "${!INCLUDED_FILES[@]}"; do
  f="${INCLUDED_FILES[$i]}"
  f="${f#./}"
  f="${f#/}"
  INCLUDED_FILES[$i]="$f"
done

# -------------------------
# Write Agent file header (includes auto-install for mapping deps)
# The generated Agent mirrors the dependency behavior: jq/perl are only requested
# if the user passes -m/--mapping to invert substitutions at reconstruction time.
# -------------------------
> "$AGENT_FILE"
cat <<'EOH' > "$AGENT_FILE"
#!/usr/bin/env bash
# ========= Generated Agent =========
set -euo pipefail

# Auto-install helpers (mirrors generator logic), used only when -m/--mapping is provided.
have() { command -v "$1" >/dev/null 2>&1; }
_have_pm() { command -v "$1" >/dev/null 2>&1 || command -v "$1.exe" >/dev/null 2>&1; }
_run_allow_fail() { set +e; bash -c "$*"; rc=$?; set -e; return $rc; }
ask_yes_no() { local p="$1" d="${2:-n}" a; read -r -p "$p " a || true; a=${a:-$d}; case "$a" in y|Y) return 0;; *) return 1;; esac; }

is_windows() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0;; *) return 1;; esac; }

_attempt_install_jq() {
  if _have_pm winget; then _run_allow_fail "winget install -e --id jqlang.jq" && return 0; fi
  if _have_pm choco;  then _run_allow_fail "choco install jq -y" && return 0; fi
  if _have_pm scoop;  then _run_allow_fail "scoop install jq" && return 0; fi
  if _have_pm pacman; then _run_allow_fail "pacman -S --noconfirm jq" || _run_allow_fail "pacman -S --noconfirm mingw-w64-x86_64-jq" && return 0; fi
  if _have_pm apt-get; then _run_allow_fail "sudo apt-get update && sudo apt-get install -y jq" && return 0; fi
  if _have_pm dnf;    then _run_allow_fail "sudo dnf install -y jq" && return 0; fi
  if _have_pm yum;    then _run_allow_fail "sudo yum install -y jq" && return 0; fi
  if _have_pm zypper; then _run_allow_fail "sudo zypper install -y jq" && return 0; fi
  if _have_pm apk;    then _run_allow_fail "sudo apk add jq" && return 0; fi
  if _have_pm brew;   then _run_allow_fail "brew install jq" && return 0; fi
  if _have_pm port;   then _run_allow_fail "sudo port install jq" && return 0; fi
  return 1
}
_attempt_install_perl() {
  if _have_pm winget; then _run_allow_fail "winget install -e --id StrawberryPerl.StrawberryPerl" && return 0; fi
  if _have_pm choco;  then _run_allow_fail "choco install strawberryperl -y" && return 0; fi
  if _have_pm scoop;  then _run_allow_fail "scoop install perl" && return 0; fi
  if _have_pm pacman; then _run_allow_fail "pacman -S --noconfirm perl" || _run_allow_fail "pacman -S --noconfirm mingw-w64-x86_64-perl" && return 0; fi
  if _have_pm apt-get; then _run_allow_fail "sudo apt-get update && sudo apt-get install -y perl" && return 0; fi
  if _have_pm dnf;    then _run_allow_fail "sudo dnf install -y perl" && return 0; fi
  if _have_pm yum;    then _run_allow_fail "sudo yum install -y perl" && return 0; fi
  if _have_pm zypper; then _run_allow_fail "sudo zypper install -y perl" && return 0; fi
  if _have_pm apk;    then _run_allow_fail "sudo apk add perl" && return 0; fi
  if _have_pm brew;   then _run_allow_fail "brew install perl" && return 0; fi
  if _have_pm port;   then _run_allow_fail "sudo port install perl5" && return 0; fi
  return 1
}

RMAP_FILE=""

print_agent_usage() {
  cat <<'USAGE'
Usage:
  ./<this-agent> [-m map.json]

Options:
  -m FILE, --mapping FILE   JSON mapping file used at creation-time (Agent will invert it).
  -h                        Show this help and exit
USAGE
}

# Parse short first
while getopts ":m:h" _opt; do
  case "$_opt" in
    m) RMAP_FILE="$OPTARG" ;;
    h) print_agent_usage; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 2 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; print_agent_usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# Long options pass
while (( $# )); do
  case "$1" in
    --mapping)
      shift
      [[ $# -ge 1 ]] || { echo "--mapping requires a value" >&2; exit 2; }
      RMAP_FILE="$1"
      ;;
    --) shift; break;;
    *) break;;
  esac
  shift
done

# Only enforce jq/perl if the user provides -m/--mapping at reconstruction time.
ensure_agent_mapping_deps_if_needed() {
  if [[ -z "${RMAP_FILE:-}" ]]; then return 0; fi
  if [[ ! -f "$RMAP_FILE" ]]; then echo "Mapping file not found: $RMAP_FILE" >&2; exit 2; fi

  if ! have jq; then
    echo "Missing dependency: jq"
    if ask_yes_no "Attempt to install jq now? [y/N]" "n"; then
      if _attempt_install_jq; then
        if is_windows; then
          echo "restarting window is required! on the next usage as the windows PATH does not updates with out restating."
        fi
      else
        echo "Auto-install failed. Please install jq and re-run."; exit 2
      fi
    else
      echo "jq is required with -m/--mapping. Aborting."; exit 2
    fi
  fi

  if ! have perl; then
    echo "Missing dependency: perl"
    if ask_yes_no "Attempt to install Perl now? [y/N]" "n"; then
      if _attempt_install_perl; then
        if is_windows; then
          echo "restarting window is required! on the next usage as the windows PATH does not updates with out restating."
        fi
      else
        echo "Auto-install failed. Please install Perl and re-run."; exit 2
      fi
    else
      echo "Perl is required with -m/--mapping. Aborting."; exit 2
    fi
  fi
}

# Inverse mapping stream filter:
# The payload stored in this Agent may have been forward-mapped at creation
# (sensitive -> placeholder). When reconstructing with -m, we reverse that
# (placeholder -> sensitive). This emits a temp Perl program tailored to the file.
inverse_map_stream() {
  # Usage: inverse_map_stream <file_rel>
  # Reads stdin, writes stdout with reverse substitutions for that file if RMAP_FILE set.
  local rel="$1"
  if [[ -z "${RMAP_FILE:-}" ]]; then
    cat
    return 0
  fi

  ensure_agent_mapping_deps_if_needed

  local tmp
  tmp="$(mktemp)"
  {
    echo 'use strict; use warnings; binmode STDIN; binmode STDOUT; undef $/; $_=<STDIN>;'
    jq -r --arg f "$rel" '
    (.map // [])
    | map(select(type=="object"))
    | map({scope: (.scope // "."), list: (.list // [])})
    | map(select(.list | type=="array"))
    | ($f | tostring | ltrimstr("./")) as $f
    | map(select(
        (.scope | tostring | ltrimstr("./")) as $s
        | ($s == "" or $s == "." or ($f == $s) or ($f | startswith(($s + "/"))))
      ))
    | map(
        .list[] | objects | to_entries[]
        | {from: (.key|tostring), to: (.value|tostring)}
      )
    | sort_by(-(.to|length))
    | .[]
    | "s|\\Q" + (.to|gsub("\\|";"\\|")) + "\\E|" + (.from|gsub("\\|";"\\|")) + "|g;"
  ' "$RMAP_FILE" || { echo "Invalid mapping file format (expected .map to be an array of objects)."; rm -f "$tmp"; exit 2; }
    echo 'print $_;'
  } > "$tmp"

  perl "$tmp"
  rm -f "$tmp"
}

FILES_TO_WRITE=()
EOH

# Prepare the file list inside the Agent so it knows what to reconstruct.
{
    echo "FILES_TO_WRITE=("
    for file_rel in "${INCLUDED_FILES[@]}"; do
        printf '  "%s"\n' "$file_rel"
    done
    echo ")"
    echo
} >> "$AGENT_FILE"

# ------------- Tree printer & overwrite logic -------------
# The Agent prints an ASCII tree of files-to-write and asks a global overwrite question.
# It tracks directories and children to render a nice 'tree' without external deps.
cat <<'EOH' >> "$AGENT_FILE"
build_tree_data() {
    declare -gA CHILDREN=()
    declare -gA IS_DIR=()
    IS_DIR["."]=1

    local f d base parent

    for f in "${FILES_TO_WRITE[@]}"; do
        f="${f#./}"
        d="$(dirname "$f")"
        d="${d#./}"
        base="$(basename "$f")"

        if [[ -n "$d" && "$d" != "." ]]; then
            local path=""
            IFS='/' read -r -a parts <<< "$d"
            for part in "${parts[@]}"; do
                [[ -z "$part" || "$part" == "." ]] && continue
                if [[ -z "$path" ]]; then
                    path="$part"
                else
                    path="$path/$part"
                fi
                IS_DIR["$path"]=1
            done
            parent="$d"
        else
            parent="."
        fi

        CHILDREN["$parent"]="${CHILDREN[$parent]-}${base}"$'\n'
    done

    local dir parent_dir name
    for dir in "${!IS_DIR[@]}"; do
        [[ "$dir" == "." ]] && continue
        parent_dir="$(dirname "$dir")"
        parent_dir="${parent_dir#./}"
        [[ -z "$parent_dir" ]] && parent_dir="."
        name="$(basename "$dir")"
        CHILDREN["$parent_dir"]="${CHILDREN[$parent_dir]-}${name}/"$'\n'
    done
}

print_dir() {
    local dir="$1"
    local prefix="$2"

    dir="${dir#./}"
    [[ -z "$dir" ]] && dir="."

    local content="${CHILDREN[$dir]-}"
    mapfile -t lines < <(printf '%s' "$content" | tr -d '\r' | sed '/^$/d' | sort)

    local all=()
    local dirs=()
    local files=()
    local entry
    for entry in "${lines[@]}"; do
        if [[ "$entry" == */ ]]; then
            dirs+=("${entry%/}")
        else
            files+=("$entry")
        fi
    done
    IFS=$'\n' read -r -d '' -a dirs < <(printf '%s\n' "${dirs[@]}" | sort && printf '\0')
    IFS=$'\n' read -r -d '' -a files < <(printf '%s\n' "${files[@]}" | sort && printf '\0')
    all=("${dirs[@]/%//}" "${files[@]}")

    local count="${#all[@]}"
    local i=0
    for ((i=0;i<count;i++)); do
        entry="${all[$i]}"
        local is_dir=0
        [[ "$entry" == */ ]] && is_dir=1
        local name="${entry%/}"

        local is_last=0
        (( i == count-1 )) && is_last=1
        local branch="├── "
        local next_prefix="${prefix}│   "
        if (( is_last )); then
            branch="└── "
            next_prefix="${prefix}    "
        fi

        if (( is_dir )); then
            echo "${prefix}${branch}${name}/"
            local child_key
            if [[ "$dir" == "." ]]; then
                child_key="$name"
            else
                child_key="$dir/$name"
            fi
            print_dir "$child_key" "$next_prefix"
        else
            echo "${prefix}${branch}${name}"
        fi
    done
}

print_tree_ascii() {
    build_tree_data
    echo "."
    print_dir "." ""
}

PROJECT_NAME="$(basename "$(pwd)")"
TIMESTAMP="$(date +"%H:%M:%S %d/%m/%Y - %A")"

echo "Agent metadata"
echo "--------------"
echo "Project   : ${PROJECT_NAME}"
echo "Timestamp : ${TIMESTAMP}"
echo "Files to write:"
print_tree_ascii
echo

OVERWRITE_ALL=0
read -r -p "Proceed and overwrite all existing files without prompting? [y/N] " _ans
case "${_ans}" in
  y|Y) OVERWRITE_ALL=1 ;;
  *) OVERWRITE_ALL=0 ;;
esac

maybe_overwrite() {
    local filepath="$1"
    if [ "$OVERWRITE_ALL" -eq 1 ]; then
        return 0
    fi
    if [ -e "$filepath" ]; then
        printf "File %s already exists. Overwrite? [y/N] " "$filepath"
        read -r ans
        case "$ans" in
            y|Y) return 0 ;;
            *) echo "Skipping $filepath"; return 1 ;;
        esac
    fi
    return 0
}
EOH

# -------------------------
# Emit file payloads
# For each included file:
#   - Optionally forward-map its content (Perl rules) before base64 encoding.
#   - Embed the base64 payload into the Agent.
#   - At reconstruction time:
#       * If user supplies -m, pipe decoded content through inverse_map_stream to restore originals.
#       * Otherwise, write as-is.
# Sorting by rule length avoids partial-match corruption.
# -------------------------
for file_rel in "${INCLUDED_FILES[@]}"; do
    {
        dirpath="$(dirname "$file_rel")"
        echo "maybe_overwrite \"$file_rel\" && { mkdir -p \"$dirpath\";"

        if [[ $MAPPING_ENABLED -eq 1 ]]; then
            fwd_pl="$(make_forward_perl_for_file "$file_rel")"
            echo "  # content below was FORWARD-mapped before encoding at creation-time"
            echo "  if [[ -n \"\${RMAP_FILE:-}\" ]]; then"
            echo "    base64 --decode <<'FILE' | inverse_map_stream \"$file_rel\" > \"$file_rel\""
            perl "$fwd_pl" < "$PROJECT_ROOT/$file_rel" | base64 --wrap=0
            echo
            echo "FILE"
            echo "  else"
            echo "    base64 --decode <<'FILE' > \"$file_rel\""
            perl "$fwd_pl" < "$PROJECT_ROOT/$file_rel" | base64 --wrap=0
            echo
            echo "FILE"
            echo "  fi"
            rm -f "$fwd_pl"
        else
            echo "  if [[ -n \"\${RMAP_FILE:-}\" ]]; then"
            echo "    base64 --decode <<'FILE' | inverse_map_stream \"$file_rel\" > \"$file_rel\""
            base64 --wrap=0 "$PROJECT_ROOT/$file_rel"
            echo
            echo "FILE"
            echo "  else"
            echo "    base64 --decode <<'FILE' > \"$file_rel\""
            base64 --wrap=0 "$PROJECT_ROOT/$file_rel"
            echo
            echo "FILE"
            echo "  fi"
        fi

        echo "  echo \"Written $file_rel\""
        echo "}"
    } >> "$AGENT_FILE"
done

echo 'echo "Project reconstruction complete."' >> "$AGENT_FILE"
chmod +x "$AGENT_FILE"
echo "Generated $AGENT_FILE with ${#INCLUDED_FILES[@]} file(s)."

# -------------------------
# Save .ai_config
# Persist:
#   - metadata (project name, timestamp, chosen agent name)
#   - final tree (as escaped text)
#   - what the user chose to include/exclude during interactive walk
# This provides a reproducible record of selection decisions.
# -------------------------
agent_dir="$(dirname "$AGENT_FILE")"
agent_base="$(basename "$AGENT_FILE")"
agent_stem="${agent_base%.*}"          CONFIG_FILE="${agent_dir}/${agent_stem}.ai_config"
mkdir -p "$agent_dir"

mapfile -t __files_sorted < <(printf '%s\n' "${INCLUDED_FILES[@]}" | sort)

declare -A __DIRS=()
for f in "${__files_sorted[@]}"; do
    d="$(dirname "$f")"
    if [[ "$d" != "." ]]; then
        while [[ "$d" != "." && -n "$d" ]]; do
            __DIRS["$d"]=1
            d="$(dirname "$d")"
        done
    fi
done
mapfile -t __dir_list < <(printf '%s\n' "${!__DIRS[@]}" | sort)

{
    echo "."
    for f in "${__files_sorted[@]}"; do
        if [[ "$(dirname "$f")" == "." ]]; then
            echo "  $(basename "$f")"
        fi
    done
    for d in "${__dir_list[@]}"; do
        slashes="${d//[^\/]/}"
        depth=$(( ${#slashes} + 1 ))
        indent=""
        for ((i=0;i<depth;i++)); do indent+="  "; done
        echo "${indent}${d}/"
        for f in "${__files_sorted[@]}"; do
            if [[ "$(dirname "$f")" == "$d" ]]; then
                echo "${indent}  $(basename "$f")"
            fi
        done
    done
} > .__tree_tmp__

# Escape the ASCII tree so it can live safely inside JSON (preserve newlines).
TREE_ESCAPED="$(sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g' .__tree_tmp__)"
rm -f .__tree_tmp__

GEN_PROJECT_NAME="$(basename "$PROJECT_ROOT")"
GEN_TIMESTAMP="$(date +"%H:%M:%S %d/%m/%Y - %A")"

{
    printf '{\n'
    printf '  "metadata": {\n'
    printf '    "project_name": "%s",\n' "$GEN_PROJECT_NAME"
    printf '    "timestamp": "%s",\n' "$GEN_TIMESTAMP"
    printf '    "agent_name": "%s",\n' "$agent_base"
    printf '    "files_tree": "%s"\n' "$TREE_ESCAPED"
    printf '  },\n'
    printf '  "include": [\n'
    first=1
    for key in "${!CHOICE_INCLUDE[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            printf ',\n'
        fi
        printf '    "%s"' "$key"
    done
    printf '\n  ],\n  "exclude": [\n'
    first=1
    for key in "${!CHOICE_EXCLUDE[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            printf ',\n'
        fi
        printf '    "%s"' "$key"
    done
    printf '\n  ]\n}\n'
} > "$CONFIG_FILE"

echo "Saved selections to $CONFIG_FILE"
[[ $MAPPING_ENABLED -eq 1 ]] && echo "Mapping applied from: $MAPPING_FILE (ignored folders respected)."
