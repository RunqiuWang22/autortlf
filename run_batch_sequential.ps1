# =============================================================================
# Sequential Batch Runner - PowerShell Script
# =============================================================================
# Program: run_batch_sequential.ps1
# Purpose: Execute all generated batch commands sequentially
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================

param(
    [string]$CommandsFile = "batch_commands.txt",
    [switch]$Help
)

if ($Help) {
    Write-Host "Sequential Batch Runner - PowerShell Script"
    Write-Host ""
    Write-Host "Usage: .\run_batch_sequential.ps1 [parameters]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -CommandsFile  File containing batch commands (default: batch_commands.txt)"
    Write-Host "  -Help          Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run_batch_sequential.ps1"
    Write-Host "  .\run_batch_sequential.ps1 -CommandsFile custom_commands.txt"
    exit 0
}

Write-Host "=== Sequential Batch Runner ===" -ForegroundColor Green
Write-Host "Commands File: $CommandsFile"
Write-Host "Started: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host ""

# Change to script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Check if commands file exists
if (-not (Test-Path $CommandsFile)) {
    Write-Host "[ERROR] Commands file not found: $CommandsFile" -ForegroundColor Red
    Write-Host "Please run 'Rscript generate_batch_commands.R' first to create the commands file" -ForegroundColor Yellow
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

# Execute commands sequentially
$SuccessCount = 0
$FailedCount = 0
$Results = @()

Write-Host ""
Write-Host "Starting sequential execution..." -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $Commands.Count; $i++) {
    $Command = $Commands[$i]
    $CommandIndex = $i + 1
    
    Write-Host "[$CommandIndex/$($Commands.Count)] Running: $Command" -ForegroundColor Cyan
    
    $JobStart = Get-Date
    
    try {
        # Parse the command to extract arguments
        $Parts = $Command -split '\s+', 2
        if ($Parts.Count -ge 2) {
            $ScriptPath = $Parts[1] -split '\s+' | Select-Object -First 1
            $Args = ($Parts[1] -split '\s+' | Select-Object -Skip 1)
            
            # Run the script and capture output
            if ($Args.Count -gt 0) {
                $Result = & Rscript $ScriptPath $Args 2>&1
            } else {
                $Result = & Rscript $ScriptPath 2>&1
            }
            $ExitCode = $LASTEXITCODE
        } else {
            throw "Invalid command format: $Command"
        }
        
        $JobEnd = Get-Date
        $Duration = ($JobEnd - $JobStart).TotalSeconds
        
        if ($ExitCode -eq 0) {
            $SuccessCount++
            Write-Host "  [OK] Completed in $([math]::Round($Duration, 2)) seconds" -ForegroundColor Green
            $Status = "SUCCESS"
        } else {
            $FailedCount++
            Write-Host "  [FAIL] Failed with exit code $ExitCode in $([math]::Round($Duration, 2)) seconds" -ForegroundColor Red
            # Show first few lines of error output
            $ErrorLines = $Result | Where-Object { $_ -match "Error|error|ERROR" } | Select-Object -First 2
            if ($ErrorLines) {
                foreach ($ErrorLine in $ErrorLines) {
                    Write-Host "    Error: $ErrorLine" -ForegroundColor Red
                }
            }
            $Status = "FAILED"
        }
        
        $Results += @{
            CommandIndex = $CommandIndex
            Command = $Command
            Status = $Status
            Duration = $Duration
            ExitCode = $ExitCode
            Output = $Result -join "`n"
        }
        
    } catch {
        $JobEnd = Get-Date
        $Duration = ($JobEnd - $JobStart).TotalSeconds
        
        $FailedCount++
        Write-Host "  [ERROR] Exception: $($_.Exception.Message)" -ForegroundColor Red
        
        $Results += @{
            CommandIndex = $CommandIndex
            Command = $Command
            Status = "ERROR"
            Duration = $Duration
            ExitCode = -1
            Output = $_.Exception.Message
        }
    }
    
    Write-Host ""
}

# Calculate summary
$EndTime = Get-Date
$TotalDuration = ($EndTime - $StartTime).TotalSeconds
$AverageDuration = if ($Results.Count -gt 0) { 
    ($Results | ForEach-Object { $_.Duration } | Measure-Object -Average).Average 
} else { 0 }

# Display summary
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
    $Results | Where-Object { $_.Status -ne "SUCCESS" } | ForEach-Object {
        Write-Host "  Command $($_.CommandIndex): $($_.Status)" -ForegroundColor Red
        Write-Host "    $($_.Command)" -ForegroundColor Gray
    }
}

if ($SuccessCount -gt 0) {
    Write-Host ""
    Write-Host "Successful Commands:" -ForegroundColor Green
    $Results | Where-Object { $_.Status -eq "SUCCESS" } | ForEach-Object {
        Write-Host "  Command $($_.CommandIndex): $([math]::Round($_.Duration, 2))s" -ForegroundColor Green
    }
}

Write-Host ""
$ExitCode = if ($FailedCount -gt 0) { 1 } else { 0 }
Read-Host "Press Enter to exit"
exit $ExitCode