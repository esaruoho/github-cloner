---
name: github-cloner
description: Analyze a GitHub repository and generate a custom development skill tailored to that project's patterns, conventions, and documentation
version: 1.0.0
tags: [github, repository, skill-generator, onboarding, development]
triggers:
  keywords:
    primary: [github-cloner, repo-skill, repository-skill, clone-repo]
    secondary: [analyze repo, learn repo, onboard repo, generate skill]
  priority: high
---

# GitHub Cloner - Repository Skill Generator

Generate a custom skill for any GitHub repository by analyzing its commits, PRs, issues, wiki, and documentation. The generated skill helps Claude work "in tune" with the project's actual development patterns.

---

## Usage

```
/github-cloner <repository-url>
/github-cloner owner/repo
```

**Examples:**
```
/github-cloner https://github.com/anthropics/claude-code
/github-cloner facebook/react
```

---

## Workflow

When this skill is invoked, follow these steps:

### Step 1: Parse Repository URL

Extract `owner` and `repo` from the input. Accept formats:
- `https://github.com/owner/repo`
- `https://github.com/owner/repo.git`
- `owner/repo`

### Step 2: Get Repository Stats First

Before asking user options, fetch the total counts so the user knows what they're working with:

```bash
# Get issue counts
gh api repos/owner/repo -q '{open_issues: .open_issues_count}'

# Get open issues count
gh issue list --repo owner/repo --state open --limit 1 --json number | jq 'length'
# Or use: gh api repos/owner/repo/issues?state=open&per_page=1 -i | grep -i "link:" to check for pagination

# Get closed issues count
gh issue list --repo owner/repo --state closed --limit 1 --json number | jq 'length'

# Get open PRs count
gh pr list --repo owner/repo --state open --limit 1 --json number | jq 'length'

# Get merged PRs count
gh pr list --repo owner/repo --state merged --limit 1 --json number | jq 'length'

# Better: Get actual totals using search API
gh api "search/issues?q=repo:owner/repo+type:issue+state:open" -q '.total_count'
gh api "search/issues?q=repo:owner/repo+type:issue+state:closed" -q '.total_count'
gh api "search/issues?q=repo:owner/repo+type:pr+state:open" -q '.total_count'
gh api "search/issues?q=repo:owner/repo+type:pr+is:merged" -q '.total_count'
```

**Display to user:**
```
Repository: owner/repo
- Open issues: X
- Closed issues: Y
- Open PRs: A
- Merged PRs: B
```

### Step 3: Ask User Options

Use AskUserQuestion to gather preferences:

```
Question 1: "How should I analyze this repository?"
- "Full clone (Recommended)" - Clone the repo to read file structure, CLAUDE.md, .github/, README, etc.
- "API only" - Use only GitHub API for metadata, issues, PRs, commits. Faster but less thorough.

Question 2: "What commit history timeframe?"
- "3 months (Recommended)" - Recent activity, captures current patterns
- "6 months" - More history for less active repos
- "1 year" - Full year of development patterns

Question 3: "How many issues to fetch?" (Show actual counts!)
- "Last 100" - Quick sampling of recent issues
- "Last 500" - More comprehensive
- "All open (X total)" - All currently open issues
- "All (X open + Y closed)" - Complete issue history

Question 4: "How many PRs to fetch?" (Show actual counts!)
- "Last 100" - Quick sampling of recent PRs
- "Last 500" - More comprehensive
- "All open (A total)" - All currently open PRs
- "All (A open + B merged)" - Complete PR history
```

### Step 4: Collect Data

Run these commands to gather repository data:

