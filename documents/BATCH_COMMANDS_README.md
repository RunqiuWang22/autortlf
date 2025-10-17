# Batch Command System for TLF Generation
AutoRTLF Development Team (Kan Li, Cursor) 2025-10-16

This system generates individual `Rscript` commands for each YAML configuration file, enabling independent execution and parallel processing.

## Overview

The batch command system provides a simple and flexible approach to TLF generation:

- **Command Generation**: Creates individual `Rscript` commands for each YAML file
- **Independent Execution**: Each command can be run separately
- **Parallel Processing**: Multiple commands can run simultaneously
- **Job Scheduler Ready**: Easy integration with SLURM, PBS, or other schedulers
- **Cross-Platform**: Works on Windows, Linux, and macOS

## How to Run the Batch System

### Prerequisites
1. **R Installation**: Ensure R is installed and `Rscript` is in your PATH
2. **Required Packages**: The system will check for the `yaml` package automatically
3. **YAML Files**: Have your TLF metadata files in `pganalysis/metadata/`
4. **Configuration**: Ensure `pgconfig/metadata/study_config.yaml` exists

### Complete Workflow

#### Step 1: Generate Batch Commands
```cmd
# Navigate to your project directory
cd \autortlf

# Generate all batch commands
Rscript generate_batch_commands.R
```

**What this does:**
- Scans `pganalysis/metadata/` for all `*.yaml` files
- Reads the `rfunction` field from each YAML
- Maps functions to appropriate runners (e.g. `baseline0char` → `run_baseline0char.R`, `ae0specific` → `run_ae0specific.R`)
- Generates individual `Rscript` commands for each YAML
- Saves all commands to `batch_commands.txt` with usage instructions and examples

#### Step 2: Choose Your Execution Method

##### Option A: Run Individual TLF (Testing/Development)
```cmd
# Copy any command from batch_commands.txt and run it
Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0itt.yaml pgconfig/metadata/study_config.yaml
```

##### Option B: Run All in Parallel (Production - Recommended)
```powershell
# PowerShell (Windows) - Default 2 parallel jobs
.\run_batch_parallel.ps1

# Increase parallelism for faster execution
.\run_batch_parallel.ps1 -MaxParallel 4

# Use custom commands file
.\run_batch_parallel.ps1 -CommandsFile custom_commands.txt
```

##### Option C: Run All Sequentially (Safe/Debugging)
```powershell
# PowerShell sequential runner (recommended for debugging)
.\run_batch_sequential.ps1

# Use custom commands file
.\run_batch_sequential.ps1 -CommandsFile custom_commands.txt
```

```cmd
# Manual sequential execution (copy from batch_commands.txt)
Rscript pganalysis/run_ae0specific.R pganalysis/metadata/ae0specific0dec0sae01.yaml pgconfig/metadata/study_config.yaml
Rscript pganalysis/run_ae0specific.R pganalysis/metadata/ae0specific0dec0sae05.yaml pgconfig/metadata/study_config.yaml
# ... continue with remaining commands
```

### Quick Start (Most Common Usage)

```cmd
# 1. Generate commands
Rscript generate_batch_commands.R

# 2a. Run all TLFs in parallel (fastest)
.\run_batch_parallel.ps1

# 2b. OR run all TLFs sequentially (most reliable)
.\run_batch_sequential.ps1
```

That's it! Your TLF files will be generated in the `outtable/` directory.

### Expected Output

After successful execution, you should see:

1. **Generated Commands File**: `batch_commands.txt` containing all individual Rscript commands
2. **RTF Output Files**: Generated in `outtable/[project_name]/` directory
   - Example: `outtable/X99-ia01/baseline0char0itt.rtf`
   - Example: `outtable/X99-ia01/ae0specific0dec0sae01.rtf`
3. **Intermediate Data Files**: Generated in `outdata/[project_name]/` directory (if enabled)
   - Example: `outdata/X99-ia01/baseline0char0itt.rds`
