# =============================================================================
# Batch Command Generator
# =============================================================================
# Program: generate_batch_commands.R
# Purpose: Generate Rscript commands for each YAML file based on rfunction
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================

rm(list = ls())

# Load required libraries
if (!require(yaml, quietly = TRUE)) {
  stop("Package 'yaml' is required but not installed. Please install it with: install.packages('yaml')")
}

# Define null-coalescing operator if not available
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Get R function name from YAML metadata file
#'
#' @param yaml_file Path to YAML file
#' @return R function name from the YAML file
get_function_from_yaml <- function(yaml_file) {
  tryCatch({
    meta <- yaml::read_yaml(yaml_file)
    return(meta$rfunction %||% "unknown")
  }, error = function(e) {
    cat("Warning: Could not read rfunction from", yaml_file, ":", e$message, "\n")
    return("unknown")
  })
}

#' Validate generated commands
#'
#' @param commands Vector of generated commands
#' @return List with validation results
validate_commands <- function(commands) {
  if (length(commands) == 0) {
    return(list(valid = FALSE, message = "No commands generated"))
  }
  
  # Check if all commands start with Rscript
  invalid_commands <- commands[!grepl("^Rscript ", commands)]
  if (length(invalid_commands) > 0) {
    return(list(
      valid = FALSE, 
      message = paste("Invalid command format found:", invalid_commands[1])
    ))
  }
  
  # Check if all referenced files exist
  for (cmd in commands) {
    parts <- strsplit(cmd, " ")[[1]]
    if (length(parts) >= 2) {
      script_file <- parts[2]
      if (!file.exists(script_file)) {
        return(list(
          valid = FALSE,
          message = paste("Runner script not found:", script_file)
        ))
      }
    }
    if (length(parts) >= 3) {
      yaml_file <- parts[3]
      if (!file.exists(yaml_file)) {
        return(list(
          valid = FALSE,
          message = paste("YAML file not found:", yaml_file)
        ))
      }
    }
  }
  
  return(list(valid = TRUE, message = "All commands validated successfully"))
}