```bash
# Create temp directory
mkdir -p /tmp/repo-analysis

# 1. Get repo metadata
gh repo view owner/repo --json name,description,homepageUrl,languages,topics,defaultBranchRef

# 2. Check if wiki exists
gh api repos/owner/repo -q '.has_wiki'

# 3. Fetch issues (adjust --limit based on user choice, use --state as needed)
# For "Last 100":
gh issue list --repo owner/repo --state all --limit 100 \
  --json number,title,body,state,labels,author,createdAt,closedAt

# For "All open":
gh issue list --repo owner/repo --state open --limit 9999 \
  --json number,title,body,state,labels,author,createdAt,closedAt

# For "All":
gh issue list --repo owner/repo --state all --limit 9999 \
  --json number,title,body,state,labels,author,createdAt,closedAt

# 4. Fetch pull requests (adjust --limit based on user choice)
# For "Last 100":
gh pr list --repo owner/repo --state all --limit 100 \
  --json number,title,body,state,author,mergedAt,additions,deletions,changedFiles

# For "All open":
gh pr list --repo owner/repo --state open --limit 9999 \
  --json number,title,body,state,author,mergedAt,additions,deletions,changedFiles

# For "All":
gh pr list --repo owner/repo --state all --limit 9999 \
  --json number,title,body,state,author,mergedAt,additions,deletions,changedFiles

# 5. Fetch recent commits (adjust --since for timeframe)
gh api "repos/owner/repo/commits?since=$(date -v-3m +%Y-%m-%dT%H:%M:%SZ)&per_page=100" \
  --jq '.[] | {sha: .sha[0:7], author: .commit.author.name, date: .commit.author.date, message: .commit.message}'

# 6. Fetch contributors
gh api repos/owner/repo/contributors --jq '.[] | {login, contributions}' | head -20

# If "Full clone" selected:
# 7. Clone repository (shallow)
git clone --depth=1 https://github.com/owner/repo.git /tmp/repo-analysis/repo

# 8. Clone wiki (if exists)
git clone --depth=1 https://github.com/owner/repo.wiki.git /tmp/repo-analysis/wiki 2>/dev/null || echo "No wiki"
```

### Step 5: Analyze Data

Analyze the collected data for:

**5.1 Contributor Patterns**
- Who are the top 5-10 contributors?
- What areas do they focus on?
- What's their commit message style?

**5.2 Commit Conventions**
- Do they use conventional commits (feat:, fix:, chore:)?
- What prefixes/patterns are common?
- How detailed are commit messages?

**5.3 PR Conventions**
- What's the PR title format?
- Do PRs have description templates?
- What's the typical PR scope (files changed)?

**5.4 Issue Patterns**
- What labels are used?
- Are there issue templates?
- How are issues categorized?

**5.5 Documentation (if cloned)**
- README.md - project overview, setup instructions
- CONTRIBUTING.md - contribution guidelines
- CLAUDE.md or .claude/ - AI-specific instructions
- .github/ - templates, workflows, CI/CD
- Wiki pages - detailed documentation

**5.6 Code Structure (if cloned)**
- Primary language(s)
- Directory structure
- Test framework and patterns
- Build/tooling configuration

### Step 6: Generate Skill

Create a new skill at `~/.claude/skills/<repo-name>/SKILL.md` with this structure:

```yaml
---
name: <repo-name>
description: Development skill for <repo-name> - <brief description from repo>
domain: repository-specific
version: 1.0.0
generated: <current timestamp>
source_repo: https://github.com/owner/repo
tags: [<primary language>, <framework if any>, <topics from repo>]
triggers:
  keywords:
    primary: [<repo-name>, <owner>/<repo>]
    secondary: [<key terms from description>]
---

# <Repo Name> Development Skill

> Auto-generated by github-cloner on <date>. Re-run `/github-cloner owner/repo` to update.

## Repository Overview

<Summarize from README: what the project does, who it's for, key features>

## Project Structure

<If cloned, show directory layout with purposes:>
```
repo/
├── src/           # Source code
├── tests/         # Test files
├── docs/          # Documentation
└── ...
```

## Development Conventions

### Commit Messages

<Extracted patterns, e.g.:>
- Uses conventional commits: `feat:`, `fix:`, `docs:`, `chore:`
- Format: `<type>(<scope>): <description>`
- Examples from recent commits:
  - `feat(api): add user authentication endpoint`
  - `fix(ui): resolve button alignment issue`

### Pull Requests

<PR conventions:>
- Title format: <pattern>
- Description template: <if present>
- Typical scope: <N files, M lines>
- Review requirements: <if known>

### Issues

<Issue patterns:>
- Common labels: bug, enhancement, documentation, etc.
- Templates: <if present>

## Key Contributors

<Top contributors and their focus areas:>
| Contributor | Commits | Focus Areas |
|-------------|---------|-------------|
| @username1  | 150     | Core API, authentication |
| @username2  | 89      | Frontend, UI components |

## Coding Patterns

<Patterns observed from commits and code:>
- Error handling approach
- Naming conventions
- Architecture patterns

## Testing

<Testing approach:>
- Framework: <jest, pytest, etc.>
- Test command: `npm test` / `pytest` / etc.
- Coverage requirements: <if known>

## Build & CI/CD

<Build and deployment:>
- Build command: <if known>
- CI: <GitHub Actions, CircleCI, etc.>
- Deployment: <if documented>

## Documentation Resources

<Links and summaries:>
- README: <key sections>
- Wiki: <if present, key pages>
- Contributing guide: <key points>

## AI-Specific Instructions

<From CLAUDE.md if present, or generated guidelines:>
- When working on this repo, follow these conventions...
- Before submitting PRs, ensure...
- Key files to understand: ...

## Quick Reference

| Item | Value |
|------|-------|
| Primary Language | <language> |
| Default Branch | <branch> |
| License | <license> |
| Last Analyzed | <date> |
```

