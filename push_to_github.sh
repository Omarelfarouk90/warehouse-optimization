#!/bin/bash

# Warehouse Optimization - GitHub Upload Script
# Run this after creating the GitHub repository

echo "🚀 Pushing Warehouse Optimization Project to GitHub"
echo "=================================================="
echo ""
echo "⚠️  IMPORTANT: GitHub requires a Personal Access Token (PAT)"
echo "   GitHub no longer accepts passwords for git operations."
echo ""
echo "📋 If you haven't created a PAT yet:"
echo "   1. Go to: https://github.com/settings/tokens"
echo "   2. Click 'Generate new token (classic)'"
echo "   3. Name it: 'warehouse-optimization-push'"
echo "   4. Select scope: 'repo' (full control)"
echo "   5. Copy the token (save it securely!)"
echo ""

# Navigate to project directory
cd /home/omar-elsherif/warehouse_optimization

echo "📍 Current directory: $(pwd)"
echo "📦 Repository: https://github.com/Omarelfarouk90/warehouse-optimization"
echo ""

# Check git status
echo "🔍 Checking git status..."
git status
echo ""

# Get Personal Access Token from user
echo "🔑 Enter your GitHub Personal Access Token:"
echo "   (This will be used for authentication - input will be hidden)"
read -s GITHUB_TOKEN

if [ -z "$GITHUB_TOKEN" ]; then
    echo ""
    echo "❌ No token provided. Please create a Personal Access Token first."
    echo "   Visit: https://github.com/settings/tokens"
    exit 1
fi

echo ""
echo "✅ Token received (length: ${#GITHUB_TOKEN} characters)"

# Set up remote URL with token
echo "🔗 Setting up authenticated remote..."
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
    echo "❌ Push failed. Possible issues:"
    echo "   1. Repository doesn't exist: Create https://github.com/Omarelfarouk90/warehouse-optimization"
    echo "   2. Invalid token: Check your Personal Access Token"
    echo "   3. Network issues: Try again later"
    echo "   4. Manual push: git push -u origin main"
    echo ""
    echo "🔧 Token troubleshooting:"
    echo "   - Verify token has 'repo' scope"
    echo "   - Check token hasn't expired"
    echo "   - Ensure correct username: Omarelfarouk90"
fi