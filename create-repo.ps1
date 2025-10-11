# Create Private GitHub Repository
# This script creates a private repository on GitHub

$repoName = "kusto-dashboard-manager"
$repoDescription = "Kusto Dashboard Manager - Browser automation for Azure Data Explorer dashboards"
$isPrivate = $true

Write-Host "Creating private GitHub repository: $repoName" -ForegroundColor Cyan

# Method 1: Using GitHub CLI (requires authentication)
Write-Host "`nAttempting to create repository using GitHub CLI..." -ForegroundColor Yellow

try {
    # Check if gh is authenticated
    $authStatus = gh auth status 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "GitHub CLI not authenticated. Please run:" -ForegroundColor Red
        Write-Host "  gh auth login --web" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Or use Method 2 below (create via web browser)" -ForegroundColor Yellow
        exit 1
    }
    
    # Create the repository
    Write-Host "Creating repository..." -ForegroundColor Green
    gh repo create "jagilber/$repoName" `
        --private `
        --description $repoDescription `
        --source=. `
        --remote=origin
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Repository created successfully!" -ForegroundColor Green
        Write-Host "`nNow pushing to GitHub..." -ForegroundColor Cyan
        
        # Push to the repository
        git push -u origin master
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✅ Successfully pushed to GitHub!" -ForegroundColor Green
            Write-Host "`nRepository URL: https://github.com/jagilber/$repoName" -ForegroundColor Cyan
        } else {
            Write-Host "`n⚠️ Failed to push. You may need to run:" -ForegroundColor Yellow
            Write-Host "  git push -u origin master" -ForegroundColor White
        }
    } else {
        Write-Host "`n❌ Failed to create repository" -ForegroundColor Red
        Write-Host "The repository might already exist or there's an authentication issue" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    Write-Host "`nPlease use Method 2 (web browser) below" -ForegroundColor Yellow
}

# Method 2: Manual instructions
Write-Host "`n" + "="*70 -ForegroundColor Cyan
Write-Host "ALTERNATIVE: Create Repository via Web Browser" -ForegroundColor Cyan
Write-Host "="*70 -ForegroundColor Cyan
Write-Host ""
Write-Host "If the above method didn't work, create the repository manually:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open your browser and go to:" -ForegroundColor White
Write-Host "   https://github.com/new" -ForegroundColor Green
Write-Host ""
Write-Host "2. Fill in the details:" -ForegroundColor White
Write-Host "   - Repository name: $repoName" -ForegroundColor Green
Write-Host "   - Description: $repoDescription" -ForegroundColor Green
Write-Host "   - Visibility: ✅ Private" -ForegroundColor Green -BackgroundColor DarkRed
Write-Host "   - ❌ Do NOT initialize with README" -ForegroundColor Red
Write-Host ""
Write-Host "3. Click 'Create repository'" -ForegroundColor White
Write-Host ""
Write-Host "4. After creation, run these commands:" -ForegroundColor White
Write-Host "   git remote add origin https://github.com/jagilber/$repoName.git" -ForegroundColor Green
Write-Host "   git push -u origin master" -ForegroundColor Green
Write-Host ""
Write-Host "="*70 -ForegroundColor Cyan
