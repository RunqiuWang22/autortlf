#!/usr/env/bin Rscript
# =============================================================================
# Time to First Adverse Event Runner
# =============================================================================
# Program: run_tte0ae.R
# Purpose: Simple runner for TTE AE analysis
# Version: 1.0.0
# Created: 2026-03-09
# Author: AutoRTLF Development Team (AI Assistant)
# =============================================================================
rm(list = ls())

source("function/global/setup_functions.R")
source("function/standard/tte0ae.R")

main <- function(metadata_file = "metadatalib/tte0ae0test.yaml",
                 global_config_file = "pgconfig/metadata/study_config.yaml",
                 verbose = TRUE) {
    start_time <- Sys.time()

    if (!file.exists(metadata_file)) stop(paste("Metadata file not found:", metadata_file))
    if (!file.exists(global_config_file)) stop(paste("Global config file not found:", global_config_file))

    if (verbose) cat("=== Starting TTE AE Analysis Pipeline ===\n")

    setup_tlf_environment(verbose = verbose)
    global_config <- load_global_config(global_config_file)
    meta <- load_tlfs_meta(metadata_file, global_config)
    meta <- resolve_global_in_meta(meta, global_config)

    log_file <- initialize_log(global_config, meta, verbose = verbose)
    clear_message_counts()

    tryCatch(
        {
            results <- with_message_logging(
                {
                    tte0ae(meta = meta, global_config = global_config, verbose = verbose, log_file = log_file)
                },
                log_file
            )

            if (verbose) {
                cat("\n=== Analysis Summary ===\n")
                cat("Output RTF:", results$output_files$rtf_file, "\n")
                cat("Analysis completed successfully!\n")
            }

            end_time <- Sys.time()
            duration_seconds <- difftime(end_time, start_time, units = "secs")
            finalize_log_with_messages(log_file, success = TRUE, input_files = list(metadata_file = metadata_file, global_config_file = global_config_file), output_files = results$output_files, duration_seconds = duration_seconds)
        },
        error = function(e) {
            append_log(log_file, paste("FATAL ERROR:", e$message), "ERROR")
            end_time <- Sys.time()
            duration_seconds <- difftime(end_time, start_time, units = "secs")
            finalize_log_with_messages(log_file, success = FALSE, input_files = list(metadata_file = metadata_file, global_config_file = global_config_file), duration_seconds = duration_seconds)
            cat("ERROR:", e$message, "\n", file = stderr())
        }
    )
}

if (!interactive()) {
    args <- commandArgs(trailingOnly = TRUE)
    metadata_file <- if (length(args) >= 1) args[1] else "metadatalib/tte0ae0test.yaml"
    global_config_file <- if (length(args) >= 2) args[2] else "pgconfig/metadata/study_config.yaml"
    main(metadata_file, global_config_file, verbose = TRUE)
}
