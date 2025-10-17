# =============================================================================
# Parallel Batch Runner - PowerShell Script
# =============================================================================
# Program: run_batch_parallel.ps1
# Purpose: Execute all generated batch commands in parallel
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================

param(
    [string]$CommandsFile = "batch_commands.txt",
    [int]$MaxParallel = 2,
    [switch]$Help
)

if ($Help) {
    Write-Host "Parallel Batch Runner - PowerShell Script"
    Write-Host ""
    Write-Host "Usage: .\run_batch_parallel.ps1 [parameters]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -CommandsFile  File containing batch commands (default: batch_commands.txt)"
    Write-Host "  -MaxParallel   Maximum number of parallel jobs (default: 4)"
    Write-Host "  -Help          Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run_batch_parallel.ps1"
    Write-Host "  .\run_batch_parallel.ps1 -MaxParallel 8"
    Write-Host "  .\run_batch_parallel.ps1 -CommandsFile custom_commands.txt"
    exit 0
}

Write-Host "=== Parallel Batch Runner ===" -ForegroundColor Green
Write-Host "Commands File: $CommandsFile"
Write-Host "Max Parallel Jobs: $MaxParallel"
Write-Host "Started: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host ""

# Change to script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Check if commands file exists
if (-not (Test-Path $CommandsFile)) {
    Write-Host "[ERROR] Commands file not found: $CommandsFile" -ForegroundColor Red
    Write-Host "Please run generate_batch.bat first to create the commands file" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Read commands from file
$AllLines = Get-Content $CommandsFile
$Commands = @()

foreach ($line in $AllLines) {
    $line = $line.Trim()
    # Skip comments and empty lines
    if ($line -and -not $line.StartsWith("#")) {
        # Check if line looks like an Rscript command
        if ($line.StartsWith("Rscript ")) {
            $Commands += $line
        }
    }
}

if ($Commands.Count -eq 0) {
    Write-Host "[ERROR] No valid Rscript commands found in $CommandsFile" -ForegroundColor Red
    Write-Host "Please check the commands file format" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[OK] Found $($Commands.Count) Rscript commands" -ForegroundColor Green
foreach ($cmd in $Commands) {
    Write-Host "  - $cmd" -ForegroundColor Gray
}
Write-Host ""

# Check if R is available
try {
    $null = Get-Command Rscript -ErrorAction Stop
    Write-Host "[OK] Rscript found" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Rscript not found in PATH" -ForegroundColor Red
    Write-Host "Please ensure R is installed and Rscript is in your PATH" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Record start time
$StartTime = Get-Date

# Create job script block
$JobScriptBlock = {
    param($Command, $CommandIndex)
    
    $JobStart = Get-Date
    
    try {
        # Parse the command to extract arguments
        $Parts = $Command -split '\s+', 2
        if ($Parts.Count -ge 2) {
            $ScriptPath = $Parts[1] -split '\s+' | Select-Object -First 1
            $Args = ($Parts[1] -split '\s+' | Select-Object -Skip 1) -join ' '
            
            # Run the script and capture output
            if ($Args) {
                $Result = & Rscript $ScriptPath $Args.Split(' ') 2>&1
            } else {
                $Result = & Rscript $ScriptPath 2>&1
            }
            $ExitCode = $LASTEXITCODE
        } else {
            throw "Invalid command format: $Command"
        }
        
        $JobEnd = Get-Date
        $Duration = ($JobEnd - $JobStart).TotalSeconds
        
        return @{
            CommandIndex = $CommandIndex
            Command = $Command
            Status = if ($ExitCode -eq 0) { "SUCCESS" } else { "FAILED" }
            Duration = $Duration
            ExitCode = $ExitCode
            Output = $Result -join "`n"
            StartTime = $JobStart
            EndTime = $JobEnd
        }
    }
    catch {
        $JobEnd = Get-Date
        $Duration = ($JobEnd - $JobStart).TotalSeconds
        
        return @{
            CommandIndex = $CommandIndex
            Command = $Command
            Status = "ERROR"
            Duration = $Duration
            ExitCode = -1
            Output = $_.Exception.Message
            StartTime = $JobStart
            EndTime = $JobEnd
        }
    }
}

# Run commands in parallel
Write-Host "Starting parallel execution with max $MaxParallel jobs..." -ForegroundColor Yellow
Write-Host ""

$Jobs = @()
$Completed = @()
$SuccessCount = 0
$FailedCount = 0

# Start initial batch of jobs
$CommandIndex = 0
while ($Jobs.Count -lt $MaxParallel -and $CommandIndex -lt $Commands.Count) {
    $Command = $Commands[$CommandIndex]
    $Job = Start-Job -ScriptBlock $JobScriptBlock -ArgumentList $Command, ($CommandIndex + 1)
    $Jobs += @{ Job = $Job; Command = $Command; Index = $CommandIndex + 1 }
    Write-Host "Started Job $($CommandIndex + 1): $Command" -ForegroundColor Cyan
    $CommandIndex++
}

# Monitor jobs and start new ones as they complete
while ($Jobs.Count -gt 0 -or $CommandIndex -lt $Commands.Count) {
    # Check for completed jobs
    $CompletedJobs = @()
    
    foreach ($JobInfo in $Jobs) {
        if ($JobInfo.Job.State -eq "Completed") {
            $Result = Receive-Job -Job $JobInfo.Job
            Remove-Job -Job $JobInfo.Job
            
            $Completed += $Result
            $CompletedJobs += $JobInfo
            
            if ($Result.Status -eq "SUCCESS") {
                $SuccessCount++
                Write-Host "[OK] Job $($Result.CommandIndex) COMPLETED ($([math]::Round($Result.Duration, 2))s)" -ForegroundColor Green
            } else {
                $FailedCount++
                Write-Host "[FAIL] Job $($Result.CommandIndex) FAILED ($([math]::Round($Result.Duration, 2))s)" -ForegroundColor Red
                if ($Result.Output) {
                    Write-Host "  Error: $($Result.Output -split "`n" | Select-Object -First 1)" -ForegroundColor Red
                }
            }
        }
    }
    
    # Remove completed jobs from active list
    foreach ($CompletedJob in $CompletedJobs) {
        $Jobs = $Jobs | Where-Object { $_.Job.Id -ne $CompletedJob.Job.Id }
    }
    
    # Start new jobs if slots available and commands remaining
    while ($Jobs.Count -lt $MaxParallel -and $CommandIndex -lt $Commands.Count) {
        $Command = $Commands[$CommandIndex]
        $Job = Start-Job -ScriptBlock $JobScriptBlock -ArgumentList $Command, ($CommandIndex + 1)
        $Jobs += @{ Job = $Job; Command = $Command; Index = $CommandIndex + 1 }
        Write-Host "Started Job $($CommandIndex + 1): $Command" -ForegroundColor Cyan
        $CommandIndex++
    }
    
    # Wait a bit before checking again
    Start-Sleep -Milliseconds 500
}

# Wait for any remaining jobs
if ($Jobs.Count -gt 0) {
    Write-Host "Waiting for remaining jobs to complete..." -ForegroundColor Yellow
    $Jobs | ForEach-Object { Wait-Job -Job $_.Job }
    
    foreach ($JobInfo in $Jobs) {
        $Result = Receive-Job -Job $JobInfo.Job
        Remove-Job -Job $JobInfo.Job
        $Completed += $Result
        
        if ($Result.Status -eq "SUCCESS") {
            $SuccessCount++
            Write-Host "[OK] Job $($Result.CommandIndex) COMPLETED ($([math]::Round($Result.Duration, 2))s)" -ForegroundColor Green
        } else {
            $FailedCount++
            Write-Host "[FAIL] Job $($Result.CommandIndex) FAILED ($([math]::Round($Result.Duration, 2))s)" -ForegroundColor Red
        }
    }
}

# Calculate summary
$EndTime = Get-Date
$TotalDuration = ($EndTime - $StartTime).TotalSeconds
$AverageDuration = ($Completed | Measure-Object -Property Duration -Average).Average

# Display summary
Write-Host ""
Write-Host "=== EXECUTION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total Commands: $($Commands.Count)"
Write-Host "Successful: $SuccessCount" -ForegroundColor Green
Write-Host "Failed: $FailedCount" -ForegroundColor $(if ($FailedCount -gt 0) { "Red" } else { "Green" })
Write-Host "Total Duration: $([math]::Round($TotalDuration, 2)) seconds"
Write-Host "Average per Command: $([math]::Round($AverageDuration, 2)) seconds"
Write-Host "Completed: $($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))"

if ($FailedCount -gt 0) {
    Write-Host ""
    Write-Host "Failed Commands:" -ForegroundColor Red
    $Completed | Where-Object { $_.Status -ne "SUCCESS" } | Sort-Object CommandIndex | ForEach-Object {
        Write-Host "  Job $($_.CommandIndex): $($_.Command)" -ForegroundColor Red
        if ($_.Output) {
            Write-Host "    Error: $($_.Output -split "`n" | Select-Object -First 2 | Join-String -Separator '; ')" -ForegroundColor Red
        }
    }
}

if ($SuccessCount -gt 0) {
    Write-Host ""
    Write-Host "Successful Commands:" -ForegroundColor Green
    $Completed | Where-Object { $_.Status -eq "SUCCESS" } | Sort-Object CommandIndex | ForEach-Object {
        Write-Host "  Job $($_.CommandIndex): $($_.Command) ($([math]::Round($_.Duration, 2))s)" -ForegroundColor Green
    }
}

Write-Host ""
$ExitCode = if ($FailedCount -gt 0) { 1 } else { 0 }
Read-Host "Press Enter to exit"
exit $ExitCode
