# Disk Cleanup (Windows)
# Frees disk space by cleaning temporary files, caches, and logs
Write-Host "Starting disk cleanup..."

# Clean temp folders
$tempPaths = @(
    $env:TEMP,
    "$env:WINDIR\Temp",
    "$env:LOCALAPPDATA\Temp"
)
$totalFreed = 0
foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
        $totalFreed += $size
        Write-Host "Cleaned: $path"
    }
}

# Clean Windows Update cache
$wuPath = "$env:WINDIR\SoftwareDistribution\Download"
if (Test-Path $wuPath) {
    $size = (Get-ChildItem -Path $wuPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    Remove-Item -Path "$wuPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    $totalFreed += $size
    Write-Host "Cleaned: Windows Update cache"
}

# Clean Recycle Bin
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "Cleaned: Recycle Bin"
} catch {}

$freedMB = [math]::Round($totalFreed / 1MB, 2)
Write-Host "Disk cleanup complete. Approximately ${freedMB} MB freed."
