# Learning: Bash Script Patterns for Project Brahmanda

## What

Standard bash scripting patterns and best practices followed in Project Brahmanda for maintainability, reliability, and SRE-grade quality.

## Why

- **Consistency**: All scripts follow the same structure and patterns
- **Maintainability**: Easy to understand, modify, and extend
- **Reliability**: Proper error handling and validation
- **Debuggability**: Clear error messages and organized code
- **Production-Ready**: Follows industry standards for shell scripting

## Script Structure Template

```bash
#!/usr/bin/env bash
#
# script-name.sh - Brief description
#
# Detailed description of what the script does
#
# Usage:
#   ./script-name.sh [options]
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly CONSTANT_NAME="value"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

VARIABLE_NAME="default_value"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print error message and exit
die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Print info message
info() {
  echo "$*"
}

# Print success message
success() {
  echo "✅ $*"
}

# Print warning message
warn() {
  echo "⚠️  WARNING: $*"
}

# Check if command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Prompt user for yes/no confirmation
confirm() {
  local prompt="$1"
  local reply
  read -rp "${prompt} [y/N]: " -n 1 reply
  echo
  [[ $reply =~ ^[Yy]$ ]]
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --option)
        VARIABLE_NAME="$2"
        shift 2
        ;;
      --flag)
        FLAG=true
        shift
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_something() {
  [[ -n "$VARIABLE" ]] || die "Variable is required"
}

# ============================================================================
# MAIN LOGIC FUNCTIONS
# ============================================================================

do_something() {
  info "Doing something..."
  # Implementation
  success "Something done"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
  parse_arguments "$@"
  validate_something
  do_something
}

main "$@"
```

## Core Patterns

### 1. Strict Mode

**Always start with:**
```bash
set -euo pipefail
```

**What it does:**
- `set -e`: Exit on any error (non-zero exit code)
- `set -u`: Exit on undefined variables
- `set -o pipefail`: Pipeline fails if any command fails

### 2. Constants vs Variables

**Constants (readonly):**
```bash
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly API_URL="https://api.example.com"
readonly MAX_RETRIES=3
```

**Variables (mutable):**
```bash
RETRY_COUNT=0
USERNAME=""
VERBOSE=false
```

**Naming Convention:**
- Constants: `UPPER_SNAKE_CASE`
- Variables: `UPPER_SNAKE_CASE` (global), `lower_snake_case` (local)

### 3. Function Structure

**Standard function format:**
```bash
# Brief description of what function does
# Arguments:
#   $1 - Description of first argument
#   $2 - Description of second argument
# Returns:
#   0 on success, 1 on failure
# Sets global variable: VARIABLE_NAME
function_name() {
  local arg1="$1"
  local arg2="${2:-default_value}"  # With default
  
  # Implementation
  
  return 0
}
```

**Key rules:**
- Use `local` for all function-scoped variables
- Document arguments and return values
- Note any global variables set/modified
- Use descriptive names (`validate_ssh_keys` not `check1`)

### 4. Error Handling

**Use die() for fatal errors:**
```bash
[[ -f "$config_file" ]] || die "Config file not found: $config_file"

command -v jq &>/dev/null || die "jq is required but not installed"

result=$(some_command) || die "Command failed"
```

**Check command success:**
```bash
# Good
if some_command; then
  success "Command succeeded"
else
  die "Command failed"
fi

# Better (for single check)
some_command || die "Command failed"
```

**Cleanup on error:**
```bash
TMP_FILE="/tmp/myfile-$$.tmp"
trap "rm -f '$TMP_FILE'" EXIT ERR

# Now temp file is cleaned up even on error
```

### 5. Variable Handling

**Always quote variables:**
```bash
# Good
if [[ -f "$config_file" ]]; then
  cat "$config_file"
fi

# Bad (can break on spaces)
if [[ -f $config_file ]]; then
  cat $config_file
fi
```

