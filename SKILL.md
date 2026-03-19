---
name: github-cloner
description: Analyze a GitHub or GitLab repository and generate a custom development skill tailored to that project's patterns, conventions, and documentation
version: 2.0.0
tags: [github, gitlab, repository, skill-generator, onboarding, development]
triggers:
  keywords:
    primary: [github-cloner, gitlab-cloner, repo-skill, repository-skill, clone-repo]
    secondary: [analyze repo, learn repo, onboard repo, generate skill, glab, gitlab]
  priority: high
---

# GitHub/GitLab Cloner - Repository Skill Generator

Generate a custom skill for any GitHub or GitLab repository by analyzing its commits, PRs/MRs, issues, wiki, and documentation. The generated skill helps Claude work "in tune" with the project's actual development patterns.

**Supports both platforms:**
- **GitHub** via `gh` CLI
- **GitLab** via `glab` CLI

---

## Usage

```
/github-cloner <repository-url>
/github-cloner owner/repo
```

**Examples:**
```
# GitHub
/github-cloner https://github.com/anthropics/claude-code
/github-cloner facebook/react

# GitLab
/github-cloner https://gitlab.com/inkscape/inkscape
/github-cloner https://gitlab.freedesktop.org/mesa/mesa
/github-cloner gitlab:group/subgroup/project
```

---

## Platform Detection & Terminology

Throughout this skill, commands are shown for both platforms. The detected platform determines:

| Concept | GitHub | GitLab |
|---------|--------|--------|
| CLI tool | `gh` | `glab` |
| Code review unit | Pull Request (PR) | Merge Request (MR) |
| Repo targeting | `--repo owner/repo` | `-R owner/repo` (issue/mr) or positional (repo view) |
| JSON output | `--json field1,field2` | `-F json` or `-O json` then pipe to `jq` |
| All states | `--state all` | `--all` |
| Result limit | `--limit N` | `--per-page N` / `-P N` |
| API jq filter | `-q '.field'` | pipe to `jq '.field'` |
| API query params | URL query string `?key=val` | `-F key=val` |
| API pagination | `--paginate` | `--paginate` |
| API path encoding | `repos/owner/repo` | `projects/owner%2Frepo` (slashes URL-encoded) |
| Clone URL | `https://github.com/owner/repo.git` | `https://gitlab.com/group/project.git` |

**GitLab URL-encoding gotcha:** In `glab api`, project paths with slashes must be URL-encoded. `/` becomes `%2F`:
- `my-group/my-project` → `my-group%2Fmy-project`
- `my-group/sub-group/my-project` → `my-group%2Fsub-group%2Fmy-project`

If inside the cloned repo, `glab api` supports `:id` and `:fullpath` placeholders that auto-resolve.

---

## Workflow

When this skill is invoked, follow these steps:

### Step 1: Parse Repository URL and Detect Platform

Extract `owner` and `repo` (or `group/project` for GitLab) from the input. Detect platform automatically.

**Accept formats:**

GitHub:
- `https://github.com/owner/repo`
- `https://github.com/owner/repo.git`
- `owner/repo` (default if no prefix — assumes GitHub)

GitLab:
- `https://gitlab.com/group/project`
- `https://gitlab.com/group/subgroup/project`
- `https://gitlab.com/group/project.git`
- `https://<self-hosted-gitlab>/group/project`
- `gitlab:group/project` (explicit GitLab prefix)

**Detection rules:**
1. URL contains `gitlab.com` or `gitlab.` → GitLab
2. URL contains `github.com` → GitHub
3. Prefixed with `gitlab:` → GitLab
4. URL contains a known self-hosted GitLab hostname (see "Known Self-Hosted GitLab Instances" section) → GitLab
5. Bare `owner/repo` with no prefix → GitHub (default)
6. If ambiguous, ask the user

**Set a `PLATFORM` variable** (github or gitlab) that all subsequent steps use.

For GitLab, also compute the **URL-encoded project path**: replace `/` with `%2F` in the project path (e.g., `group%2Fsubgroup%2Fproject`). Store this as `PROJECT_PATH_ENCODED`.

