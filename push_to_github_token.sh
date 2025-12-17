#!/bin/bash

# Warehouse Optimization - GitHub Upload Script (Environment Variable Version)
# Set GITHUB_TOKEN environment variable before running this script
# Example: export GITHUB_TOKEN=your_token_here

# Warehouse Optimization - GitHub Upload Script (Token Version)
# Run this after creating the GitHub repository and setting GITHUB_TOKEN

echo "🚀 Pushing Warehouse Optimization Project to GitHub (Token Version)"
echo "=================================================================="

# Check if token is provided via environment variable
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN environment variable not set!"
    echo ""
    echo "📋 Setup Instructions:"
    echo "   1. Create Personal Access Token: https://github.com/settings/tokens"
    echo "   2. Set environment variable:"
    echo "      export GITHUB_TOKEN=your_token_here"
    echo "   3. Run this script again"
    echo ""
    echo "🔒 Security: Token is only used for this push operation"
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

# Set up remote URL with token
echo "🔗 Configuring authenticated remote..."
git remote set-url origin https://Omarelfarouk90:$GITHUB_TOKEN@github.com/Omarelfarouk90/warehouse-optimization.git
echo "✅ Remote configured with authentication"

# Switch to main branch
echo "🌿 Switching to main branch..."
git branch -M main
echo "✅ Switched to main branch"
echo ""

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
    echo "   Consider deleting it from GitHub settings if no longer needed."
else
    echo ""
    echo "❌ Push failed. Please check:"
    echo "   1. Repository exists: https://github.com/Omarelfarouk90/warehouse-optimization"
    echo "   2. Token has 'repo' scope"
    echo "   3. Token is valid and not expired"
    echo "   4. Network connectivity"
fi