# Fimoni — file monitoring for shared spreadsheet folders

Fimoni watches shared Seafile folders and tells the people who manage them, in plain language in
Mattermost, when files, sheets or columns don't follow the agreed structure. It then follows each
problem until it is fixed. I designed and built it at Max Planck Information and Technology (MaxIT,
which includes the former Max Planck Digital Library), where it guards the spreadsheets that feed a
PostgreSQL database.

The implementation is proprietary to MaxIT. This repository shows what fimoni does and how it is
configured, with an example setup. All names, channel ids and paths are placeholders.

## Features

- **Rules non-programmers can read.** Naming conventions are written as patterns like
  `sales_report_⟨YYYYMMDD⟩` instead of regular expressions. The same definition matches files,
  documents the convention and appears in the messages.
- **Checks down to sheets and columns.** Rules apply to folders, file names, the sheets inside Excel
  files and their column headers. Patterns can refer to each other, e.g. a report's year must match
  its folder's year.
- **Smart event handling.** Seafile's save-by-rename, moves and renames are recognised, and saves
  that only change formatting are ignored.
- **Readable notifications.** Each message says what happened, who did it and whether it was allowed.
  The right people are @-mentioned in the right channel, and a wrong name comes with the allowed
  patterns and examples.
- **Issue tracking.** Every problem becomes an issue that fimoni follows up in the original thread:
  "still open", "resolved, thank you @bob", or "resolved by config change". People can also close
  issues by acknowledging the message, and issue admins can close any of them. A chat command lists
  open issues per person.
- **Content checks.** Actions can run checks on the file, e.g. whether all formulas in a workbook are
  calculated. A failed check is reported and tracked like any other issue.
- **Live configuration.** Config changes take effect while fimoni runs. A broken config is reported
  to the developers and the last working one is restored, so a typo never stops monitoring.
- **Self-documentation.** Fimoni exports the rules as an Excel guide for colleagues and tells the
  database loader which files and sheets go into which table.
- **Self-testing and self-healing.** Fimoni regularly creates and deletes a test file to check the
  whole chain end to end. A supervisor restarts it on a crash or hang, and users are told if
  monitoring is unavailable.
- **Automated delivery.** GitLab CI builds, tests and deploys it as a rootless podman container under
  systemd. A weekly rebuild keeps the image patched.

## How it is configured

Rules live in a nested JSON tree (folder → file → sheet → column). Each level can set which events
to report, whether they are allowed, who to notify, which channel, how urgent, and custom messages.
Lower levels inherit from higher ones.

```jsonc
{
  "file_pattern_id": "f00002",                        // report_⟨YYYY\1⟩_⟨quarter⟩
  "users_2b_notified": ["bob"],
  "notify_on": {
    "insert": { "message": "New quarterly report, it will be loaded tonight." },
    "modify": { "execute": ["check_xlsx_calculated"] },
    "remove": { "is_allowed": false, "priority": "urgent" }
  },
  "sheets": [{ "sheet_pattern_id": "s00001", "notify_on": { "remove": { "is_allowed": false } } }]
}
```

| Pattern | Matches |
|---|---|
| `sales_report_⟨YYYYMMDD⟩` | `sales_report_20261102` |
| `backup_⟨anystring⟩` | `backup_old_data` |
| `total_⟨amount\|value⟩` | `total_amount`, `total_value` |
| `daily_export_⟨today-7⟩` | an export dated within the last 7 days |
| `report_⟨YYYY\1⟩_⟨quarter⟩` | a report whose year matches its folder |

### What the example setup reports

| Event in `exports/2026/` | Result |
|---|---|
| quarterly report deleted | ❌ urgent issue, resolved in the thread once the file is restored |
| report saved without its `Summary` sheet | ❌ missing sheet, tracked until it is back |
| `report_2025_….xlsx` saved into the 2026 folder | ❌ year doesn't match the folder |
| `budget_final.xlsx` added | ❌ personal copy, with a hint where it belongs |
| report re-saved with formatting changes only | nothing |

## Repository contents

| File | Purpose |
|---|---|
| [`dpfimoni_fimoni_config.json`](dpfimoni_fimoni_config.json) | Main config: what to watch, channels, feature switches |
| [`dpfimoni_test_dir_config.json`](dpfimoni_test_dir_config.json) | The rule tree for the example folders |
| [`dpfimoni_test_patternid_config.json`](dpfimoni_test_patternid_config.json) | Reusable named patterns |
| [`dpfimoni_test_user_map.json`](dpfimoni_test_user_map.json) | Seafile → Mattermost users, issue admins |
| [`dpfimoni_fimoni.py`](dpfimoni_fimoni.py) | Entry point |

**Built with** Python, watchdog, SQLite, the Mattermost API (bot, webhooks, websocket), Seafile,
sops, GitLab CI, buildah and podman/systemd.