**Split-hostname detection:** If the GitLab instance has separate SSH and API hostnames (see "Known Self-Hosted GitLab Instances"), store both:
- `GIT_HOST` — for `git clone` operations (SSH)
- `API_HOST` — for `glab api` and `glab` CLI operations
- Prefix all `glab` commands with `GITLAB_HOST=${API_HOST}` when these differ

### Step 2: Get Repository Stats First

Before asking user options, fetch the total counts so the user knows what they're working with:

**GitHub:**
```bash
# Get actual totals using search API
gh api "search/issues?q=repo:owner/repo+type:issue+state:open" -q '.total_count'
gh api "search/issues?q=repo:owner/repo+type:issue+state:closed" -q '.total_count'
gh api "search/issues?q=repo:owner/repo+type:pr+state:open" -q '.total_count'
gh api "search/issues?q=repo:owner/repo+type:pr+is:merged" -q '.total_count'
gh api repos/owner/repo -q '.forks_count'
```

**GitLab:**
```bash
# Get issue counts via x-total header (per_page=1 for speed)
glab api "projects/${PROJECT_PATH_ENCODED}/issues" -F state=opened -F per_page=1 -i 2>&1 | grep -i 'x-total:' | awk '{print $2}'
glab api "projects/${PROJECT_PATH_ENCODED}/issues" -F state=closed -F per_page=1 -i 2>&1 | grep -i 'x-total:' | awk '{print $2}'

# Get MR counts (GitLab = merge requests, not PRs)
glab api "projects/${PROJECT_PATH_ENCODED}/merge_requests" -F state=opened -F per_page=1 -i 2>&1 | grep -i 'x-total:' | awk '{print $2}'
glab api "projects/${PROJECT_PATH_ENCODED}/merge_requests" -F state=merged -F per_page=1 -i 2>&1 | grep -i 'x-total:' | awk '{print $2}'

# Get fork count
glab repo view group/project -F json | jq '.forks_count'
```

**Display to user:**
```
Repository: owner/repo (GitHub|GitLab)
- Open issues: X
- Closed issues: Y
- Open PRs/MRs: A
- Merged PRs/MRs: B
- Forks: F
```

### Step 3: Ask User Options

Use AskUserQuestion to gather preferences:

```
Question 1: "How should I analyze this repository?"
- "Full clone (Recommended)" - Clone the repo to read file structure, CLAUDE.md, .github/.gitlab/, README, etc.
- "API only" - Use only GitHub/GitLab API for metadata, issues, PRs/MRs, commits. Faster but less thorough.

Question 2: "What commit history timeframe?"
- "3 months (Recommended)" - Recent activity, captures current patterns
- "6 months" - More history for less active repos
- "1 year" - Full year of development patterns

Question 3: "How many issues to fetch?" (Show actual counts!)
- "Last 100" - Quick sampling of recent issues
- "Last 500" - More comprehensive
- "All open (X total)" - All currently open issues
- "All (X open + Y closed)" - Complete issue history

Question 4: "How many PRs/MRs to fetch?" (Show actual counts!)
- "Last 100" - Quick sampling of recent PRs/MRs
- "Last 500" - More comprehensive
- "All open (A total)" - All currently open PRs/MRs
- "All (A open + B merged)" - Complete PR/MR history

Question 5: "A Fork on the Road?" (Only show if forks > 0! Show count.)
- "Yes — analyze all F forks for unique changes" - Compare each fork against upstream to find divergent work
- "Top 10 most recently updated forks" - Analyze only the most active forks
- "Skip fork analysis" - Don't analyze forks
```

### Step 4: Collect Data

Run these commands to gather repository data. Use the appropriate platform commands:

```bash
# Create temp directory for transient analysis data (forks, wiki)
mkdir -p /tmp/repo-analysis

# The repo itself is cloned to ~/work/<repo-name>/ as a FULL working copy
# (not shallow, not to /tmp) so the user can work from it afterward
```

#### 4.1 Get repo metadata

**GitHub:**
```bash
gh repo view owner/repo --json name,description,homepageUrl,languages,topics,defaultBranchRef
```

**GitLab:**
```bash
glab repo view group/project -F json | jq '{name: .name, description: .description, web_url: .web_url, topics: .topics, default_branch: .default_branch}'
```

#### 4.2 Check if wiki exists

