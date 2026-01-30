# Integration Guide: Building on GitHub Cloner

This guide explains how to use github-cloner as a foundation for repository-specific skills, using a concrete example.

## The Problem

When an AI assistant works on a codebase, it often:
- Guesses at commit message conventions
- Doesn't know who the key contributors are
- Misses project-specific patterns
- Lacks context from PRs and issues

## The Solution

**Layer 1: github-cloner** provides automated, fresh data:
- Recent commits, PRs, issues
- Contributor activity
- Extracted conventions

**Layer 2: Your custom skill** adds manual knowledge:
- Developer mappings (username → full name, role)
- Feature areas and categorization
- Build/test instructions
- Project-specific guidelines

Together: An AI that truly understands the project.

---

## Case Study: Renoise Definitions

Let's use [renoise/definitions](https://github.com/renoise/definitions) - a public repository containing LuaCATS definitions for the Renoise Lua API.

### What github-cloner Provides

Running `/github-cloner renoise/definitions` generates:

```json
{
  "repository": {
    "name": "definitions",
    "description": "LuaCATS definitions for the Renoise Lua API",
    "languages": ["Lua"],
    "default_branch": "master"
  },
  "contributors": [
    {"login": "emuell", "contributions": 42},
    {"login": "unlessgames", "contributions": 13},
    {"login": "matt-allan", "contributions": 2}
  ],
  "conventions": {
    "commit_format": "freeform",
    "commit_prefixes": ["fix", "add", "update"]
  },
  "recent_prs": [...],
  "recent_issues": [...]
}
```

### Adding Manual Knowledge

You can extend this with a custom development skill that adds:

```markdown
## Developer Mapping

| GitHub | Name | Focus |
|--------|------|-------|
| @emuell | Eduard Müller | Core maintainer, API definitions |
| @unlessgames | Unless Games | Contributions, fixes |

## Project Structure

- `library/` - Core Lua type definitions
- `library/renoise/` - Renoise-specific API types

## How to Contribute

1. Fork the repository
2. Add or update definitions in `library/`
3. Follow existing naming conventions
4. Submit PR with clear description
```

### The Integration

Your custom skill can now:

1. **Map automated data to manual knowledge:**
   - `emuell` in analysis.json → "Eduard Müller, core maintainer"
   - Files in `library/renoise/` → categorized under "Renoise API"

2. **Get fresh PR/issue context:**
   - Understand what's currently being worked on
   - See recent bug reports and feature requests

3. **Validate conventions:**
   - Confirm commit patterns from actual history

---

## Integration Patterns

### Pattern 1: Merge at Read Time

When your skill is invoked, read both files and merge:

```
1. Read ~/.claude/skills/definitions/analysis.json
2. Read your custom knowledge file
3. For each contributor in analysis.json:
   - Look up in developer mapping
   - Enrich with role, focus areas
4. For each PR in recent_prs:
   - Categorize by feature area based on files changed
```

### Pattern 2: Generate Merged Skill

Run github-cloner, then merge into your skill file:

```markdown
## Key Contributors (auto-updated 2026-01-30)

| Username | Name | Commits (3mo) | Focus Areas |
|----------|------|---------------|-------------|
| @emuell | Eduard Müller | 15 | Core definitions |
| @unlessgames | Unless Games | 5 | Fixes, enhancements |

## Recent Development Context

From recent PRs:
- #42: Update song API definitions
- #38: Fix type annotations for instruments
```

### Pattern 3: Reference Link

Keep skills separate but reference each other:

```markdown
## Automated Analysis

For current contributor activity and PR context, see:
~/.claude/skills/definitions/analysis.json

Re-generate with: `/github-cloner renoise/definitions`
```

---

## Step-by-Step: Adding github-cloner to Your Skill

### Step 1: Run github-cloner

```
/github-cloner owner/your-repo
```

Choose "Full clone" for maximum data.

### Step 2: Locate Generated Files

```
~/.claude/skills/your-repo/
├── SKILL.md
├── analysis.json
└── metadata.json
```

### Step 3: Add Your Manual Knowledge

Create or update your repository-specific skill with sections for:

```markdown
## Developer Mapping

Map GitHub usernames to real identities:

| GitHub | Name | Role |
|--------|------|------|
| @user1 | Full Name | Maintainer |

## Feature Areas

Define your project's feature areas:

**Feature Name**
- Files: `path/to/feature/*`
- Owners: @user1, @user2
- Description: What this feature does

## Build Instructions

How to build, test, and run...

## Integration with github-cloner

This skill uses data from github-cloner for:
- Contributor activity (analysis.json → contributors)
- PR context (analysis.json → recent_prs)
- Convention validation (analysis.json → conventions)

Last updated: [date]
Re-run: `/github-cloner owner/repo`
```

### Step 4: Create Merge Logic (Optional)

If you want automatic merging, add instructions to your skill:

```markdown
## Auto-Enrichment

When reading contributor data from analysis.json, apply these mappings:

GitHub Username → Developer Info:
- emuell → {name: "Eduard Müller", role: "maintainer"}
- unlessgames → {name: "Unless Games", role: "contributor"}

File Path → Feature Area:
- library/renoise/* → "Renoise API"
- library/*.lua → "Core definitions"
```

---

## For Other LLMs

If you're using a different LLM (not Claude Code), you can still use github-cloner data:

1. **Have Claude Code generate the data:**
   ```
   /github-cloner owner/repo
   ```

2. **Copy the generated files** to where your other LLM can access them

3. **Give your LLM these instructions:**
   ```
   Read the file analysis.json which contains:
   - contributors: Top contributors with commit counts and focus areas
   - recent_prs: Recent PRs with titles, descriptions, and authors
   - conventions: Commit and PR conventions used in this repo

   Use this data to understand the project's development patterns.
   ```

---

## Keeping Data Fresh

### Manual Refresh

Re-run periodically:
```
/github-cloner owner/repo
```

### Suggested Frequency

| Repo Activity | Refresh Frequency |
|---------------|-------------------|
| Very active (daily commits) | Weekly |
| Active (weekly commits) | Monthly |
| Low activity | Quarterly |

### Checking Freshness

Look at `generated` timestamp in analysis.json:
```json
{
  "generated": "2026-01-30T10:40:00Z"
}
```

---

## Template: Repository-Specific Skill

Here's a template for creating a skill that integrates with github-cloner:

```markdown
---
name: your-repo-name
description: Development skill for Your Project
---

# Your Project Development Skill

## Overview
What this project does...

## Integration with github-cloner

This skill uses automated data from:
- `~/.claude/skills/your-repo/analysis.json`

Re-generate: `/github-cloner owner/your-repo`

## Developer Mapping

| GitHub | Name | Role |
|--------|------|------|
| @user1 | Name | Role |

## Feature Areas

**Feature 1**
- Files: `path/*`
- Description: ...

**Feature 2**
- Files: `other/path/*`
- Description: ...

## Development Conventions

Based on analysis.json conventions plus manual additions:
- Commit format: [from analysis.json]
- PR requirements: [manual]
- Testing: [manual]

## Build & Run

[Your instructions]

## Recent Context

See analysis.json → recent_prs for current development focus.

Key recent work:
- [Summarize from PRs]
```

---

## Summary

1. **github-cloner provides the foundation**: automated, fresh data from GitHub
2. **Your skill adds the depth**: manual knowledge, mappings, instructions
3. **Together they create**: an AI assistant that truly understands your project

The key insight: **Don't make the AI guess. Give it real data.**
