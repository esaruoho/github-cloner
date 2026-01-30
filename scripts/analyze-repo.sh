#!/bin/bash
# GitHub Repository Analyzer
# Collects data for generating a repository-specific skill

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage
usage() {
    echo "Usage: $0 <owner/repo> [options]"
    echo ""
    echo "Options:"
    echo "  --clone          Clone the repository for deeper analysis"
    echo "  --wiki           Include wiki if available"
    echo "  --months N       Commit history timeframe (default: 3)"
    echo "  --output DIR     Output directory (default: /tmp/repo-analysis)"
    echo ""
    echo "Examples:"
    echo "  $0 anthropics/claude-code"
    echo "  $0 facebook/react --clone --months 6"
    exit 1
}

# Check dependencies
check_deps() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: gh CLI is required but not installed.${NC}"
        echo "Install with: brew install gh"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo -e "${RED}Error: Not authenticated with GitHub.${NC}"
        echo "Run: gh auth login"
        exit 1
    fi
}

# Parse arguments
REPO=""
DO_CLONE=false
DO_WIKI=false
MONTHS=3
OUTPUT_DIR="/tmp/repo-analysis"

while [[ $# -gt 0 ]]; do
    case $1 in
        --clone)
            DO_CLONE=true
            shift
            ;;
        --wiki)
            DO_WIKI=true
            shift
            ;;
        --months)
            MONTHS="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$REPO" ]]; then
                REPO="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$REPO" ]]; then
    usage
fi

# Extract owner and repo name
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

echo -e "${GREEN}Analyzing repository: ${REPO}${NC}"
echo "Output directory: ${OUTPUT_DIR}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

# Calculate date for commit history
if [[ "$OSTYPE" == "darwin"* ]]; then
    SINCE_DATE=$(date -v-${MONTHS}m +%Y-%m-%dT%H:%M:%SZ)
else
    SINCE_DATE=$(date -d "-${MONTHS} months" +%Y-%m-%dT%H:%M:%SZ)
fi

echo -e "${YELLOW}[1/7] Fetching repository metadata...${NC}"
gh repo view "${REPO}" --json name,description,homepageUrl,languages,topics,defaultBranchRef,licenseInfo > metadata.json

echo -e "${YELLOW}[2/7] Fetching contributors...${NC}"
gh api "repos/${REPO}/contributors" --paginate --jq '.[] | {login, contributions}' > contributors.json 2>/dev/null || echo "[]" > contributors.json

echo -e "${YELLOW}[3/7] Fetching issues...${NC}"
gh issue list --repo "${REPO}" --state all --limit 100 \
    --json number,title,body,state,labels,author,createdAt,closedAt > issues.json 2>/dev/null || echo "[]" > issues.json

echo -e "${YELLOW}[4/7] Fetching pull requests...${NC}"
gh pr list --repo "${REPO}" --state all --limit 100 \
    --json number,title,body,state,author,mergedAt,additions,deletions,changedFiles > prs.json 2>/dev/null || echo "[]" > prs.json

echo -e "${YELLOW}[5/7] Fetching commits (last ${MONTHS} months)...${NC}"
gh api "repos/${REPO}/commits?since=${SINCE_DATE}&per_page=100" \
    --jq '.[] | {sha: .sha[0:7], author: .commit.author.name, date: .commit.author.date, message: .commit.message}' > commits.json 2>/dev/null || echo "[]" > commits.json

if $DO_CLONE; then
    echo -e "${YELLOW}[6/7] Cloning repository...${NC}"
    git clone --depth=1 "https://github.com/${REPO}.git" repo 2>/dev/null || echo "Clone failed"

    # Extract key files if they exist
    if [[ -d repo ]]; then
        [[ -f repo/README.md ]] && cp repo/README.md ./README.md
        [[ -f repo/CONTRIBUTING.md ]] && cp repo/CONTRIBUTING.md ./CONTRIBUTING.md
        [[ -f repo/CLAUDE.md ]] && cp repo/CLAUDE.md ./CLAUDE.md
        [[ -d repo/.claude ]] && cp -r repo/.claude ./.claude
        [[ -d repo/.github ]] && cp -r repo/.github ./.github

        # Get directory structure
        echo "Directory structure:" > structure.txt
        ls -la repo/ >> structure.txt
        find repo -maxdepth 2 -type d >> structure.txt 2>/dev/null
    fi
else
    echo -e "${YELLOW}[6/7] Skipping clone (API-only mode)${NC}"
fi

if $DO_WIKI; then
    echo -e "${YELLOW}[7/7] Cloning wiki...${NC}"
    git clone --depth=1 "https://github.com/${REPO}.wiki.git" wiki 2>/dev/null || echo "No wiki available"
else
    echo -e "${YELLOW}[7/7] Skipping wiki${NC}"
fi

echo ""
echo -e "${GREEN}Analysis complete!${NC}"
echo "Data saved to: ${OUTPUT_DIR}"
echo ""
echo "Files created:"
ls -la "${OUTPUT_DIR}"