### Step 6.5: Generate analysis.json (Machine-Readable)

Also create `~/.claude/skills/<repo-name>/analysis.json` for other LLMs/agents:

```json
{
  "version": "1.0",
  "generated": "<ISO-8601 timestamp>",
  "source_repo": "https://github.com/owner/repo",

  "repository": {
    "name": "<repo-name>",
    "description": "<from API>",
    "languages": ["<lang1>", "<lang2>"],
    "topics": ["<topic1>", "<topic2>"],
    "default_branch": "<branch>",
    "license": "<license>"
  },

  "contributors": [
    {
      "login": "<username>",
      "contributions": <count>,
      "focus_areas": ["<path1>", "<path2>"],
      "commit_style": "conventional|freeform|mixed",
      "recent_activity": true|false
    }
  ],

  "conventions": {
    "commit_format": "conventional|freeform|angular|custom",
    "commit_prefixes": ["feat", "fix", "chore", "docs"],
    "commit_examples": ["<example1>", "<example2>"],
    "pr_title_format": "<pattern>",
    "pr_has_template": true|false,
    "issue_labels": ["<label1>", "<label2>"]
  },

  "recent_prs": [
    {
      "number": <n>,
      "title": "<title>",
      "body": "<description>",
      "state": "open|closed|merged",
      "author": "<username>",
      "merged_at": "<timestamp>",
      "files_changed": <n>,
      "additions": <n>,
      "deletions": <n>
    }
  ],

  "recent_issues": [
    {
      "number": <n>,
      "title": "<title>",
      "body": "<description>",
      "state": "open|closed",
      "labels": ["<label1>"],
      "author": "<username>"
    }
  ],

  "recent_commits": [
    {
      "sha": "<7-char>",
      "message": "<message>",
      "author": "<name>",
      "date": "<timestamp>"
    }
  ],

  "documentation": {
    "has_readme": true|false,
    "has_contributing": true|false,
    "has_claude_md": true|false,
    "has_wiki": true|false,
    "wiki_pages": ["<page1>", "<page2>"],
    "readme_summary": "<brief summary>"
  },

  "recent_activity": {
    "analysis_period_days": <n>,
    "total_commits": <n>,
    "total_prs_merged": <n>,
    "active_contributors": <n>
  }
}
```

This file follows the schema at `~/.claude/skills/github-cloner/schemas/repo-analysis-schema.json`.

### Step 7: Cleanup

```bash
# Remove temp files
rm -rf /tmp/repo-analysis
```

### Step 8: Report Success

Tell the user:
- Skill created at `~/.claude/skills/<repo-name>/SKILL.md`
- Machine-readable data at `~/.claude/skills/<repo-name>/analysis.json`
- How to use it: when working on that repo, the skill will auto-trigger
- For other LLMs: read analysis.json (see AGENT-PROTOCOL.md)
- How to update: re-run `/github-cloner owner/repo`

---

## Notes

- **Rate limits**: GitHub API has rate limits. For large repos, the API-only mode is gentler.
- **Private repos**: Requires `gh auth` with appropriate permissions.
- **Updates**: Re-running the skill will overwrite the generated skill with fresh data.
- **Wiki**: Not all repos have wikis. The skill handles this gracefully.