**GitHub:**
```bash
gh api repos/owner/repo -q '.has_wiki'
```

**GitLab:**
```bash
glab api "projects/${PROJECT_PATH_ENCODED}" | jq '.wiki_enabled'
```

#### 4.3 Fetch issues

**GitHub:**
```bash
# For "Last 100":
gh issue list --repo owner/repo --state all --limit 100 \
  --json number,title,body,state,labels,author,createdAt,closedAt

# For "All open":
gh issue list --repo owner/repo --state open --limit 9999 \
  --json number,title,body,state,labels,author,createdAt,closedAt

# For "All":
gh issue list --repo owner/repo --state all --limit 9999 \
  --json number,title,body,state,labels,author,createdAt,closedAt
```

**GitLab:**
```bash
# For "Last 100":
glab issue list -R group/project --all --per-page 100 -F json

# For "All open":
glab issue list -R group/project --per-page 100 -F json
# Note: glab defaults to open state; use --all for all states
# For large counts, paginate:
glab api "projects/${PROJECT_PATH_ENCODED}/issues" -F state=opened -F per_page=100 --paginate

# For "All":
glab api "projects/${PROJECT_PATH_ENCODED}/issues" -F state=all -F per_page=100 --paginate
```

#### 4.4 Fetch pull requests / merge requests

**GitHub:**
```bash
# For "Last 100":
gh pr list --repo owner/repo --state all --limit 100 \
  --json number,title,body,state,author,mergedAt,additions,deletions,changedFiles

# For "All open":
gh pr list --repo owner/repo --state open --limit 9999 \
  --json number,title,body,state,author,mergedAt,additions,deletions,changedFiles

# For "All":
gh pr list --repo owner/repo --state all --limit 9999 \
  --json number,title,body,state,author,mergedAt,additions,deletions,changedFiles
```

**GitLab:**
```bash
# For "Last 100":
glab mr list -R group/project --all --per-page 100 -F json

# For "All open":
glab mr list -R group/project --per-page 100 -F json

# For "All":
glab api "projects/${PROJECT_PATH_ENCODED}/merge_requests" -F state=all -F per_page=100 --paginate
```

#### 4.5 Fetch recent commits

**GitHub:**
```bash
gh api "repos/owner/repo/commits?since=$(date -v-3m +%Y-%m-%dT%H:%M:%SZ)&per_page=100" \
  --jq '.[] | {sha: .sha[0:7], author: .commit.author.name, date: .commit.author.date, message: .commit.message}'
```

**GitLab:**
```bash
glab api "projects/${PROJECT_PATH_ENCODED}/repository/commits" \
  -F since="$(date -v-3m +%Y-%m-%dT%H:%M:%SZ)" -F per_page=100 \
  | jq '.[] | {sha: .short_id, author: .author_name, date: .authored_date, message: .message}'
```

#### 4.6 Fetch contributors

**GitHub:**
```bash
gh api repos/owner/repo/contributors --jq '.[] | {login, contributions}' | head -20
```

**GitLab:**
```bash
glab api "projects/${PROJECT_PATH_ENCODED}/repository/contributors" \
  | jq '.[] | {name, email, commits}' | head -20
```

**Note:** GitLab's contributor API returns `name` and `email` (from git commits), not usernames. To get GitLab usernames, you may need to cross-reference with project members:
```bash
glab api "projects/${PROJECT_PATH_ENCODED}/members/all" | jq '.[] | {username, name}'
```

#### 4.7 Clone repository (if "Full clone" selected)

Clone to `~/work/<repo-name>/` as a **full working copy** (not shallow). This gives the user a repo they can immediately work from — create branches, push PRs/MRs, etc.

If `~/work/<repo-name>/` already exists, skip cloning and use the existing checkout (pull latest if clean).

**GitHub:**
```bash
# Full clone to working directory
if [ -d ~/work/<repo-name> ]; then
  echo "~/work/<repo-name>/ already exists — using existing checkout"
  cd ~/work/<repo-name> && git pull --ff-only 2>/dev/null || true
else
  git clone https://github.com/owner/repo.git ~/work/<repo-name>
fi
```

