# Company Safety Policy

The `company` profile is fail-closed. Without an approved local `memory_root`, it may only stage policy-allowed, sanitized Markdown locally. It must not synchronize to a personal vault, enable snapshots, retain raw logs, or create source excerpts unless all corresponding profile gates are explicitly true.

Always reject `.env`, credentials, certificate or key files, database URIs, raw business records, unsupported formats, and full logs. Store only bounded conclusions, relative paths, hashes, and verification summaries. Treat staging as a local cache, not as authorization for cross-device or personal-data transfer.

`07-技术沉淀/` is reserved for genuinely reusable, de-identified knowledge. Require an explicit user confirmation before promoting company-derived material there. Obsidian is a memory projection, not an approved backup system.
