# Configuration

Store machine-specific configuration only in `%USERPROFILE%\.codex-memory\config.yaml`. This first version deliberately accepts JSON-compatible YAML so PowerShell 5.1 can parse it without a third-party runtime. Do not put personal vault paths in project configuration.

```json
{
  "schema_version": 1,
  "active_profile": "home",
  "profiles": {
    "home": {
      "obsidian_vault_root": "D:\\Notes\\my-obsidian-vault",
      "memory_root": "D:\\Notes\\my-obsidian-vault\\codex_memory",
      "allow_source_excerpt": true,
      "allow_raw_logs": false,
      "allow_snapshot": false,
      "allow_event_content": true,
      "allow_staging_sync": true,
      "allow_personal_sync": true,
      "source_extensions": [".md"]
    }
  }
}
```

Create the `home` profile with `scripts/setup.ps1 -Profile home -VaultRoot <your-vault> -Apply` after the target `codex_memory` directory has its required markers. `OBSIDIAN_VAULT_ROOT` is an optional machine-local alternative to the parameter. The Skill never ships, infers, or reads a personal vault path from a repository.

`CODEX_MEMORY_ROOT`, if supplied, is the `memory_root` itself, never the Obsidian vault parent. It must contain `00-总索引.md`, `03-项目记忆/`, and `06-模板/`; otherwise write-capable modes are blocked. Configuration discovery never scans arbitrary disks or selects the first plausible vault.

Project identifiers resolve in this order: explicit argument, `.project-memory.local.yaml`, safe-to-commit `.project-memory.yaml`, sanitized Git remote leaf, then repository directory name. Project config may contain only `project_id`, `scope`, and `docs_root`; never a vault location, credential, or company classification exception.