**GitLab:**
```bash
# Full clone to working directory
# For split-hostname instances, clone via SSH host
if [ -d ~/work/<repo-name> ]; then
  echo "~/work/<repo-name>/ already exists — using existing checkout"
  cd ~/work/<repo-name> && git pull --ff-only 2>/dev/null || true
else
  git clone https://gitlab.com/group/project.git ~/work/<repo-name>
  # For self-hosted: use the full URL from the repo metadata
  # For split-hostname: git clone git@${GIT_HOST}:group/project.git ~/work/<repo-name>
fi
```

**After cloning, analyze from `~/work/<repo-name>/`** — read directory structure, README, CONTRIBUTING, CLAUDE.md, .github/.gitlab/, etc. from the working copy.

#### 4.8 Clone wiki (if exists)

**GitHub:**
```bash
git clone --depth=1 https://github.com/owner/repo.wiki.git /tmp/repo-analysis/wiki 2>/dev/null || echo "No wiki"
```

**GitLab:**
```bash
# GitLab wikis are stored as git repos at <project-url>.wiki.git
git clone --depth=1 https://gitlab.com/group/project.wiki.git /tmp/repo-analysis/wiki 2>/dev/null || echo "No wiki"
```

#### 4.9 Fork analysis (if "A Fork on the Road" selected)

**GitHub:**
```bash
# Fetch all forks with metadata
gh api repos/owner/repo/forks --paginate \
  --jq '.[] | {full_name, owner: .owner.login, default_branch, pushed_at, updated_at, stargazers_count, forks_count}' \
  > /tmp/repo-analysis/forks.json

# For each fork, compare against upstream's default branch
for fork in $(gh api repos/owner/repo/forks --paginate --jq '.[].full_name'); do
  fork_owner=$(echo "$fork" | cut -d'/' -f1)
  fork_branch=$(gh api "repos/$fork" --jq '.default_branch' 2>/dev/null)

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

**GitLab:**
```bash
# Fetch all forks with metadata
glab api "projects/${PROJECT_PATH_ENCODED}/forks" --paginate \
  | jq '.[] | {full_path: .path_with_namespace, owner: .namespace.path, default_branch, last_activity_at, star_count, forks_count}' \
  > /tmp/repo-analysis/forks.json

# For each fork, compare against upstream
# GitLab uses the repository compare API:
# GET /projects/:id/repository/compare?from=<upstream_branch>&to=<fork_branch>
# However, cross-project comparison requires the fork to be accessible.
# Alternative: clone each fork shallow and use git log --not
for fork_path in $(glab api "projects/${PROJECT_PATH_ENCODED}/forks" --paginate | jq -r '.[].path_with_namespace'); do
  fork_encoded=$(echo "$fork_path" | sed 's/\//%2F/g')
  fork_branch=$(glab api "projects/${fork_encoded}" | jq -r '.default_branch' 2>/dev/null)
  upstream_branch=$(glab api "projects/${PROJECT_PATH_ENCODED}" | jq -r '.default_branch' 2>/dev/null)

  # GitLab compare API (within same server)
  glab api "projects/${fork_encoded}/repository/compare" \
    -F from="${upstream_branch}" -F to="${fork_branch}" \
    | jq '{
      fork: "'"$fork_path"'",
      commits: [.commits[]? | {sha: .short_id, message: .message, author: .author_name, date: .authored_date}],
      diffs: [.diffs[]? | .new_path]
    }' 2>/dev/null
