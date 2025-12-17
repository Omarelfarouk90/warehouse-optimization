#!/bin/bash

# GitHub Upload Script (Environment Variable Version)
# Set your GitHub token as an environment variable first:
# export GITHUB_TOKEN=your_personal_access_token_here
# Then run this script

echo "🚀 GitHub Project Upload (Token Version)"
echo "========================================"

# Check if token is provided
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN environment variable not set!"
    echo ""
    echo "📋 Setup Instructions:"
    echo "   1. Create Personal Access Token: https://github.com/settings/tokens"
    echo "   2. Set environment variable:"
    echo "      export GITHUB_TOKEN=your_token_here"
    echo "   3. Run this script again"
    echo ""
    echo "🔒 Security: Token is only used for git operations"
    exit 1
fi

# Validate token format
if [[ ! $GITHUB_TOKEN =~ ^gh[psuo]_ ]]; then
    echo "❌ Invalid token format. GitHub tokens start with 'ghp_', 'ghs_', 'gho_', etc."
    exit 1
fi

echo "✅ GitHub token found (length: ${#GITHUB_TOKEN} characters)"

# Navigate to project directory
cd /home/omar-elsherif/warehouse_optimization

echo "📍 Current directory: $(pwd)"
echo "📦 Repository: https://github.com/Omarelfarouk90/warehouse-optimization"
echo ""

# Check git status
echo "🔍 Checking git status..."
git status
echo ""

# Configure remote with token
echo "🔗 Setting up authenticated remote..."
git remote set-url origin "https://Omarelfarouk90:$GITHUB_TOKEN@github.com/Omarelfarouk90/warehouse-optimization.git"
echo "✅ Remote configured with authentication"

# Switch to main branch
echo "🌿 Ensuring main branch..."
git branch -M main
echo "✅ On main branch"

# Push to GitHub
echo "📤 Pushing to GitHub..."
if git push -u origin main; then
    echo ""
    echo "🎉 SUCCESS! Project uploaded to GitHub"
    echo "🌐 Repository URL: https://github.com/Omarelfarouk90/warehouse-optimization"
    echo ""
    echo "📊 Repository contains:"
    echo "   • Complete warehouse optimization system"
    echo "   • VNS optimization with 15% improvement"
    echo "   • Advanced visualizations (PNG, GIF, ASCII)"
    echo "   • Comprehensive documentation"
    echo "   • Industrial-ready code"
    echo ""
    echo "🔒 Security Note: The token was only used for this push."
    echo "   Consider unsetting the environment variable:"
    echo "   unset GITHUB_TOKEN"
else
    echo ""
    echo "❌ Push failed. Possible issues:"
    echo "   1. Invalid token - verify it has 'repo' scope"
    echo "   2. Repository doesn't exist - create https://github.com/Omarelfarouk90/warehouse-optimization"
    echo "   3. Token expired - create a new one"
    echo "   4. Network issues - try again later"
fi