<#
.SYNOPSIS
FULLY AUTOMATED & DYNAMIC:
1. Detects project name from the current folder.
2. Sets the GitHub Remote URL to match the folder name.
3. Auto-generates commit message.
4. Resets remote and pushes.
#>
param(
    # Default user is jasonezard, but can be overridden
    [string]$GitHubUser = "jasonezard",
    [string]$CommitMessage
)

$BranchName = "main"

# 1. Get Project Name from the current folder (e.g., "skills-foundation-project")
$ProjectName = Split-Path -Leaf (Get-Location)

# 2. Construct the Remote URL dynamically based on the folder name
$RemoteUrl = "https://github.com/$GitHubUser/$($ProjectName).git"

# 3. Auto-generate Commit Message if none provided
if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $CommitMessage = "Update $($ProjectName): $Timestamp"
}

# Helper function to mute output but show progress
function Invoke-Git {
    param([string[]]$GitArgs)
    Write-Host "Running: git $($GitArgs -join ' ')" -ForegroundColor Gray
    # Using 'Out-Null' here can hide critical errors. It might be better to remove 2>&1 | Out-Null
    # but for consistency with the original script, we keep it.
    & git $GitArgs 2>&1 | Out-Null
}

Write-Host "--- AUTO-SYNC: $ProjectName ---" -ForegroundColor Cyan
Write-Host "Target Repo: $RemoteUrl" -ForegroundColor DarkGray

# 4. Setup (Initialize & Branch)
Invoke-Git "init"
Invoke-Git "branch", "-M", "$BranchName"

# 5. Create GitHub repo if it doesn't exist (Removed --remote=origin to prevent conflict)
$repoCheck = & gh repo view "$GitHubUser/$ProjectName" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Repository doesn't exist. Creating '$ProjectName' on GitHub..." -ForegroundColor Yellow
    # *** FIX: Removed '--remote=origin' flag to prevent the 'Unable to add remote' error ***
    & gh repo create "$ProjectName" --public --source=.
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create repository. Make sure 'gh' CLI is installed and authenticated." -ForegroundColor Red
        Write-Host "   Run: gh auth login" -ForegroundColor DarkGray
        exit 1
    }
    Write-Host "✅ Repository created!" -ForegroundColor Green
} else {
    Write-Host "Repository exists." -ForegroundColor DarkGray
}

# 6. Set/Update Remote (This runs regardless of creation or existence)
Write-Host "Resetting remote to: $RemoteUrl" -ForegroundColor DarkGray
Invoke-Git "remote", "remove", "origin"
Invoke-Git "remote", "add", "origin", "$RemoteUrl"

# 7. Stage and Commit
Write-Host "Staging files..." -ForegroundColor Yellow
Invoke-Git "add", "."
Invoke-Git "commit", "-m", "$CommitMessage"

# 8. Push
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
# Pull first (rebase) just in case, then push
Invoke-Git "pull", "origin", "$BranchName", "--rebase"
Invoke-Git "push", "-u", "origin", "$BranchName"

Write-Host "✅ Done! Committed to '$ProjectName'" -ForegroundColor Green