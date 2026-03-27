---
name: chezmoi
description: Use when managing dotfiles with chezmoi — adding files, editing managed files, writing templates, handling machine-specific config, running scripts on apply, or working with the chezmoi source directory
---

# chezmoi Dotfiles Management

## Overview

chezmoi manages dotfiles by maintaining a **source state** (`~/.local/share/chezmoi`) that gets applied to the **target state** (home directory). Files in source use special prefixes/suffixes to encode target behavior.

## Core Workflow

```bash
chezmoi add ~/.config/foo    # target → source (start tracking)
chezmoi edit ~/.config/foo   # open source file in $EDITOR
chezmoi diff                 # preview what apply would change — run BEFORE apply
chezmoi apply                # source → target (write to home dir)
chezmoi update               # git pull + apply (multi-machine sync)
chezmoi cd                   # shell in source dir (for git ops)
chezmoi status               # pending changes summary
chezmoi data                 # show all template variables
chezmoi cat ~/.config/foo    # show rendered template (no write)
chezmoi execute-template     # test/debug template fragments
chezmoi managed              # list all managed files
chezmoi unmanaged            # list files NOT managed by chezmoi
```

**Always run `chezmoi diff` before `chezmoi apply`** to preview changes. Apply overwrites target files silently.

## File Naming Conventions

Source filenames encode behavior through prefixes/suffixes. Multiple prefixes can be combined.

### Common Prefixes

| Prefix | Effect | Example |
|--------|--------|---------|
| `dot_` | Hidden file (`dot_` → `.`) | `dot_gitconfig` → `.gitconfig` |
| `private_` | Remove group/world perms | `private_dot_ssh/` |
| `executable_` | Set executable bit | `executable_script.sh` |
| `run_` | Execute as script on apply | `run_install.sh` |
| `run_once_` | Execute script only once (tracked by content hash) | `run_once_bootstrap.sh` |
| `run_onchange_` | Execute when file contents change | `run_onchange_packages.sh` |
| `before_` | Combined with `run_`: runs before directory update | `before_run_backup.sh` |
| `after_` | Combined with `run_`: runs after directory update | `after_run_reload.sh` |
| `create_` | Create only if absent | `create_dot_hushlogin` |
| `exact_` | **Deletes any file in target dir NOT tracked in source** (data loss risk) | `exact_dot_config/` |
| `encrypted_` | Encrypt file (requires age/gpg) | `encrypted_dot_netrc` |
| `symlink_` | Create symlink | `symlink_dot_vim` |
| `modify_` | Script that modifies existing file (reads stdin, writes stdout) | `modify_dot_gitconfig` |
| `remove_` | Delete this file/dir | `remove_dot_old` |
| `empty_` | Keep even if empty | `empty_dot_gitkeep` |
| `literal_` | Stop prefix parsing | `literal_run_example` |

### Suffix

| Suffix | Effect |
|--------|--------|
| `.tmpl` | Process as Go template |

**Combining**: `private_dot_ssh/` = hidden + private permissions. Order matters: prefixes apply left-to-right.

## Templates

### Key Variables

```
.chezmoi.hostname       # machine hostname
.chezmoi.os             # "linux", "darwin", "windows"
.chezmoi.arch           # "amd64", "arm64"
.chezmoi.username       # current user
.chezmoi.homeDir        # home directory path
.chezmoi.sourceDir      # source state path
.chezmoi.group          # primary group
```

Custom data from `~/.config/chezmoi/chezmoi.toml`:
```toml
[data]
  email = "me@example.com"
  work = false
```

Accessed as `{{ .email }}`, `{{ .work }}`.

### Template Patterns

**Machine-specific config:**
```
[user]
  email = {{ if eq .chezmoi.hostname "work-laptop" }}me@corp.com{{ else }}me@home.com{{ end }}
```

**OS-specific block:**
```
{{ if eq .chezmoi.os "darwin" }}
export BROWSER=open
{{ end }}
```

