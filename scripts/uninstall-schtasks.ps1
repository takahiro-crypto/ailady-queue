# uninstall-schtasks.ps1 — AILady Worker タスクを全削除
#
# 使い方:
#   PS> .\uninstall-schtasks.ps1

param(
    [string[]]$Pcs = @("role1-billing","role2-expense","role3-payroll","role4-hr","role5-cs","role6-quote")
)

$ErrorActionPreference = "Stop"

Write-Host "Removing AILady Worker scheduled tasks..." -ForegroundColor Cyan
foreach ($pc in $Pcs) {
    $taskName = "AILady Worker " + ($pc.ToUpper())
    $out = & schtasks /Delete /TN $taskName /F 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK]   removed $taskName" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] $taskName : $($out -join ' ')" -ForegroundColor Yellow
    }
}
Write-Host "Done."