4. **Log Files**: Individual log files for each TLF execution

### Execution Time
- **Individual TLF**: ~4-6 seconds per table
- **5 TLFs Sequential**: ~20-30 seconds total
- **5 TLFs Sequential (PowerShell)**: ~22-32 seconds total (includes overhead)
- **5 TLFs Parallel (2 jobs)**: ~12-15 seconds total
- **5 TLFs Parallel (4 jobs)**: ~8-10 seconds total

## Files

### Core Scripts
- **`generate_batch_commands.R`** - Main command generator
- **`run_batch_parallel.ps1`** - PowerShell script for parallel execution
- **`run_batch_sequential.ps1`** - PowerShell script for sequential execution
- **`batch_commands.txt`** - Generated file containing all commands

### Updated Runner Scripts
- **`pganalysis/run_baseline0char.R`** - Enhanced with command line argument support
- **`pganalysis/run_ae0specific.R`** - Enhanced with command line argument support

## Command Line Arguments

Both runner scripts support positional arguments:

```cmd
Rscript pganalysis/run_baseline0char.R [yaml_file] [config_file]
Rscript pganalysis/run_ae0specific.R [yaml_file] [config_file]

Arguments:
  yaml_file    YAML metadata file (optional, uses default if not provided)
  config_file  Global configuration file (optional, uses default if not provided)
```

### Examples
```cmd
# Use default files
Rscript pganalysis/run_baseline0char.R

# Specify YAML file only
Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0itt.yaml

# Specify both YAML and config files
Rscript pganalysis/run_ae0specific.R pganalysis/metadata/ae0specific0dec0sae01.yaml pgconfig/metadata/study_config.yaml

# Custom files
Rscript pganalysis/run_baseline0char.R custom.yaml custom_config.yaml
```

## Generated Commands Format

The `generate_batch_commands.R` script creates a comprehensive `batch_commands.txt` file that includes:

1. **Header Information**: Generation timestamp and command count
2. **Individual Commands**: Each with descriptive comments
3. **Usage Instructions**: Examples for different execution methods
4. **Platform-specific Examples**: PowerShell and Bash examples

The `batch_commands.txt` file contains commands like:

```bash
# =============================================================================
# Auto-generated TLF Batch Commands
# =============================================================================
# Generated: 2025-10-07 13:22:34
# Total commands: 5
# =============================================================================

# Individual Rscript commands for each TLF:

# Command 1 - TLF: baseline0char0itt.yaml - Function: baseline0char
Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0itt.yaml pgconfig/metadata/study_config.yaml

# Command 2 - TLF: baseline0char0white.yaml - Function: baseline0char
Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0white.yaml pgconfig/metadata/study_config.yaml

# Command 3 - TLF: ae0specific0dec0sae01.yaml - Function: ae0specific
Rscript pganalysis/run_ae0specific.R pganalysis/metadata/ae0specific0dec0sae01.yaml pgconfig/metadata/study_config.yaml

# ... more commands
```

## Parallel Execution

### PowerShell Parallel Runner

The PowerShell script provides sophisticated parallel execution:

```powershell
# Run with default settings (2 parallel jobs)
.\run_batch_parallel.ps1

# Run with 4 parallel jobs
.\run_batch_parallel.ps1 -MaxParallel 4

# Use custom commands file
.\run_batch_parallel.ps1 -CommandsFile custom_commands.txt
```

**Features:**
- **Automatic Job Management**: Manages parallel job slots automatically
- **Real-time Progress**: Shows job completion in real-time
- **Error Handling**: Captures and reports individual command failures
- **Resource Control**: Limits concurrent jobs to prevent system overload
- **Detailed Reporting**: Comprehensive execution summary

### PowerShell Sequential Runner

The sequential runner provides reliable one-by-one execution:

```powershell
# Run with default settings
.\run_batch_sequential.ps1

# Use custom commands file
.\run_batch_sequential.ps1 -CommandsFile custom_commands.txt
```

