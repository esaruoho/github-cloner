# GitHub Cloner - Agent Protocol

This document describes how any LLM or AI agent can consume and use the output from github-cloner.

## Purpose

The github-cloner skill generates structured data about GitHub repositories. This data can be consumed by:
- Other Claude instances
- Different LLMs (GPT, Gemini, etc.)
- Automated pipelines
- Repository-specific skills

## Core Principle

**Ground AI understanding in real data, not assumptions.**

Instead of guessing how a project works, github-cloner extracts actual:
- Commit message patterns from recent history
- PR conventions from merged PRs
- Contributor focus areas from commit paths
- Documentation from README, CONTRIBUTING, wiki

This allows any AI to work "in tune" with the project's actual development culture.

---

## Output Files

When github-cloner analyzes a repository, it generates files at:

```
~/.claude/skills/<repo-name>/
├── SKILL.md          # Human-readable skill (markdown)
├── analysis.json     # Machine-readable structured data
└── metadata.json     # Quick reference metadata
```

### For AI Consumption

**Primary file: `analysis.json`**

This JSON file contains all extracted data in a structured format that any LLM can parse and reason about.

**Secondary file: `SKILL.md`**

Human-readable markdown that can also be read by LLMs for context. Useful when you want to give an LLM the "full picture" without parsing JSON.

---

## analysis.json Schema

See `schemas/repo-analysis-schema.json` for the formal JSON Schema.

### Top-Level Structure

```json
{
  "version": "1.0",
  "generated": "ISO-8601 timestamp",
  "source_repo": "https://github.com/owner/repo",

  "repository": { },      // Repo metadata
  "contributors": [ ],    // Top contributors
  "conventions": { },     // Extracted patterns
  "recent_prs": [ ],      // Recent pull requests
  "recent_issues": [ ],   // Recent issues
  "recent_commits": [ ],  // Recent commits
  "documentation": { }    // Available docs
}
```

### Section Details

#### repository
```json
{
  "name": "repo-name",
  "description": "Project description",
  "languages": ["TypeScript", "Python"],
  "topics": ["cli", "developer-tools"],
  "default_branch": "main",
  "license": "MIT"
}
```

#### contributors
```json
[
  {
    "login": "username",
    "contributions": 150,
    "focus_areas": ["src/core/", "src/api/"],
    "commit_style": "conventional",
    "recent_activity": true
  }
]
```

#### conventions
```json
{
  "commit_format": "conventional",
  "commit_prefixes": ["feat", "fix", "chore", "docs"],
  "commit_examples": [
    "feat(api): add user authentication",
    "fix(ui): resolve button alignment"
  ],
  "pr_title_format": "type: description",
  "pr_has_template": true,
  "issue_labels": ["bug", "enhancement", "help wanted"]
}
```

#### recent_prs
```json
[
  {
    "number": 123,
    "title": "feat: add new feature",
    "body": "PR description...",
    "state": "merged",
    "author": "username",
    "merged_at": "2025-01-15T10:30:00Z",
    "files_changed": 5,
    "additions": 150,
    "deletions": 30
  }
]
```

#### documentation
```json
{
  "has_readme": true,
  "has_contributing": true,
  "has_claude_md": false,
  "has_wiki": true,
  "wiki_pages": ["Home", "Getting-Started", "API-Reference"],
  "readme_summary": "Brief summary of README content..."
}
```

---

## How to Use This Data

### Pattern 1: Direct Reading

Simply read `analysis.json` and use the data directly:

```
Read the file ~/.claude/skills/<repo-name>/analysis.json
Use the conventions.commit_format to understand commit style
Use contributors to know who works on what
```

### Pattern 2: Merge with Manual Knowledge

If you have manual knowledge about the project (e.g., developer mappings, internal conventions), merge it:

```
1. Read analysis.json for automated data
2. Overlay your manual knowledge:
   - Map "emuell" → "Eduard Müller, maintainer"
   - Map files in "library/renoise/*" → "Renoise API definitions"
3. Generate enriched understanding
```

### Pattern 3: Focus on Specific Data

For development tasks, focus on PRs:

```
1. Read recent_prs from analysis.json
2. Analyze PR descriptions for development context
3. Understand what features are being worked on
4. Use this to inform your own contributions
```

### Pattern 4: Build a Custom Skill

Use analysis.json as the foundation for a repository-specific skill:

```
1. Run github-cloner to generate base data
2. Read analysis.json
3. Add your own sections:
   - Build instructions
   - Testing commands
   - Architecture diagrams
4. Save as a new skill
```

---

## Integration Prompt Template

When giving this data to another LLM, use this prompt structure:

```
I have repository analysis data from github-cloner.

Repository: {repository.name}
Description: {repository.description}

Top Contributors:
{for each contributor}
- {login}: {contributions} commits, focuses on {focus_areas}
{end for}

Development Conventions:
- Commit format: {conventions.commit_format}
- Common prefixes: {conventions.commit_prefixes}
- Example commits: {conventions.commit_examples}

Recent Activity:
- {recent_prs.length} PRs in analysis period
- {recent_commits.length} commits in analysis period

Based on this data, please [your task here].
```

---

## Freshness

The `generated` timestamp indicates when the analysis was performed. For active repositories, consider re-running github-cloner periodically to get fresh data.

```json
{
  "generated": "2025-01-30T10:40:00Z"
}
```

---

## Error Handling

If analysis.json is missing or malformed:
1. Fall back to reading SKILL.md (human-readable)
2. Or re-run `/github-cloner owner/repo` to regenerate

---

## Privacy and Scope

- github-cloner only extracts **public information** from the repository
- For private repos, the user must have appropriate GitHub access
- No sensitive data (secrets, credentials) is extracted
- Focus is on development patterns, not code content