#' Generate batch commands for all YAML files
#'
#' @param metadata_dir Directory containing YAML metadata files
#' @param global_config_file Path to global configuration file
#' @param pattern Pattern to match YAML files
#' @param output_file File to save batch commands (optional)
#' @return List of generated commands
generate_batch_commands <- function(metadata_dir = "pganalysis/metadata",
                                  global_config_file = "pgconfig/metadata/study_config.yaml",
                                  pattern = "*.yaml",
                                  output_file = NULL) {
  
  cat("=== Batch Command Generator ===\n")
  cat("Metadata directory:", metadata_dir, "\n")
  cat("Global config:", global_config_file, "\n")
  cat("Pattern:", pattern, "\n")
  if (!is.null(output_file)) {
    cat("Output file:", output_file, "\n")
  }
  cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  
  # Check if metadata directory exists
  if (!dir.exists(metadata_dir)) {
    stop(paste("Metadata directory not found:", metadata_dir))
  }
  
  # Check if global config file exists
  if (!file.exists(global_config_file)) {
    cat("Warning: Global config file not found:", global_config_file, "\n")
    cat("Commands will be generated but may fail during execution.\n")
  }
  
  # Find all YAML files
  yaml_files <- list.files(metadata_dir, pattern = pattern, full.names = TRUE)
  
  if (length(yaml_files) == 0) {
    cat("No YAML files found in", metadata_dir, "with pattern", pattern, "\n")
    return(character(0))
  }
  
  cat("Found", length(yaml_files), "YAML files:\n")
  for (f in yaml_files) {
    cat("  -", basename(f), "\n")
  }
  cat("\n")
  
  # Generate commands
  commands <- character()
  success_count <- 0
  failed_count <- 0
  
  cat("=== Generating Commands ===\n")
  
  for (yaml_file in yaml_files) {
    yaml_basename <- basename(yaml_file)
    
    # Get function name from YAML
    func_name <- get_function_from_yaml(yaml_file)
    
    if (func_name == "unknown") {
      cat("SKIP:", yaml_basename, "- Could not determine rfunction\n")
      failed_count <- failed_count + 1
      next
    }
    
    # Determine which runner to use
    runner_file <- paste0("pganalysis/run_", func_name, ".R")
    
    
    if (is.null(runner_file)) {
      cat("SKIP:", yaml_basename, "- No runner found for rfunction", func_name, "\n")
      failed_count <- failed_count + 1
      next
    }
    
    # Check if runner file exists
    if (!file.exists(runner_file)) {
      cat("SKIP:", yaml_basename, "- Runner file not found:", runner_file, "\n")
      failed_count <- failed_count + 1
      next
    }
    
     # Generate command
     # Use positional arguments (yaml_file, global_config_file)
     command <- paste("Rscript", runner_file, yaml_file, global_config_file)
    commands <- c(commands, command)
    
    cat("OK  :", yaml_basename, "->", func_name, "->", runner_file, "\n")
    success_count <- success_count + 1
  }
  
  # Summary
  cat("\n=== Generation Summary ===\n")
  cat("Total YAML files:", length(yaml_files), "\n")
  cat("Commands generated:", success_count, "\n")
  cat("Skipped:", failed_count, "\n")
  
  # Validate generated commands
  if (success_count > 0) {
    cat("\n=== Validation ===\n")
    validation_result <- validate_commands(commands)
    if (validation_result$valid) {
      cat("✓", validation_result$message, "\n")
    } else {
      cat("✗", validation_result$message, "\n")
      cat("Warning: Some commands may fail during execution.\n")
    }
  }
  
  if (success_count > 0) {
    cat("\n=== Generated Commands ===\n")
    for (i in seq_along(commands)) {
      cat(sprintf("%2d. %s\n", i, commands[i]))
    }
    
    # Save to file if requested
    if (!is.null(output_file)) {
      cat("\n=== Saving to File ===\n")
      
      # Create header for the batch file
      batch_content <- c(
        "# =============================================================================",
        "# Auto-generated TLF Batch Commands",
        "# =============================================================================",
        paste("# Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
        paste("# Total commands:", length(commands)),
        "# =============================================================================",
        "",
        "# Individual Rscript commands for each TLF:",
        ""
      )
      
      # Add each command with comments
      for (i in seq_along(commands)) {
        yaml_file <- yaml_files[i]
        yaml_basename <- basename(yaml_file)
        func_name <- get_function_from_yaml(yaml_file)
        
        batch_content <- c(
          batch_content,
          paste("# Command", i, "- TLF:", yaml_basename, "- Function:", func_name),
          commands[i],
          ""
        )
      }
      
      # Add usage instructions
      batch_content <- c(
        batch_content,
        "",
        "# =============================================================================",
        "# Usage Instructions:",
        "# =============================================================================",
        "# 1. Run individual command:",
        "#    Copy and paste any command above",
        "#",
        "# 2. Run all sequentially (PowerShell):",
        "#    .\\run_batch_sequential.ps1",
        "#",
        "# 3. Run all in parallel (PowerShell):",
        "#    .\\run_batch_parallel.ps1",
        "#    .\\run_batch_parallel.ps1 -MaxParallel 4",
        "#",
        "# 4. Manual sequential execution:",
        "#    Execute each command one by one",
        "#",
        "# 5. Manual parallel (PowerShell example):",
        "#    $jobs = @()",
        paste0("#    ", paste(sprintf("$jobs += Start-Job { %s }", commands[1:min(3, length(commands))]), collapse = "\n#    ")),
        "#    ...",
        "#    $jobs | Wait-Job",
        "#    $jobs | Receive-Job",
        "#",
        "# 6. Manual parallel (Bash example):",
        paste0("#    ", paste(sprintf("%s &", commands[1:min(3, length(commands))]), collapse = "\n#    ")),
        "#    ...",
        "#    wait",
        ""
      )
      
      writeLines(batch_content, output_file)
      cat("Commands saved to:", output_file, "\n")
    }
    
    cat("\n=== Usage Examples ===\n")
    cat("Run individual command:\n")
    cat("  ", commands[1], "\n")
    
    cat("\nRun all sequentially (PowerShell):\n")
    cat("  .\\run_batch_sequential.ps1\n")
    
    cat("\nRun all in parallel (PowerShell):\n")
    cat("  .\\run_batch_parallel.ps1\n")
    cat("  .\\run_batch_parallel.ps1 -MaxParallel 4\n")
    
    if (length(commands) > 1) {
      cat("\nManual sequential execution:\n")
      for (cmd in commands[1:min(3, length(commands))]) {
        cat("  ", cmd, "\n")
      }
      if (length(commands) > 3) {
        cat("  ... (", length(commands) - 3, "more commands)\n")
      }
    }
    
    cat("\nManual parallel (PowerShell):\n")
    for (cmd in commands[1:min(2, length(commands))]) {
      cat("  Start-Job {", cmd, "}\n")
    }
    if (length(commands) > 2) {
      cat("  ... (", length(commands) - 2, "more jobs)\n")
    }
    cat("  Get-Job | Wait-Job\n")
    
    cat("\nManual parallel (Bash):\n")
    for (cmd in commands[1:min(2, length(commands))]) {
      cat("  ", cmd, " &\n")
    }
    if (length(commands) > 2) {
      cat("  ... (", length(commands) - 2, "more background jobs)\n")
    }
    cat("  wait\n")
  }
  
  return(commands)
}

# Run if called directly
if (!interactive()) {
  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  
  # Default parameters
  metadata_dir <- "pganalysis/metadata"
  global_config_file <- "pgconfig/metadata/study_config.yaml"
  pattern <- "*.yaml"
  output_file <- "batch_commands.txt"
  
  # Parse arguments
  if (length(args) >= 1) metadata_dir <- args[1]
  if (length(args) >= 2) global_config_file <- args[2]
  if (length(args) >= 3) pattern <- args[3]
  if (length(args) >= 4) output_file <- args[4]
  
  # Generate commands
  commands <- generate_batch_commands(
    metadata_dir = metadata_dir,
    global_config_file = global_config_file,
    pattern = pattern,
    output_file = output_file
  )
  
  # Exit with appropriate code
  if (length(commands) == 0) {
    quit(status = 1)
  } else {
    quit(status = 0)
  }
} else {
  cat("=== Batch Command Generator (Interactive Mode) ===\n")
  cat("Available functions:\n")
  cat("  generate_batch_commands()                    - Generate commands (display only)\n")
  cat("  generate_batch_commands(output_file = 'batch_commands.txt') - Generate and save to file\n")
  cat("\nParameters:\n")
  cat("  metadata_dir      - Directory with YAML files (default: 'pganalysis/metadata')\n")
  cat("  global_config_file - Global config file (default: 'pgconfig/metadata/study_config.yaml')\n")
  cat("  pattern          - File pattern (default: '*.yaml')\n")
  cat("  output_file      - Output file (default: NULL for display only)\n")
  cat("\nExample:\n")
  cat("  generate_batch_commands(metadata_dir = 'custom/metadata', output_file = 'my_commands.txt')\n")
}
