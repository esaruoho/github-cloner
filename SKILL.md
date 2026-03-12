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

# Get fork count
gh api repos/owner/repo -q '.forks_count'
```

**Display to user:**
```
Repository: owner/repo
- Open issues: X
- Closed issues: Y
- Open PRs: A
- Merged PRs: B
- Forks: F
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

Question 5: "A Fork on the Road?" (Only show if forks > 0! Show count.)
- "Yes — analyze all F forks for unique changes" - Compare each fork against upstream to find divergent work
- "Top 10 most recently updated forks" - Analyze only the most active forks
- "Skip fork analysis" - Don't analyze forks
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

# 9. If "A Fork on the Road" selected:
# Fetch all forks with metadata
gh api repos/owner/repo/forks --paginate \
  --jq '.[] | {full_name, owner: .owner.login, default_branch, pushed_at, updated_at, stargazers_count, forks_count}' \
  > /tmp/repo-analysis/forks.json

# For each fork, compare against upstream's default branch.
# This reveals commits in the fork that are NOT in upstream — the unique work.
# Replace <default_branch> with the repo's actual default branch (e.g. main, master).
for fork in $(gh api repos/owner/repo/forks --paginate --jq '.[].full_name'); do
  fork_owner=$(echo "$fork" | cut -d'/' -f1)
  fork_branch=$(gh api "repos/$fork" --jq '.default_branch' 2>/dev/null)

  # Compare: what does the fork have that upstream doesn't?
  gh api "repos/owner/repo/compare/<default_branch>...${fork_owner}:${fork_branch}" \
    --jq '{
      fork: "'"$fork"'",
      status: .status,
      ahead_by: .ahead_by,
      behind_by: .behind_by,
      total_commits: .total_commits,
      files_changed: [.files[]? | .filename],
      commits: [.commits[]? | {sha: .sha[0:7], message: .commit.message, author: .commit.author.name, date: .commit.author.date}]
    }' 2>/dev/null
done > /tmp/repo-analysis/fork-comparisons.json
```

**Note on fork comparison:** The compare API has a limit of ~250 commits. For forks that have diverged significantly, the API will return `"status": "diverged"` with truncated results. In these cases, note the divergence but don't try to enumerate every commit — summarize at a high level instead.

### Step 5: Analyze Data

Analyze the collected data for:

**5.1 Contributor Patterns**
- Who are the top 5-10 contributors?
- What areas do they focus on?
- What's their commit message style?

**CRITICAL: Use real names, never invent them.** Look up each contributor's real name via `gh api users/<login> -q '.name'`. GitHub handles do NOT reliably map to real names (e.g., `kaneel` = Guillaume Richard, not "Chris"; `krplata` = Krystian Plata, not "Kuba"). If the API returns null for `.name`, use the GitHub handle only — do NOT guess a name.

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

**5.7 A Fork on the Road (if fork analysis selected)**

Analyze the fork comparison data to answer:
- **Which forks have unique work?** (ahead_by > 0) — these are the interesting ones
- **What did they change?** Summarize the files changed and commit messages per fork
- **Are there patterns?** Multiple forks fixing the same thing suggests an unaddressed upstream issue
- **Stale vs. active?** Use `pushed_at` to distinguish active forks from abandoned ones
- **Could any of this be upstreamed?** Flag changes that look like bug fixes, feature additions, or compatibility patches that the upstream repo might benefit from

Categorize each fork with unique work as one of:
- **Feature fork** — adds new functionality not in upstream
- **Fix fork** — patches bugs or compatibility issues
- **Customization fork** — adapts the project for a specific use case
- **Abandoned experiment** — has unique commits but no recent activity
- **Mirror/unchanged** — identical to upstream (ahead_by = 0)

For forks marked as "Feature fork" or "Fix fork", look more closely at the commit messages and changed files to summarize what they actually did. These are the hidden gems — work that exists in the ecosystem but hasn't made it back upstream.

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

## A Fork on the Road
<!-- Generated by fork analysis. Shows forks with unique work not in upstream. -->

<If fork analysis was performed, include this section. Otherwise omit.>

**F forks analyzed — N have unique changes.**

### Forks with Unique Work

| Fork | Type | Ahead By | Last Pushed | Summary |
|------|------|----------|-------------|---------|
| @fork_owner | Feature fork | +12 commits | 2024-01-15 | Added MIDI CC support, new preset system |
| @fork_owner2 | Fix fork | +3 commits | 2023-11-20 | Fixed crash on startup with large files |
| @fork_owner3 | Customization | +7 commits | 2023-09-01 | Adapted for live performance workflow |

### Potential Upstreaming Candidates

<List changes from forks that look like they could benefit the main repo:>
- **@fork_owner2**: Crash fix in `src/loader.lua` — likely a real bug worth cherry-picking
- **@fork_owner**: MIDI CC support could be a valuable feature addition

### Mirror/Unchanged Forks

<List forks with ahead_by = 0:>
- @fork_owner4 (last pushed: 2023-06-01) — identical to upstream
- @fork_owner5 (last pushed: 2022-12-10) — identical to upstream

## Key Contributors
<!-- PR-FED: Updated by PR analysis. When a PR reveals new focus areas or notable work, update this table. -->

**CRITICAL: All names in this table MUST be real names looked up via `gh api users/<login> -q '.name'`. NEVER guess or invent names from GitHub handles.**

| Contributor | GitHub | Focus Areas | Notable PRs |
|-------------|--------|-------------|-------------|
<Populated from contributor analysis. Notable PRs column starts empty, filled by PR analysis.>

## Common Pitfalls
<!-- PR-FED: Grown from PRs that fix recurring problems. Each row is a lesson learned. -->

| Pitfall | Fix | Seen in |
|---------|-----|---------|
<Starts empty. Populated as bug-fix PRs are analyzed.>

## PR Analysis & Skill Growth

This skill is a living document. It was created by github-cloner but is **kept alive by PR analysis**.

**How it grows:**
- Every PR analyzed updates the skill — contributors, active areas, pitfalls, coding patterns
- Techniques extracted from PRs accumulate in `pr-exemplars.md`
- Sections marked `<!-- PR-FED -->` are maintained by the PR analysis pipeline

**Modules that power this:**

| Module | Path | Purpose |
|--------|------|---------|
| PR Writeup Template | `~/.claude/skills/pr-writeup-template.md` | Problem → Solution format for PR descriptions |
| PR Analysis | `~/.claude/skills/pr-analysis.md` | Read, explain, score, and archive PRs; feed back into this skill |
| PR Exemplars | `~/.claude/skills/<repo-name>/pr-exemplars.md` | Every PR archived, techniques indexed |

**To analyze a PR:** Say `read <URL>` or `read PR #<number>`
**To bulk-ingest history:** Re-run `/github-cloner owner/repo`

