#!/bin/bash

# Extract changelog entries from merged PRs and store them for release
# This script runs on every merge to main and collects changelog information

set -e

# Create directory for changelog entries
CHANGELOG_ENTRIES_DIR=".github/changelog_entries"
mkdir -p "$CHANGELOG_ENTRIES_DIR"

# Get the commit that triggered this workflow
COMMIT_SHA="${GITHUB_SHA}"

# Get PR number associated with this commit (if any)
PR_NUMBER=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/commits/$COMMIT_SHA/pulls" | \
  jq -r '.[0].number // empty')

if [ -n "$PR_NUMBER" ]; then
  # Get PR details
  PR_DATA=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER")
  
  # Check if PR_DATA is valid JSON object
  if echo "$PR_DATA" | jq -e 'type == "object"' > /dev/null 2>&1; then
    PR_TITLE=$(echo "$PR_DATA" | jq -r '.title')
    PR_AUTHOR=$(echo "$PR_DATA" | jq -r '.user.login')
    PR_BODY=$(echo "$PR_DATA" | jq -r '.body // empty')
  else
    echo "Error: Failed to fetch PR details for PR #$PR_NUMBER"
    echo "Response was: $PR_DATA"
    exit 1
  fi
  
  # Check if PR body contains ##Changelog section
  if echo "$PR_BODY" | grep -q "##Changelog"; then
    # Extract changelog content
    CHANGELOG_CONTENT=$(echo "$PR_BODY" | sed -n '/##Changelog/,$p' | sed '1d' | sed '/^##[^#]/q' | sed '$d')
    
    # If no other ## sections, get everything after ##Changelog
    if [ -z "$CHANGELOG_CONTENT" ]; then
      CHANGELOG_CONTENT=$(echo "$PR_BODY" | sed -n '/##Changelog/,$p' | sed '1d')
    fi
    
    # Create changelog entry file
    ENTRY_FILE="$CHANGELOG_ENTRIES_DIR/pr-${PR_NUMBER}.md"
    
    # Write changelog entry with PR information
    cat > "$ENTRY_FILE" << EOF
### $PR_TITLE

$CHANGELOG_CONTENT

**Contributed by:** @$PR_AUTHOR
EOF
    
    echo "Changelog entry extracted from PR #$PR_NUMBER"
  else
    echo "No ##Changelog section found in PR #$PR_NUMBER"
  fi
else
  echo "No PR associated with this commit"
fi