**Prompt on first init (in `chezmoi.toml.tmpl`):**
```
[data]
  email = {{ promptString "email" | quote }}
```
Use `| quote` to wrap string values in TOML-safe quotes. Use `| toJson` for complex types.

**Shared templates** — store in `.chezmoitemplates/` and include:
```
{{ template "common-aliases" . }}
```

**Debug a template:**
```bash
chezmoi cat ~/.gitconfig               # see rendered output
echo '{{ .chezmoi.os }}' | chezmoi execute-template
```

## Common Operations

**Convert existing file to template:**
```bash
chezmoi chattr +template ~/.gitconfig
# or rename: dot_gitconfig → dot_gitconfig.tmpl
```

**Re-sync after editing target directly:**
```bash
chezmoi add ~/.gitconfig   # pulls current file back into source
```

**Check what's managed:**
```bash
chezmoi managed
chezmoi unmanaged
```

**Init on a new machine:**
```bash
chezmoi init --apply https://github.com/USERNAME/dotfiles
```

**Ignore files:**
Add patterns to `.chezmoiignore` in the source root (gitignore syntax).

## 1Password Integration

chezmoi integrates with 1Password via the `op` CLI to pull secrets into templates.

### Setup

```bash
op account add --address $SUBDOMAIN.1password.com --email $EMAIL
eval $(op signin --account $SUBDOMAIN)
```

Biometric authentication eliminates manual sign-in. By default chezmoi verifies session tokens and prompts if expired. To error instead of prompting, set `onepassword.prompt = false` in `chezmoi.toml`.

### Template Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `onepasswordRead` | `op read $URL` — simplest, use Secret References | `{{ onepasswordRead "op://vault/item/field" }}` |
| `onepassword` | Full item as JSON | `{{ (index (onepassword "$UUID").fields 1).value }}` |
| `onepasswordDetailsFields` | Fields indexed by label — easier than `onepassword` | `{{ (onepasswordDetailsFields "$UUID").password.value }}` |
| `onepasswordItemFields` | Additional/custom item fields | `{{ (onepasswordItemFields "$UUID").myfield.value }}` |
| `onepasswordDocument` | Retrieve a document by UUID | `{{- onepasswordDocument "$UUID" -}}` |

**Prefer `onepasswordRead` with Secret References** (`op://vault/item/field`) — they're stable, readable, and work across vaults.

**Debug:** `chezmoi execute-template '{{ onepasswordItemFields "$UUID" | toJson }}'`

### Operational Modes (`chezmoi.toml`)

```toml
[onepassword]
  mode = "account"   # default — full desktop app integration
  # mode = "connect"   # requires OP_CONNECT_HOST + OP_CONNECT_TOKEN
  # mode = "service"   # requires OP_SERVICE_ACCOUNT_TOKEN
```

- **account** (default): Full 1Password CLI with desktop app. Errors if service account env vars are set.
- **connect**: 1Password Connect server. No `onepasswordDocument`, single account only.
- **service**: Service account token. Single account only, no connect vars allowed.

### Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using UUID instead of Secret Reference | Prefer `op://vault/item/field` with `onepasswordRead` — UUIDs are opaque and break on vault migration |
| `onepasswordDocument` in connect/service mode | Not available — use account mode or store docs differently |
| Token not set — apply fails silently | Run `eval $(op signin)` or set `OP_SERVICE_ACCOUNT_TOKEN` before `chezmoi apply` |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Editing target file, then running `apply` — overwrites your edit | Either `chezmoi edit` + apply, or edit target then `chezmoi add` to re-sync |
| Forgetting `.tmpl` suffix — template syntax appears literally | Rename source file to add `.tmpl`, or `chezmoi chattr +template` |
| `run_once_` script re-running after modify | chezmoi tracks by content hash — change file content to re-trigger; delete `~/.local/share/chezmoi/.chezmoistate.boltdb` to reset ALL run-once history |
| `exact_` deleting unexpected files | Chezmoi **removes** any file in the target dir not present in source — only use when chezmoi fully owns that directory |
| Template errors not shown until apply | Use `chezmoi cat` or `chezmoi execute-template` to test first |