done > /tmp/repo-analysis/fork-comparisons.json
```

**Note on fork comparison:** The compare API has a limit of ~250 commits on GitHub and similar limits on GitLab. For forks that have diverged significantly, note the divergence but don't try to enumerate every commit — summarize at a high level instead.

### Step 5: Analyze Data

Analyze the collected data for:

**5.1 Contributor Patterns**
- Who are the top 5-10 contributors?
- What areas do they focus on?
- What's their commit message style?

**CRITICAL: Use real names, never invent them.**

GitHub: Look up each contributor's real name via `gh api users/<login> -q '.name'`. GitHub handles do NOT reliably map to real names (e.g., `kaneel` = Guillaume Richard, not "Chris"). If the API returns null for `.name`, use the GitHub handle only — do NOT guess a name.

GitLab: Look up via `glab api users -F username=<login> | jq '.[0].name'`. If the API returns an empty array or null name, use the handle only.

**5.2 Commit Conventions**
- Do they use conventional commits (feat:, fix:, chore:)?
- What prefixes/patterns are common?
- How detailed are commit messages?

**5.3 PR/MR Conventions**
- What's the PR/MR title format?
- Do PRs/MRs have description templates?
- What's the typical PR/MR scope (files changed)?

**5.4 Issue Patterns**
- What labels are used?
- Are there issue templates?
- How are issues categorized?

**5.5 Documentation (if cloned)**
- README.md - project overview, setup instructions
- CONTRIBUTING.md - contribution guidelines
- CLAUDE.md or .claude/ - AI-specific instructions
- `.github/` (GitHub) or `.gitlab/` (GitLab) - templates, workflows, CI/CD
- `.gitlab-ci.yml` (GitLab) - CI/CD pipeline definition
- Wiki pages - detailed documentation

**5.6 Code Structure (if cloned)**
- Primary language(s)
- Directory structure
- Test framework and patterns
- Build/tooling configuration

**5.7 A Fork on the Road (if fork analysis selected)**

Analyze the fork comparison data to answer:
- **Which forks have unique work?** (ahead_by > 0 or unique commits) — these are the interesting ones
- **What did they change?** Summarize the files changed and commit messages per fork
- **Are there patterns?** Multiple forks fixing the same thing suggests an unaddressed upstream issue
- **Stale vs. active?** Use `pushed_at` / `last_activity_at` to distinguish active forks from abandoned ones
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
source_repo: <full URL — https://github.com/... or https://gitlab.com/...>
source_platform: <github|gitlab>
tags: [<primary language>, <framework if any>, <topics from repo>]
triggers:
  keywords:
    primary: [<repo-name>, <owner>/<repo>]
    secondary: [<key terms from description>]
---

# <Repo Name> Development Skill

> Auto-generated by github-cloner on <date> from <GitHub|GitLab>. Re-run `/github-cloner <url>` to update.

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

### Pull Requests / Merge Requests

<PR/MR conventions:>
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
- CI: <GitHub Actions | GitLab CI (.gitlab-ci.yml) | other>
- Deployment: <if documented>

## Documentation Resources

<Links and summaries:>
- README: <key sections>
- Wiki: <if present, key pages>
- Contributing guide: <key points>

## AI-Specific Instructions

<From CLAUDE.md if present, or generated guidelines:>
- When working on this repo, follow these conventions...
- Before submitting PRs/MRs, ensure...
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
<!-- PR-FED: Updated by PR/MR analysis. When a PR/MR reveals new focus areas or notable work, update this table. -->

**CRITICAL: All names in this table MUST be real names looked up via the platform API. NEVER guess or invent names from handles.**

GitHub: `gh api users/<login> -q '.name'`
GitLab: `glab api users -F username=<login> | jq '.[0].name'`

| Contributor | Handle | Focus Areas | Notable PRs/MRs |
|-------------|--------|-------------|-----------------|
<Populated from contributor analysis. Notable PRs/MRs column starts empty, filled by PR/MR analysis.>

## Common Pitfalls
<!-- PR-FED: Grown from PRs/MRs that fix recurring problems. Each row is a lesson learned. -->

| Pitfall | Fix | Seen in |
|---------|-----|---------|
<Starts empty. Populated as bug-fix PRs/MRs are analyzed.>

## PR/MR Analysis & Skill Growth

This skill is a living document. It was created by github-cloner but is **kept alive by PR/MR analysis**.

**How it grows:**
- Every PR/MR analyzed updates the skill — contributors, active areas, pitfalls, coding patterns
- Techniques extracted from PRs/MRs accumulate in `pr-exemplars.md`
- Sections marked `<!-- PR-FED -->` are maintained by the PR/MR analysis pipeline

**Modules that power this:**

| Module | Path | Purpose |
|--------|------|---------|
| PR Writeup Template | `~/.claude/skills/pr-writeup-template.md` | Problem -> Solution format for PR/MR descriptions |
| PR Analysis | `~/.claude/skills/pr-analysis.md` | Read, explain, score, and archive PRs/MRs; feed back into this skill |
| PR Exemplars | `~/.claude/skills/<repo-name>/pr-exemplars.md` | Every PR/MR archived, techniques indexed |

**To analyze a PR/MR:** Say `read <URL>` or `read PR #<number>` / `read MR !<number>`
**To bulk-ingest history:** Re-run `/github-cloner <url>`

