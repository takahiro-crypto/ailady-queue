# uninstall-schtasks.ps1 — AILady Worker タスクを全削除
#
# 使い方:
#   PS> .\uninstall-schtasks.ps1

param(
    [string[]]$Pcs = @("pc1-billing","pc2-expense","pc3-payroll","pc4-hr","pc5-cs","pc6-quote")
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
