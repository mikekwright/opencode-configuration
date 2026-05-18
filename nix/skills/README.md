# Bundled opencode skills

These skills are bundled with the packaged opencode wrapper instead of living in the project-local `.opencode/` tree.

## Layout

```text
nix/
  skills/
    <skill-name>/
      SKILL.md
      notes.md        # optional
      examples.md     # optional
```

## Conventions

- One skill per folder.
- The folder name should match the skill frontmatter `name`.
- Only `SKILL.md` is discovered as a skill.
- Keep notes, templates, and examples named something else.
- Write descriptions with concrete trigger keywords and an explicit `Use ONLY when...` scope when the skill should stay narrow.

## Packaging

- `nix/packages/opencode-skills.nix` copies this tree to `$out/share/opencode/skills`.
- The wrapped opencode package adds that directory to `skills.paths` through `OPENCODE_CONFIG_CONTENT`.
- Home Manager, NixOS, and `nix run .` all use the same bundled skill package.

## Copyable template

```markdown
---
name: my-skill
description: my-tool, my-file, my-command. Use ONLY when editing or troubleshooting ...
---

# My Skill

## When to use

- ...

## Workflow

1. ...
2. ...

## Validation

- ...
```
