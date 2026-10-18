# claude-skills

A Claude Code plugin marketplace containing my personal skills.

## Install

```
/plugin marketplace add mkmiecik14/claude-skills
/plugin install mattk-tools@claude-skills
```

Pull updates later with `/plugin marketplace update claude-skills`.

## Layout

```
.claude-plugin/marketplace.json   # lists the plugins in this repo
plugins/mattk-tools/
  .claude-plugin/plugin.json      # plugin manifest
  skills/<skill-name>/SKILL.md    # one folder per skill
```

## Developing

Test the plugin straight from this working copy without installing it:

```
claude --plugin-dir ./plugins/mattk-tools
```

Restart the session to pick up edits. Bump `version` in `plugin.json` when releasing changes.
