# =============================================================================
# Baseline Analysis Runner
# =============================================================================
# Program: run_baseline0char.R
# Purpose: Simple runner for baseline characteristics analysis
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================
rm(list = ls())

# Source the setup functions
source("function/global/setup_functions.R")
# Source the complete baseline analysis function
source("function/standard/baseline0char.R")

#' Main function for baseline analysis
#'
#' @param metadata_file Path to metadata YAML file (default: pganalysis/metadata/baseline0char.yaml)
#' @param global_config_file Path to global config file (default: pgconfig/metadata/study_config.yaml)
#' @param verbose Whether to print progress messages
main <- function(metadata_file = "pganalysis/metadata/baseline0char.yaml",
                global_config_file = "pgconfig/metadata/study_config.yaml",
                verbose = TRUE) {
  
  # start time
  start_time <- Sys.time()
  
  # Check if files exist
  if (!file.exists(metadata_file)) {
    stop(paste("Metadata file not found:", metadata_file))
  }
  
  if (!file.exists(global_config_file)) {
    stop(paste("Global config file not found:", global_config_file))
  }

   if (verbose) cat("=== Starting Baseline Analysis Pipeline ===\n")
  
  # Step 1: Setup environment
  setup_tlf_environment(verbose = verbose)
  
  # Step 2: Load configurations
  if (verbose) cat("Loading configurations...\n")
  
  if (is.null(global_config_file)) {
    global_config_file <- "pgconfig/metadata/study_config.yaml"
  }
  
  global_config <- load_global_config(global_config_file)
  meta <- load_tlfs_meta(metadata_file, global_config)
  meta <- resolve_global_in_meta(meta, global_config)
  
  if (verbose) {
    cat("Global config loaded from:", global_config_file, "\n")
    cat("Metadata loaded from:", metadata_file, "\n")
    cat("Analysis for:", meta$title %||% "Baseline Table", "\n")
  }
  
  # Initialize log file
  log_file <- initialize_log(global_config, meta, verbose = verbose)
  
  # Clear message counts for this run
  clear_message_counts()
  
  # Run the complete analysis pipeline with message capture
  tryCatch({
    results <- with_message_logging({
      baseline0char(
        meta = meta,
        global_config= global_config, 
        verbose = verbose,
        log_file = log_file
      )
    }, log_file)
    
    if (verbose) {
      cat("\n=== Analysis Summary ===\n")
      cat("Metadata file:", metadata_file, "\n")
      cat("Global config:", global_config_file, "\n")
      cat("Output RTF:", results$output_files$rtf_file, "\n")
      cat("Table rows:", nrow(results$baseline_table), "\n")
      cat("Table columns:", ncol(results$baseline_table), "\n")
      
      # Show captured message counts
      msg_counts <- get_message_counts()
      if (msg_counts$warnings > 0 || msg_counts$errors > 0) {
        cat("Messages captured:", msg_counts$warnings, "warnings,", msg_counts$errors, "errors\n")
      }
      
      cat("Analysis completed successfully!\n")
    }

    end_time <- Sys.time()
    duration_seconds <- difftime(end_time, start_time, units = "secs")
    finalize_log_with_messages(log_file, success = TRUE, input_files = list(metadata_file = metadata_file, global_config_file = global_config_file), output_files = results$output_files, duration_seconds = duration_seconds )
    
    #return(results)
    
  }, error = function(e) {
    # Log the error and finalize
    append_log(log_file, paste("FATAL ERROR:", e$message), "ERROR")
    
    end_time <- Sys.time()
    duration_seconds <- difftime(end_time, start_time, units = "secs")
    finalize_log_with_messages(log_file, success = TRUE, input_files = list(metadata_file = metadata_file, global_config_file = global_config_file), output_files = results$output_files, duration_seconds = duration_seconds )
    
    cat("ERROR:", e$message, "\n", file = stderr())
    cat("Check log file for details:", log_file, "\n", file = stderr())
    return(NULL)
  })
}

# Run if called directly
if (!interactive()) {
  # Parse command line arguments if needed
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) >= 1) {
    metadata_file <- args[1]
  } else {
    metadata_file <- "pganalysis/metadata/baseline0char.yaml"
  }
  
  if (length(args) >= 2) {
    global_config_file <- args[2]
  } else {
    global_config_file <- "pgconfig/metadata/study_config.yaml"
  }
  
  main(metadata_file, global_config_file, verbose = TRUE)
}