**Use [[ ]] instead of [ ]:**
```bash
# Good - supports regex, no word splitting
if [[ "$status" == "active" ]]; then
  info "Service is active"
fi

# Old style (avoid)
if [ "$status" = "active" ]; then
  info "Service is active"
fi
```

**Default values:**
```bash
# Use default if variable empty
output_dir="${OUTPUT_DIR:-./output}"

# Use default if variable unset
port="${PORT-8080}"

# Require variable or fail
: "${REQUIRED_VAR:?Variable REQUIRED_VAR must be set}"
```

### 6. Command Substitution

**Use $() instead of backticks:**
```bash
# Good
current_date=$(date +%Y-%m-%d)
file_count=$(ls -1 | wc -l)

# Old style (avoid)
current_date=`date +%Y-%m-%d`
```

### 7. Test Conditions

**File tests:**
```bash
[[ -f "$file" ]]     # Regular file exists
[[ -d "$dir" ]]      # Directory exists
[[ -e "$path" ]]     # Path exists (file or dir)
[[ -r "$file" ]]     # File is readable
[[ -w "$file" ]]     # File is writable
[[ -x "$file" ]]     # File is executable
[[ -L "$link" ]]     # Is symbolic link
```

**String tests:**
```bash
[[ -z "$str" ]]      # String is empty
[[ -n "$str" ]]      # String is not empty
[[ "$a" == "$b" ]]   # Strings equal
[[ "$a" != "$b" ]]   # Strings not equal
[[ "$str" =~ ^[0-9]+$ ]]  # Regex match
```

**Numeric tests:**
```bash
[[ "$a" -eq "$b" ]]  # Equal
[[ "$a" -ne "$b" ]]  # Not equal
[[ "$a" -lt "$b" ]]  # Less than
[[ "$a" -gt "$b" ]]  # Greater than
[[ "$a" -le "$b" ]]  # Less than or equal
[[ "$a" -ge "$b" ]]  # Greater than or equal
```

**Logical operators:**
```bash
[[ -f "$file" && -r "$file" ]]  # AND
[[ -f "$file" || -d "$file" ]]  # OR
[[ ! -f "$file" ]]               # NOT
```

### 8. User Input

**Reading input:**
```bash
# Simple read
read -rp "Enter name: " name

# Read with timeout (5 seconds)
read -rt 5 -p "Enter value: " value

# Read password (no echo)
read -rsp "Enter password: " password
echo  # New line after password

# Read single character
read -rn 1 -p "Continue? [y/N]: " reply
echo
```

**Confirmation prompts:**
```bash
confirm() {
  local prompt="$1"
  local reply
  read -rp "${prompt} [y/N]: " -n 1 reply
  echo
  [[ $reply =~ ^[Yy]$ ]]
}

# Usage
if confirm "Delete all files?"; then
  rm -rf ./files/
fi
```

### 9. Looping

**Over files:**
```bash
# Good - handles spaces in filenames
while IFS= read -r file; do
  process "$file"
done < <(find . -name "*.txt")

# Or with array
files=( *.txt )
for file in "${files[@]}"; do
  process "$file"
done
```

**Over lines:**
```bash
while IFS= read -r line; do
  echo "Processing: $line"
done < file.txt
```

**With counter:**
```bash
for i in {1..10}; do
  echo "Iteration $i"
done

# Or with C-style
for ((i=0; i<10; i++)); do
  echo "Iteration $i"
done
```

### 10. Arrays

**Declaration and usage:**
```bash
# Declare array
files=("file1.txt" "file2.txt" "file3.txt")

# Append element
files+=("file4.txt")

# Get length
echo "Count: ${#files[@]}"

# Iterate
for file in "${files[@]}"; do
  echo "$file"
done

# Access by index
first="${files[0]}"
last="${files[-1]}"
```

### 11. Exit Codes

**Standard exit codes:**
```bash
exit 0    # Success
exit 1    # General error
exit 2    # Misuse of shell command
exit 126  # Command cannot execute
exit 127  # Command not found
exit 130  # Script terminated by Ctrl+C
```

