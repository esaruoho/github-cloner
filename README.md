# GitHub/GitLab Cloner - Repository Skill Generator

A Claude Code skill that analyzes any GitHub or GitLab repository and generates a custom development skill tailored to that project's patterns, conventions, and documentation.

## What It Does

GitHub/GitLab Cloner examines a repository and extracts:

- **Contributor patterns** - Who are the key developers? What areas do they focus on?
- **Commit conventions** - Do they use conventional commits? What prefixes are common?
- **PR/MR patterns** - How are PRs/MRs titled and described? What's typical scope?
- **Issue organization** - What labels are used? Are there templates?
- **Documentation** - README, CONTRIBUTING, CLAUDE.md, wiki content
- **CI/CD** - GitHub Actions workflows or `.gitlab-ci.yml` pipelines
- **A Fork on the Road** - Analyzes forks for unique work not in upstream — finds hidden bug fixes, features, and customizations living in the fork ecosystem

It then generates a **skill file** that helps any AI assistant work "in tune" with that repository's actual development patterns.

## Supported Platforms

| Platform | CLI Tool | Status |
|----------|----------|--------|
| GitHub | `gh` | Full support |
| GitLab | `glab` | Full support (v2.0+) |

Both platforms support: repo metadata, issues, PRs/MRs, commits, contributors, forks, wiki, and full clone analysis.

## Installation

Copy the skill to your Claude Code skills directory:

```bash
# Clone this repo
git clone https://github.com/esaruoho/github-cloner.git

# Copy to Claude Code skills directory
cp -r github-cloner ~/.claude/skills/
```

Or manually copy the files to `~/.claude/skills/github-cloner/`.

## Usage

```
/github-cloner <repository>
```

**Examples:**
```
# GitHub repos
/github-cloner https://github.com/anthropics/claude-code
/github-cloner facebook/react
/github-cloner owner/repo

# GitLab repos
/github-cloner https://gitlab.com/inkscape/inkscape
/github-cloner https://gitlab.freedesktop.org/mesa/mesa
/github-cloner gitlab:group/subgroup/project
```

**Platform detection is automatic:**
- URLs containing `gitlab.com` or `gitlab.` -> GitLab
- URLs containing `github.com` -> GitHub
- `gitlab:` prefix -> GitLab
- Bare `owner/repo` -> GitHub (default)

## Requirements

- [Claude Code](https://claude.ai/claude-code) CLI

**For GitHub repos:**
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

```bash
brew install gh
gh auth login
```

**For GitLab repos:**
- [GitLab CLI](https://gitlab.com/gitlab-org/cli) (`glab`) installed and authenticated

```bash
brew install glab
glab auth login
# For self-hosted: glab auth login --hostname your-gitlab.example.com
```

## Output

After running, a new skill is created at `~/.claude/skills/<repo-name>/` containing:

| File | Purpose |
|------|---------|
| `SKILL.md` | Human-readable skill with conventions, patterns, instructions |
| `pr-exemplars.md` | PR/MR archive with technique index |
| `analysis.json` | Machine-readable structured data (for other LLMs) |

## Features

- **Dual platform** - Works with both GitHub and GitLab repositories
- **Interactive options** - Choose full clone vs API-only, commit history timeframe
- **A Fork on the Road** - Discover hidden work in forks: bug fixes, features, and customizations that never made it upstream
- **Machine-readable output** - `analysis.json` follows a JSON schema for LLM interoperability
- **Cross-LLM compatible** - Other AI assistants can consume the structured data
- **Living skills** - PR/MR analysis keeps the skill growing after initial generation
- **Self-hosted GitLab** - Supports custom GitLab instances via `glab auth`
- **Incremental updates** - Re-run to refresh with latest commits/PRs/MRs

## Documentation

| File | Description |
|------|-------------|
| [SKILL.md](SKILL.md) | The skill instructions (what Claude follows) |
| [AGENT-PROTOCOL.md](AGENT-PROTOCOL.md) | How other LLMs can consume the output |
| [INTEGRATION-GUIDE.md](INTEGRATION-GUIDE.md) | Building repository-specific skills |
| [WORKFLOW-GUIDE.md](WORKFLOW-GUIDE.md) | Step-by-step usage workflow |
| [schemas/repo-analysis-schema.json](schemas/repo-analysis-schema.json) | JSON schema for analysis.json |

## Example Workflow

1. **Generate a skill from any repo:**
   ```bash
   cd ~/repos/my-project
   claude
   # In Claude: /github-cloner owner/my-project
   # Or: /github-cloner https://gitlab.com/group/my-project
   ```

2. **Use the skill from anywhere:**
   ```bash
   cd ~/dev/my-project-work
   claude
   # The skill is automatically available!
   ```

3. **Update when needed:**
   ```
   /github-cloner owner/my-project
   ```

## File Structure

```
github-cloner/
├── SKILL.md                 # Main skill instructions
├── README.md                # This file
├── AGENT-PROTOCOL.md        # LLM interoperability guide
├── INTEGRATION-GUIDE.md     # Building on github-cloner
├── WORKFLOW-GUIDE.md        # Usage workflow
├── schemas/
│   └── repo-analysis-schema.json
└── scripts/
    └── analyze-repo.sh      # Helper script
```

## Use Cases

- **Onboard to a new codebase** - Quickly understand conventions and key contributors
- **Cross-platform projects** - Works with repos on either GitHub or GitLab
- **Cross-LLM workflows** - Generate data for Claude, use it with GPT/Gemini
- **Build custom skills** - Use as a foundation for repository-specific skills
- **Team documentation** - Auto-generate development guides from actual patterns

## License

MIT

## Contributing

Contributions welcome! Please follow the existing code style and include tests for new features.
