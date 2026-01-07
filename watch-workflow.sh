#!/usr/bin/env bash
# Safe workflow watcher that won't hang VS Code
# Usage: ./watch-workflow.sh

set -euo pipefail

echo "Waiting for workflow to start..."
sleep 5

# Get the latest run ID
RUN_ID=$(gh run list --workflow="build.yml" --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -z "$RUN_ID" ]; then
    echo "ERROR: No workflow run found"
    exit 1
fi

echo "Found workflow run: $RUN_ID"
echo "View in browser: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions/runs/$RUN_ID"
echo ""
echo "Checking status every 30 seconds (Ctrl+C to stop)..."
echo ""

# Poll status instead of using gh run watch (which can hang)
while true; do
    STATUS=$(gh run view "$RUN_ID" --json status,conclusion -q '.status + " " + (.conclusion // "running")')
    echo "[$(date +'%H:%M:%S')] Status: $STATUS"
    
    if [[ "$STATUS" == *"completed"* ]]; then
        echo ""
        echo "Workflow completed!"
        gh run view "$RUN_ID"
        
        # Show artifacts if any
        echo ""
        echo "Checking for artifacts..."
        gh run view "$RUN_ID" --json artifacts -q '.artifacts[] | "  - \(.name) (\(.size_in_bytes) bytes)"' || echo "  No artifacts found"
        break
    fi
    
    sleep 30
done