**Check last exit code:**
```bash
some_command
if [[ $? -eq 0 ]]; then
  success "Command succeeded"
else
  die "Command failed with exit code $?"
fi

# Better - check directly
if some_command; then
  success "Command succeeded"
fi
```

### 12. Output Redirection

**Standard patterns:**
```bash
# Redirect stdout to file
command > output.txt

# Redirect stderr to file
command 2> error.txt

# Redirect both to same file
command &> output.txt

# Redirect both to different files
command > output.txt 2> error.txt

# Append instead of overwrite
command >> output.txt

# Discard output
command &>/dev/null
```

## Project Brahmanda Specific Patterns

### 1. Early Validation

**Check authentication early:**
```bash
main() {
  parse_arguments "$@"
  
  # Validate prerequisites first
  validate_required_inputs
  validate_required_tools
  validate_onepassword_auth  # Check auth BEFORE doing work
  
  # Then do actual work
  do_main_work
}
```

### 2. Idempotency

**Check state before acting:**
```bash
create_something() {
  # Check if already created
  if already_exists; then
    success "Already exists, skipping"
    return 0
  fi
  
  # Create
  info "Creating..."
  perform_creation
  success "Created"
}
```

### 3. User-Friendly Output

**Use emoji for visual clarity:**
```bash
info "📋 Step 1/5: Validating..."
success "✅ Validation complete"
warn "⚠️  WARNING: Data will be erased"
info "🔍 Checking configuration..."
info "ℹ️  Additional information"
```

### 4. 1Password Integration

**Standard pattern:**
```bash
validate_onepassword_auth() {
  [[ -n "$PASSWORD" ]] && return 0  # Skip if already provided
  
  info "🔐 Checking 1Password CLI authentication..."
  
  command_exists op || die "1Password CLI not found"
  op account get &>/dev/null || die "1Password CLI not authenticated. Run: eval \$(op signin)"
  
  success "1Password CLI authenticated"
}

retrieve_secret() {
  PASSWORD=$(op read "op://Vault-Name/Item-Name/field")
  [[ -n "$PASSWORD" ]] || die "Failed to retrieve secret"
}
```

### 5. USB Device Validation

**Safety checks for destructive operations:**
```bash
validate_removable_device() {
  local device="$1"
  
  # Check exists
  lsblk "$device" &>/dev/null || die "Device not found: $device"
  
  # Check is disk, not partition
  local type
  type=$(lsblk -dno TYPE "$device" 2>/dev/null)
  [[ "$type" == "disk" ]] || die "Must be disk device, not partition"
  
  # Check is removable (safety)
  local removable
  removable=$(lsblk -dno RM "$device" 2>/dev/null)
  [[ "$removable" == "1" ]] || die "Device is not removable (RM=0)"
}
```

## Common Pitfalls

### 1. Unquoted Variables

```bash
# WRONG - breaks on spaces
file=$1
cat $file

# CORRECT
file="$1"
cat "$file"
```

### 2. Not Using Local

```bash
# WRONG - pollutes global scope
function process() {
  result=$(do_something)
}

# CORRECT
function process() {
  local result
  result=$(do_something)
}
```

### 3. Ignoring Errors

```bash
# WRONG - continues on error
mkdir /protected/dir
cd /protected/dir

# CORRECT
mkdir /protected/dir || die "Failed to create directory"
cd /protected/dir || die "Failed to change directory"
```

### 4. Word Splitting in Loops

```bash
# WRONG - breaks on spaces in filenames
for file in $(ls *.txt); do
  cat "$file"
done

# CORRECT
while IFS= read -r file; do
  cat "$file"
done < <(find . -name "*.txt")
```

### 5. Using Backticks

```bash
# OLD - harder to nest, less readable
result=`command \`nested\``

# CORRECT
result=$(command $(nested))
```

## Debugging Tips

### Enable Debug Mode

```bash
# At top of script
set -x  # Print commands before execution

# Or run script with debug
bash -x script.sh