## Quick Reference

| Item | Value |
|------|-------|
| Source Platform | <GitHub\|GitLab> |
| Primary Language | <language> |
| Default Branch | <branch> |
| License | <license> |
| Last Analyzed | <date> |
```

### Step 6.5: Initialize PR/MR Analysis Pipeline

After generating the skill, also create the PR exemplars file:

Create `~/.claude/skills/<repo-name>/pr-exemplars.md`:

```markdown
# <Repo Name> — PR/MR Archive & Exemplars

> Every merged PR/MR is a record of what was contributed. This file catalogues them all.
> Stand-out PRs/MRs (13+/15) are spotlighted. Every PR/MR teaches something.
> Managed by the PR Analysis skill (`~/.claude/skills/pr-analysis.md`).

## Techniques Index

| Technique | First seen in | Category |
|-----------|--------------|----------|
<Populated as PRs/MRs are analyzed.>

---

<PR/MR entries appear here as they are analyzed.>
```

Then, for each of the top 10-20 most significant merged PRs/MRs (largest diff, most comments, or most recent), run the PR analysis pipeline from `~/.claude/skills/pr-analysis.md`:
1. Fetch the PR/MR metadata and diff
2. Produce the breakdown (what it does, changes at a glance, technique, risk)
3. Score it (Craft / Clarity / Courage)
4. Archive it in `pr-exemplars.md`
5. Update the skill's PR-FED sections (Contributors, Common Pitfalls, Active Areas)

This seeds the exemplar library from day one. The skill doesn't launch empty — it launches with the project's best work already catalogued.

### Step 6.6: Generate analysis.json (Machine-Readable)

Also create `~/.claude/skills/<repo-name>/analysis.json` for other LLMs/agents:

```json
{
  "version": "2.0",
  "generated": "<ISO-8601 timestamp>",
  "source_repo": "<full URL>",
  "source_platform": "github|gitlab",

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
      "contributions": "<count>",
      "focus_areas": ["<path1>", "<path2>"],
      "commit_style": "conventional|freeform|mixed",
      "recent_activity": true
    }
  ],

  "conventions": {
    "commit_format": "conventional|freeform|angular|custom",
    "commit_prefixes": ["feat", "fix", "chore", "docs"],
    "commit_examples": ["<example1>", "<example2>"],
    "pr_title_format": "<pattern>",
    "pr_has_template": true,
    "issue_labels": ["<label1>", "<label2>"]
  },

  "recent_prs": [
    {
      "number": 0,
      "title": "<title>",
      "body": "<description>",
      "state": "open|closed|merged",
      "author": "<username>",
      "merged_at": "<timestamp>",
      "files_changed": 0,
      "additions": 0,
      "deletions": 0
    }
  ],

  "recent_issues": [
    {
      "number": 0,
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
    "has_readme": true,
    "has_contributing": true,
    "has_claude_md": false,
    "has_wiki": true,
    "wiki_pages": ["<page1>", "<page2>"],
    "readme_summary": "<brief summary>"
  },

  "recent_activity": {
    "analysis_period_days": 0,
    "total_commits": 0,
    "total_prs_merged": 0,
    "active_contributors": 0
  },

  "forks": {
    "total_count": 0,
    "analyzed": false,
    "forks_with_unique_work": 0,
    "fork_details": [
      {
        "full_name": "<owner/repo>",
        "owner": "<username>",
        "type": "feature|fix|customization|abandoned|mirror",
        "ahead_by": 0,
        "behind_by": 0,
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
        "upstreaming_candidate": true,
        "upstreaming_reason": "<why this could benefit upstream>"
      }
    ]
  }
}
```

This file follows the schema at `~/.claude/skills/github-cloner/schemas/repo-analysis-schema.json`.

### Step 7: Cleanup

```bash
# Remove temp files (forks, wiki analysis data) — NOT the working repo
rm -rf /tmp/repo-analysis
# The repo at ~/work/<repo-name>/ is kept as a working copy
```

### Step 9: Report Success

Tell the user:
- **Working repo** cloned to `~/work/<repo-name>/` — ready for branches, commits, and PRs/MRs
- Skill created at `~/.claude/skills/<repo-name>/SKILL.md`
- PR/MR archive initialized at `~/.claude/skills/<repo-name>/pr-exemplars.md`
- Machine-readable data at `~/.claude/skills/<repo-name>/analysis.json`
- Top PRs/MRs have been analyzed and seeded into the exemplar library
- If fork analysis was performed: **"A Fork on the Road" found N forks with unique work** — summarize the most interesting findings (potential bug fixes, features, etc.)
- **The skill is now alive** — say `read <PR/MR-URL>` to analyze any PR/MR and the skill grows
- **To start working:** `cd ~/work/<repo-name>` — the repo is a full clone with complete git history
- How to update the foundation: re-run `/github-cloner <url>`

---

## How github-cloner and PR/MR Analysis Work Together

```
github-cloner                          PR/MR analysis
─────────────                          ──────────────
Analyzes repo ──→ Creates SKILL.md     "read <URL>" ──→ Fetches PR/MR
                  Creates pr-exemplars.md               Explains diff
                  Seeds top PRs/MRs ───────────────→   Scores quality
                                                        Archives to pr-exemplars.md
                                                        Updates SKILL.md (PR-FED sections)
                                                        ↓
                                                     Skill gets sharper
                                                     Techniques index grows
                                                     Pitfalls table grows
                                                     Contributors sharpen
