#!/bin/bash

# Secure GitHub Token Setup Script
# This script securely prompts for your GitHub Personal Access Token
# and configures the remote URL for uploading your project

echo "🔑 GitHub Personal Access Token Setup"
echo "====================================="
echo ""
echo "This script will securely configure your GitHub remote with a Personal Access Token."
echo ""
echo "📋 If you haven't created a PAT yet:"
echo "   1. Go to: https://github.com/settings/tokens"
echo "   2. Click 'Generate new token (classic)'"
echo "   3. Name it: 'warehouse-optimization-push'"
echo "   4. Select scope: 'repo' (full control)"
echo "   5. Copy the token"
echo ""
echo "⚠️  Your token will be used ONLY for this git operation and not stored."
echo ""

# Navigate to project directory
cd /home/omar-elsherif/warehouse_optimization

# Prompt for token securely (input hidden)
read -s -p "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
echo ""

# Validate token format (GitHub tokens start with ghp_, ghs_, gho_, etc.)
if [[ ! $GITHUB_TOKEN =~ ^gh[psuo]_ ]]; then
    echo "❌ Invalid token format. GitHub tokens start with 'ghp_', 'ghs_', 'gho_', etc."
    echo "   Please check your token and try again."
    exit 1
fi

echo "✅ Token format validated"

# Update remote URL with token
echo "🔗 Configuring remote URL..."
git remote set-url origin "https://Omarelfarouk90:$GITHUB_TOKEN@github.com/Omarelfarouk90/warehouse-optimization.git"
echo "✅ Remote URL updated"

# Test the connection
echo "🧪 Testing authentication..."
if git ls-remote --heads origin main >/dev/null 2>&1; then
    echo "✅ Authentication successful!"
    echo ""
    echo "🚀 Ready to push your project to GitHub!"
    echo ""
    echo "📤 Run the following command to upload:"
    echo "   git push -u origin main"
    echo ""
    echo "📦 This will upload your complete warehouse optimization system!"
else
    echo "❌ Authentication failed. Please check:"
    echo "   - Token has 'repo' scope"
    echo "   - Token is not expired"
    echo "   - Repository exists: https://github.com/Omarelfarouk90/warehouse-optimization"
    echo "   - Correct username: Omarelfarouk90"
    exit 1
fi