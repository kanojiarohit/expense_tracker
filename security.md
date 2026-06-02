# Security Guide for AI Agents

Keep security simple, local-first, and consistent with a solo Flutter app.

## Core Rules

- Treat all financial data as private user data.
- Store app data locally with Isar unless the user explicitly changes the product direction.
- Do not add Firebase, analytics, tracking SDKs, remote logging, or backend sync.
- Do not commit secrets, API keys, tokens, certificates, or personal data.
- Do not print sensitive expense data, debt data, or user settings in logs.
- Keep debug logs short, temporary, and remove them before finishing a task.
- Use platform storage and existing app services before adding new dependencies.
- Avoid permissions the feature does not clearly need.

## Code Changes

- Validate and sanitize all user-entered amounts, dates, names, notes, and search text.
- Prefer typed models and structured parsing over string-based shortcuts.
- Handle corrupt, missing, or old local data without crashing.
- Do not weaken platform security settings in Android, iOS, or macOS config files.
- Do not disable certificate checks, sandboxing, app transport security, or backup protections.
- Keep imports and dependencies minimal; avoid packages with unclear maintenance or security posture.

## Agent Workflow

- Review security impact before changing storage, import/export, sharing, backup, or file access.
- Ask before adding any network access, cloud feature, account system, or third-party service.
- If a security tradeoff is unavoidable, document the reason in the final response.
- When unsure, choose the option that exposes less user data.
