# Agent Compatibility

This skill is **agent-neutral**. Nothing in the workflow depends on a specific
assistant — it drives standard host tooling (ESP-IDF, esptool, shell/PowerShell
scripts) and edits a normal ESP-IDF project. Any coding agent that can read
files, run shell commands, and edit code can execute it.

Throughout the skill docs, **"the agent"** means whichever assistant is running
it (Claude, Codex, WorkBuddy, Trae, Qoder, or any other).

## Supported agents

| Agent      | How to install / trigger                                              |
|------------|----------------------------------------------------------------------|
| Claude     | Place the folder under `~/.claude/skills/`. Triggers by description.  |
| Codex      | See `agents/openai.yaml`. Reference with `$esp32-s3-2-8-screen-module`.|
| WorkBuddy  | Place under the agent's skills/extensions dir; triggers by description.|
| Trae       | Place under the agent's skills dir; triggers by description.          |
| Qoder      | Place under the agent's skills dir; triggers by description.          |
| Others     | Point the agent at `SKILL.md` as the entry document.                  |

The exact skills directory differs per client and can change between versions.
The stable rule: **make `SKILL.md` discoverable to the agent and let it match on
the description.** If a client has no auto-discovery, the user can name the
skill folder explicitly and ask the agent to follow `SKILL.md`.

## Per-agent manifests

Optional interface hints live under `agents/`:

- `agents/openai.yaml` — Codex display name / default prompt.
- `agents/generic.yaml` — portable display metadata other clients can read or
  adapt. Use this as the template when onboarding a new agent.

These files only affect presentation (display name, default prompt). The skill
runs identically with or without them.

## Adding a new agent

1. Copy `agents/generic.yaml` to `agents/<agent>.yaml`.
2. Adjust `display_name`, `short_description`, `default_prompt`.
3. If the client needs a specific manifest schema, translate the same three
   fields into it — do not fork the skill logic.
4. Add a row to the table above.

## What stays constant across agents

- The natural-language interaction contract (`references/interaction.md`).
- The setup / first-boot / customization / HID / troubleshooting workflows
  (`references/workflows.md`).
- Board facts and edit boundaries (`references/project-map.md`).
- The on-screen app + Nothing-style guidance (`references/onscreen-apps.md`,
  `references/nothing-style.md`).