# Debug specific section
set -x
complex_function
set +x
```

### Add Debug Function

```bash
DEBUG=false

debug() {
  [[ "$DEBUG" == "true" ]] && echo "DEBUG: $*" >&2
}

# Usage
debug "Variable value: $var"
debug "Entering function: ${FUNCNAME[1]}"
```

### Check Variable Values

```bash
# Print all variables
declare -p

# Print specific variable
declare -p VARIABLE_NAME

# Print function definition
declare -f function_name
```

## Testing Scripts

### Syntax Check

```bash
# Check syntax without running
bash -n script.sh

# Or in script
check_syntax() {
  bash -n "$1" || die "Syntax error in $1"
}
```

### ShellCheck

```bash
# Install shellcheck
apt install shellcheck

# Run
shellcheck script.sh

# In CI/CD
shellcheck scripts/*.sh || exit 1
```

## Git Hooks

### Hook Location

**CRITICAL:** Git doesn't use hooks from `.git/hooks/` if `core.hooksPath` is configured!

```bash
# Check where Git looks for hooks
git config core.hooksPath

# If output is .githooks, Git uses:
#   .githooks/pre-commit  ✅ Active
# NOT:
#   .git/hooks/pre-commit ❌ Ignored
```

**Project Brahmanda uses:**
```bash
core.hooksPath = .githooks
```

This means hooks are versioned in the repository (`.githooks/`) instead of Git's default location (`.git/hooks/`).

### Pre-Commit Hook Pattern

**Simple is better than complex:**

```bash
#!/usr/bin/env bash
set -e

# Check if sensitive file is being modified
if git diff --cached --name-only | grep -q "^sensitive/file.txt$"; then
    STAGED_CONTENT=$(git diff --cached --no-ext-diff "sensitive/file.txt")
    
    # Check if placeholder is still present
    if echo "$STAGED_CONTENT" | grep -q 'PLACEHOLDER_VALUE'; then
        echo "✅ File appears to be template"
    else
        echo "❌ COMMIT BLOCKED: File contains real secrets!"
        exit 1
    fi
fi

exit 0
```

**Why this pattern works:**
- ✅ Checks for presence of placeholder (positive check)
- ✅ Simple logic, hard to get wrong
- ✅ No false positives on unrelated file changes
- ✅ Clear pass/fail conditions

**Anti-pattern to avoid:**
```bash
# DON'T: Complex diff parsing with edge cases
password_diff=$(git diff --cached file.txt | grep '^[+-]password' || true)
if [[ -n "$password_diff" ]]; then
    # Complex logic that can fail...
fi
```

### Debugging Hooks

**When a hook misbehaves:**

1. **Check which hook is active:**
   ```bash
   git config core.hooksPath
   ```

2. **Run hook manually:**
   ```bash
   bash -x .githooks/pre-commit  # Shows execution trace
   ```

3. **Verify hook file location:**
   ```bash
   # Default location
   ls -la .git/hooks/pre-commit
   
   # Custom location (if core.hooksPath set)
   ls -la .githooks/pre-commit
   ```

4. **Test without hook:**
   ```bash
   git commit --no-verify  # Skip hooks temporarily
   ```

**Common mistake:** Debugging `.git/hooks/pre-commit` when Git is actually using `.githooks/pre-commit` due to `core.hooksPath` configuration. Always check which one is active first!

### Setting Up Custom Hook Path

```bash
# Make hooks versioned in repo
git config core.hooksPath .githooks

# Make hooks executable
chmod +x .githooks/pre-commit
```

**Benefits:**
- ✅ Hooks are version controlled
- ✅ All team members get same hooks
- ✅ Easy to update and distribute
- ✅ Works across machines automatically after clone

## References

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Best Practices](https://bertvv.github.io/cheat-sheets/Bash.html)
- [ShellCheck](https://www.shellcheck.net/)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [Git Hooks Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)

---

**Last Updated:** January 5, 2026  
**Applies To:** All bash scripts in Project Brahmanda