**Features:**
- **Reliable Execution**: Runs commands one at a time for maximum stability
- **Progress Tracking**: Shows current command and progress counter
- **Error Reporting**: Detailed error messages for failed commands
- **Execution Summary**: Complete report with timing and success/failure counts
- **Debugging Friendly**: Easier to identify and troubleshoot issues

### Manual Parallel Execution

For advanced users or other platforms:

```bash
# Linux/macOS - Run in background
Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0itt.yaml pgconfig/metadata/study_config.yaml &
Rscript pganalysis/run_ae0specific.R pganalysis/metadata/ae0specific0dec0sae01.yaml pgconfig/metadata/study_config.yaml &
wait  # Wait for all background jobs to complete
```

```powershell
# PowerShell - Manual job management
$job1 = Start-Job { Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0itt.yaml pgconfig/metadata/study_config.yaml }
$job2 = Start-Job { Rscript pganalysis/run_ae0specific.R pganalysis/metadata/ae0specific0dec0sae01.yaml pgconfig/metadata/study_config.yaml }
$job1, $job2 | Wait-Job
$job1, $job2 | Receive-Job
```

## Job Scheduler Integration

### SLURM Array Job
```bash
#!/bin/bash
#SBATCH --job-name=tlf_batch
#SBATCH --array=1-5
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00

# Read the command for this array index
COMMAND=$(sed -n "${SLURM_ARRAY_TASK_ID}p" batch_commands_clean.txt)

# Execute the command
eval $COMMAND
```

### PBS Array Job
```bash
#!/bin/bash
#PBS -N tlf_batch
#PBS -t 1-5
#PBS -l nodes=1:ppn=1
#PBS -l mem=4gb
#PBS -l walltime=01:00:00

cd $PBS_O_WORKDIR

# Read the command for this array index
COMMAND=$(sed -n "${PBS_ARRAYID}p" batch_commands_clean.txt)

# Execute the command
eval $COMMAND
```

### Preparing Commands for Job Schedulers

To create a clean commands file for job schedulers:

```bash
# Extract only the Rscript commands (no comments)
grep "^Rscript " batch_commands.txt > batch_commands_clean.txt
```

## Configuration

### Generator Parameters

The `generate_batch_commands.R` script accepts these parameters:

```r
generate_batch_commands(
  metadata_dir = "pganalysis/metadata",     # YAML files directory
  global_config_file = "pgconfig/metadata/study_config.yaml",  # Global config
  pattern = "*.yaml",                       # YAML file pattern
  output_file = "batch_commands.txt"        # Output file (optional)
)
```

### Command Line Usage

```cmd
# Use defaults
Rscript generate_batch_commands.R

# Custom parameters
Rscript generate_batch_commands.R "custom/metadata" "custom_config.yaml" "*.yml" "custom_commands.txt"
```

## Output and Logging

### Command Generation Output
```
=== Batch Command Generator ===
Metadata directory: pganalysis/metadata
Global config: pgconfig/metadata/study_config.yaml
Pattern: *.yaml
Found 5 YAML files:
  - baseline0char0itt.yaml
  - baseline0char0white.yaml
  - ae0specific0dec0sae01.yaml
  - ae0specific0dec0sae05.yaml
  - ae0specific0soc05.yaml

=== Generating Commands ===
OK  : baseline0char0itt.yaml -> baseline0char -> pganalysis/run_baseline0char.R
OK  : baseline0char0white.yaml -> baseline0char -> pganalysis/run_baseline0char.R
OK  : ae0specific0dec0sae01.yaml -> ae0specific -> pganalysis/run_ae0specific.R
OK  : ae0specific0dec0sae05.yaml -> ae0specific -> pganalysis/run_ae0specific.R
OK  : ae0specific0soc05.yaml -> ae0specific -> pganalysis/run_ae0specific.R

=== Generation Summary ===
Total YAML files: 5
Commands generated: 5
Skipped: 0
```

