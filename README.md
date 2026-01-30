# GitHub Cloner - Repository Skill Generator

A Claude Code skill that analyzes any GitHub repository and generates a custom development skill tailored to that project's patterns, conventions, and documentation.

## What It Does

GitHub Cloner examines a repository and extracts:

- **Contributor patterns** - Who are the key developers? What areas do they focus on?
- **Commit conventions** - Do they use conventional commits? What prefixes are common?
- **PR patterns** - How are PRs titled and described? What's typical scope?
- **Issue organization** - What labels are used? Are there templates?
- **Documentation** - README, CONTRIBUTING, CLAUDE.md, wiki content

It then generates a **skill file** that helps any AI assistant work "in tune" with that repository's actual development patterns.

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
/github-cloner https://github.com/anthropics/claude-code
/github-cloner facebook/react
/github-cloner owner/repo
```

## Requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login
```

## Output

After running, a new skill is created at `~/.claude/skills/<repo-name>/` containing:

| File | Purpose |
|------|---------|
| `SKILL.md` | Human-readable skill with conventions, patterns, instructions |
| `analysis.json` | Machine-readable structured data (for other LLMs) |

## Features

- **Interactive options** - Choose full clone vs API-only, commit history timeframe
- **Machine-readable output** - `analysis.json` follows a JSON schema for LLM interoperability
- **Cross-LLM compatible** - Other AI assistants can consume the structured data
- **Incremental updates** - Re-run to refresh with latest commits/PRs

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
- **Cross-LLM workflows** - Generate data for Claude, use it with GPT/Gemini
- **Build custom skills** - Use as a foundation for repository-specific skills
- **Team documentation** - Auto-generate development guides from actual patterns

## License

MIT

## Contributing

Contributions welcome! Please follow the existing code style and include tests for new features.