## Quick Reference

| Item | Value |
|------|-------|
| Primary Language | <language> |
| Default Branch | <branch> |
| License | <license> |
| Last Analyzed | <date> |
```

### Step 6.5: Initialize PR Analysis Pipeline

After generating the skill, also create the PR exemplars file:

Create `~/.claude/skills/<repo-name>/pr-exemplars.md`:

```markdown
# <Repo Name> — PR Archive & Exemplars

> Every merged PR is a record of what was contributed. This file catalogues them all.
> Stand-out PRs (13+/15) are spotlighted. Every PR teaches something.
> Managed by the PR Analysis skill (`~/.claude/skills/pr-analysis.md`).

## Techniques Index

| Technique | First seen in | Category |
|-----------|--------------|----------|
<Populated as PRs are analyzed.>

---

<PR entries appear here as they are analyzed.>
```

Then, for each of the top 10-20 most significant merged PRs (largest diff, most comments, or most recent), run the PR analysis pipeline from `~/.claude/skills/pr-analysis.md`:
1. Fetch the PR metadata and diff
2. Produce the breakdown (what it does, changes at a glance, technique, risk)
3. Score it (Craft / Clarity / Courage)
4. Archive it in `pr-exemplars.md`
5. Update the skill's PR-FED sections (Contributors, Common Pitfalls, Active Areas)

This seeds the exemplar library from day one. The skill doesn't launch empty — it launches with the project's best work already catalogued.

### Step 6.6: Generate analysis.json (Machine-Readable)

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
  },

  "forks": {
    "total_count": <n>,
    "analyzed": true|false,
    "forks_with_unique_work": <n>,
    "fork_details": [
      {
        "full_name": "<owner/repo>",
        "owner": "<username>",
        "type": "feature|fix|customization|abandoned|mirror",
        "ahead_by": <n>,
        "behind_by": <n>,
        "last_pushed": "<ISO-8601 timestamp>",
        "unique_commits": [
          {
            "sha": "<7-char>",
            "message": "<message>",
            "author": "<name>",
            "date": "<timestamp>"
          }
        ],
        "files_changed": ["<file1>", "<file2>"],
        "summary": "<brief description of what this fork adds/changes>",
        "upstreaming_candidate": true|false,
        "upstreaming_reason": "<why this could benefit upstream>"
      }
    ]
  }
}
```

This file follows the schema at `~/.claude/skills/github-cloner/schemas/repo-analysis-schema.json`.

### Step 7: Cleanup

```bash
# Remove temp files
rm -rf /tmp/repo-analysis
```

### Step 9: Report Success

Tell the user:
- Skill created at `~/.claude/skills/<repo-name>/SKILL.md`
- PR archive initialized at `~/.claude/skills/<repo-name>/pr-exemplars.md`
- Machine-readable data at `~/.claude/skills/<repo-name>/analysis.json`
- Top PRs have been analyzed and seeded into the exemplar library
- If fork analysis was performed: **"A Fork on the Road" found N forks with unique work** — summarize the most interesting findings (potential bug fixes, features, etc.)
- **The skill is now alive** — say `read <PR-URL>` to analyze any PR and the skill grows
- How to update the foundation: re-run `/github-cloner owner/repo`

---

## How github-cloner and PR Analysis Work Together

```
github-cloner                          PR analysis
─────────────                          ───────────
Analyzes repo ──→ Creates SKILL.md     "read <URL>" ──→ Fetches PR
                  Creates pr-exemplars.md               Explains diff
                  Seeds top PRs ────────────────────→   Scores quality
                                                        Archives to pr-exemplars.md
                                                        Updates SKILL.md (PR-FED sections)
                                                        ↓
                                                     Skill gets sharper
                                                     Techniques index grows
                                                     Pitfalls table grows
                                                     Contributors sharpen
```

**github-cloner** is the foundation pour — the initial snapshot.
**PR analysis** is the ongoing feed — every PR deepens the skill's understanding.

The skill knows the people. It knows their code. It knows the patterns they use and the mistakes they've fixed. And it gets better every time a PR is analyzed.

## Notes

- **Rate limits**: GitHub API has rate limits. For large repos, the API-only mode is gentler.
- **Private repos**: Requires `gh auth` with appropriate permissions.
- **Updates**: Re-running the skill will overwrite the generated skill with fresh data, but preserves `pr-exemplars.md`.
- **Wiki**: Not all repos have wikis. The skill handles this gracefully.
- **PR analysis module**: `~/.claude/skills/pr-analysis.md` — the full pipeline docs.
- **PR writeup template**: `~/.claude/skills/pr-writeup-template.md` — how to write PR descriptions.
