# Workflow Guide: Generate a Skill from One Repo, Use It in Another

This guide walks you through generating a development skill from a repository you have cloned, then using that skill in a different folder where you do your actual development work.

---

## The Scenario

You have:
1. **A cloned repository** (e.g., `~/repos/my-project/`) - where you pulled the code
2. **A development folder** (e.g., `~/dev/my-project-work/`) - where you actually write code
3. **A public GitHub repository** - the source of truth for issues and commits

You want the skill to be generated once, then available everywhere.

---

## How It Works

Skills are stored globally at `~/.claude/skills/<repo-name>/`

This means:
- Generate the skill from **any folder**
- Use it from **any other folder**
- The skill auto-triggers when you mention the repo name

---

## Step-by-Step Workflow

### Step 1: Navigate to Your Cloned Repository

```bash
cd ~/repos/my-project
```

### Step 2: Start Claude Code

```bash
claude
```

### Step 3: Run the GitHub Cloner Skill

```
/github-cloner owner/my-project
```

Or with the full URL:
```
/github-cloner https://github.com/owner/my-project
```

### Step 4: Answer the Prompts

1. **Analysis mode**: Choose "Full clone" or "API only"
   - If you're already in the repo folder, "API only" is often enough
   - "Full clone" reads README, CLAUDE.md, .github/ for more context

2. **Commit history**: Choose 3/6/12 months based on repo activity

### Step 5: Wait for Generation

Claude will:
- Fetch issues from GitHub
- Fetch PRs from GitHub
- Fetch recent commits
- Analyze patterns
- Generate the skill

### Step 6: Skill is Ready

Files created at:
```
~/.claude/skills/my-project/
├── SKILL.md       # Human-readable skill
└── analysis.json  # Machine-readable data
```

---

## Using the Skill in Your Development Folder

### Step 1: Navigate to Your Dev Folder

```bash
cd ~/dev/my-project-work
```

### Step 2: Start Claude Code

```bash
claude
```

### Step 3: The Skill is Automatically Available

The skill triggers when you:
- Mention the project name
- Work on files related to the project
- Ask about development conventions

You can also explicitly reference it:
```
Using the my-project skill, what are the commit conventions?
```

---

## Example: Real Workflow

Let's say you have:
- **Repo**: `https://github.com/acme/widget-app`
- **Clone location**: `/Users/you/repos/widget-app`
- **Dev location**: `/Users/you/work/widget-features`

**Generate the skill:**
```bash
cd /Users/you/repos/widget-app
claude
# In Claude:
/github-cloner acme/widget-app
# Answer prompts, wait for generation
# Exit Claude
```

**Use the skill:**
```bash
cd /Users/you/work/widget-features
claude
# The widget-app skill is now available!
# Ask: "What's the commit format for this project?"
# Ask: "Who are the main contributors?"
# Work on code with full context
```

---

## Updating the Skill

When the repo has new commits, PRs, or issues:

```bash
# From any folder:
claude
/github-cloner acme/widget-app
```

The skill will be regenerated with fresh data.

---

## Verifying the Skill Exists

```bash
ls ~/.claude/skills/
```

You should see your project folder:
```
widget-app/
├── SKILL.md
└── analysis.json
```

---

## Sharing the Skill with Another LLM

If you want another LLM (Gemini, GPT, etc.) to use this data:

1. Copy the files:
   ```bash
   cp ~/.claude/skills/widget-app/analysis.json /path/to/other/location/
   ```

2. Give the other LLM these instructions:
   ```
   Read the file analysis.json which contains repository analysis:
   - contributors: Who works on what
   - conventions: Commit and PR patterns
   - recent_prs: Current development context
   - feature_areas: What areas of the codebase exist

   Use this to understand the project's development patterns.
   ```

---

## Tips

1. **Generate once, use everywhere** - The skill is global, not tied to a folder

2. **API-only is often enough** - If you just need issues/PRs/commits, skip the clone

3. **Re-generate periodically** - Keep the skill fresh with new commits/PRs

4. **Check the analysis.json** - It has structured data you can parse or share

5. **Works with private repos** - Just make sure `gh auth login` has access

---

## Troubleshooting

**"gh: command not found"**
```bash
brew install gh
gh auth login
```

**"Could not fetch repo metadata"**
- Check you have access to the repo
- Run `gh auth status` to verify authentication

**Skill not showing up**
- Check `ls ~/.claude/skills/` for the folder
- Restart Claude Code to reload skills

**Want to delete a skill**
```bash
rm -rf ~/.claude/skills/my-project/
```