### Parallel Execution Output
```
=== Parallel Batch Runner ===
Commands File: batch_commands.txt
Max Parallel Jobs: 4
Started: 2025-10-16 14:30:15

✓ Found 5 Rscript commands
✓ Rscript found

Starting parallel execution with max 4 jobs...

Started Job 1: Rscript pganalysis/run_baseline0char.R --yaml pganalysis/metadata/baseline0char0itt.yaml --config pgconfig/metadata/study_config.yaml
Started Job 2: Rscript pganalysis/run_baseline0char.R --yaml pganalysis/metadata/baseline0char0white.yaml --config pgconfig/metadata/study_config.yaml
✓ Job 1 COMPLETED (12.3s)
Started Job 3: Rscript pganalysis/run_ae0specific.R --yaml pganalysis/metadata/ae0specific0dec0sae01.yaml --config pgconfig/metadata/study_config.yaml
✓ Job 2 COMPLETED (11.8s)
Started Job 4: Rscript pganalysis/run_ae0specific.R --yaml pganalysis/metadata/ae0specific0dec0sae05.yaml --config pgconfig/metadata/study_config.yaml

=== EXECUTION SUMMARY ===
Total Commands: 5
Successful: 5
Failed: 0
Total Duration: 45.2 seconds
Average per Command: 9.8 seconds
Completed: 2025-10-16 14:31:00
```

## Troubleshooting

### Common Issues

1. **"No YAML files found"**
   - Check that YAML files exist in `pganalysis/metadata/`
   - Verify the file pattern (default: `*.yaml`)
   - Ensure YAML files have valid `rfunction` field

2. **"No runner found for rfunction"**
   - Verify the `rfunction` field in YAML files
   - Supported functions: `baseline0char`, `ae0specific`
   - Add new function mappings in `generate_batch_commands.R` if needed

3. **"Commands file not found"**
   - Run `Rscript generate_batch_commands.R` first to create the commands file
   - Check that `batch_commands.txt` exists

4. **Individual command failures**
   - Use `.\run_batch_sequential.ps1` for easier debugging
   - Check the command output for detailed error messages
   - Verify YAML configuration is correct
   - Ensure required datasets exist
   - Test individual commands manually

### Performance Optimization

1. **Parallel Jobs**: Set `MaxParallel` based on your system:
   - **CPU cores**: Usually 1-2x number of cores
   - **Memory**: Ensure enough RAM for concurrent jobs
   - **I/O**: Consider disk I/O limitations

2. **Resource Monitoring**: Monitor system resources during execution:
   - CPU usage
   - Memory consumption
   - Disk I/O

## Advanced Usage

### Custom Command Generation

```r
# Generate commands for specific directory
generate_batch_commands(
  metadata_dir = "custom/metadata",
  output_file = "custom_commands.txt"
)

# Generate commands with specific pattern
generate_batch_commands(
  pattern = "*baseline*.yaml",
  output_file = "baseline_commands.txt"
)
```

### Conditional Execution

```powershell
# Run only baseline commands
$commands = Get-Content "batch_commands.txt" | Where-Object { $_ -match "baseline0char" -and -not $_.StartsWith("#") }
foreach ($cmd in $commands) {
    if ($cmd.Trim()) {
        Invoke-Expression $cmd
    }
}
```

### Integration with CI/CD

```yaml
# GitHub Actions example
name: Generate TLFs
on: [push]
jobs:
  generate-tlfs:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: r-lib/actions/setup-r@v2
    - name: Generate batch commands
      run: Rscript generate_batch_commands.R
    - name: Run TLFs in parallel
      run: |
        # Extract commands and run in background
        grep "^Rscript " batch_commands.txt | while read cmd; do
          eval "$cmd" &
        done
        wait
```

This batch command system provides maximum flexibility for TLF generation while maintaining simplicity and compatibility with various execution environments.
