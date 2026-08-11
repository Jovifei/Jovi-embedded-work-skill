# Configuration v2

Store machine-specific configuration only in `%USERPROFILE%\.codex-memory\config.yaml`. The file is JSON-compatible YAML so Windows PowerShell can parse it without a third-party runtime.

Each active profile may contain:

```json
{
  "schema_version": 2,
  "active_profile": "home",
  "profiles": {
    "home": {
      "memory_root": "D:\\Notes\\my-vault\\codex_memory",
      "approved_memory_roots": ["D:\\Notes\\my-vault\\codex_memory"],
      "allow_document_mirror": true,
      "source_extensions": [".md"],
      "automation": {
        "read_on_session_start": true,
        "remind_on_user_prompt": true,
        "auto_apply_verified_checkpoint": true,
        "auto_apply_document_mirror": true,
        "dry_run_required": true
      },
      "project_mappings": [
        { "memory_id": "main-project", "source_root": "D:\\work\\main-project", "component": "main" },
        { "memory_id": "main-project", "source_root": "D:\\work\\main-project\\bootloader", "component": "bootloader", "mirror_prefix": "bootloader" }
      ]
    }
  }
}
```

`source_root` matching is canonical, case-insensitive, path-boundary aware, and longest-match wins. A child Boot/BL mapping may use the same `memory_id` as its parent. Never store a Vault path, credential, or company-classification exception in a project repository.

`CODEX_MEMORY_ROOT`, when allowed, is the exact approved `memory_root`, not its Vault parent. The root must contain the index, project-memory directory, and template directory markers. Configuration discovery never scans arbitrary disks or selects the first plausible Vault.