```

**github-cloner** is the foundation pour — the initial snapshot.
**PR/MR analysis** is the ongoing feed — every PR/MR deepens the skill's understanding.

The skill knows the people. It knows their code. It knows the patterns they use and the mistakes they've fixed. And it gets better every time a PR/MR is analyzed.

## Notes

- **Rate limits**: Both GitHub and GitLab APIs have rate limits. For large repos, the API-only mode is gentler.
- **Private repos**: GitHub requires `gh auth` with appropriate permissions. GitLab requires `glab auth` with a personal access token.
- **Self-hosted GitLab**: `glab` supports self-hosted instances. Configure with `glab auth login --hostname your-gitlab.example.com`.
- **Split-hostname GitLab instances**: Some self-hosted GitLab setups use different hostnames for SSH (git) and HTTPS (API) — for example, due to Cloudflare constraints. In these cases, `glab` may fail because it assumes both git and API are on the same hostname. **Workaround:** set `GITLAB_HOST=<api-hostname>` when running `glab` commands on a repo cloned via SSH from a different hostname. Example: if SSH is at `git.example.com` but API is at `work.example.com`, use `GITLAB_HOST=work.example.com glab issue list`. Known instance with this issue: Episkopos Community (`git.episkopos.community` for SSH, `work.episkopos.community` for API).
- **Updates**: Re-running the skill will overwrite the generated skill with fresh data, but preserves `pr-exemplars.md`.
- **Wiki**: Not all repos have wikis. The skill handles this gracefully on both platforms.
- **GitLab CI/CD**: GitLab repos often have `.gitlab-ci.yml` at root — this is equivalent to `.github/workflows/` and should be analyzed for build/test/deploy patterns.
- **GitLab subgroups**: GitLab supports nested groups (e.g., `org/team/subteam/project`). All slashes must be URL-encoded in API calls.
- **PR analysis module**: `~/.claude/skills/pr-analysis.md` — the full pipeline docs.
- **PR writeup template**: `~/.claude/skills/pr-writeup-template.md` — how to write PR/MR descriptions.

## Known Self-Hosted GitLab Instances

| Instance | SSH Host | API Host | Notes |
|----------|----------|----------|-------|
| Episkopos Community | `git.episkopos.community` | `work.episkopos.community` | Split hostname due to Cloudflare. Use `GITLAB_HOST=work.episkopos.community` for all `glab` commands. Status page: `status.episkopos.community`. Also runs: Stoat Chat, Umami analytics, Rallly scheduling. |

When cloning from a known split-hostname instance, the skill should automatically detect this and:
1. Clone via SSH using the git hostname
2. Set `GITLAB_HOST` to the API hostname for all `glab` API calls
3. Warn the user about the split-hostname configuration in the generated skill
