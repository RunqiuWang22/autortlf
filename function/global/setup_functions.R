# =============================================================================
# Global Setup Functions
# =============================================================================
# Program: setup_functions.R
# Purpose: Global setup, library loading, and configuration functions
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================


# load all the functions in global folder besides setup_functions.R
files <- list.files("function/global", pattern = "\\.R$", full.names = TRUE)
files <- files[files != "function/global/setup_functions.R"]
for (file in files) {
  source(file)
}

#' Setup TLF environment and load required libraries
#'
#' @param verbose Logical, whether to print setup messages
#' @export
setup_tlf_environment <- function(verbose = TRUE) {
  
  if (verbose) cat("Setting up TLF environment...\n")
  
  # Required libraries for TLF generation
  required_packages <- c(
    "yaml",      # YAML configuration
    "jsonlite",  # JSON handling
    "dplyr",     # Data manipulation
    "tidyr",     # Data reshaping
    "rlang",     # Non-standard evaluation
    "stringr",   # String manipulation
    "r2rtf"      # RTF output
  )
  
  # Load packages quietly
  for (pkg in required_packages) {
    suppressPackageStartupMessages(
      library(pkg, character.only = TRUE, warn.conflicts = FALSE)
    )
  }
  
  if (verbose) cat("Libraries loaded successfully.\n")
  
  # Set global options
  options(stringsAsFactors = FALSE)
  
  if (verbose) cat("TLF environment setup complete.\n")
}

#' Load and resolve global configuration
#'
#' @param config_path Path to study configuration file
#' @return List containing resolved global configuration
#' @export
load_global_config <- function(config_path) {
  
  if (!file.exists(config_path)) {
    stop(paste("Global configuration file not found:", config_path))
  }
  
  # Load YAML configuration
  global_config <- yaml::read_yaml(config_path)
  
  # Resolve paths to absolute paths if needed
  if (!is.null(global_config$paths$study_root)) {
    study_root <- global_config$paths$study_root
    for (path_name in names(global_config$paths)) {
      if (path_name != "study_root") {
        path_value <- global_config$paths[[path_name]]
        if (!file.path.is.absolute(path_value)) {
          global_config$paths[[path_name]] <- file.path(study_root, path_value)
        }
      }
    }
  }

  # replace the value {data_cutoff_date} with the corresponding value from global_config
  global_config$titles$footnotes$data_cutoff <- str_replace_all(global_config$titles$footnotes$data_cutoff, "\\{data_cutoff_date\\}", global_config$study_info$data_cutoff_date)
  global_config$titles$footnotes$data_source_text <- str_replace_all(global_config$titles$footnotes$data_source_text, "\\{study_id\\}", global_config$study_info$study_id)

  return(global_config)
}

#' Load TLFs metadata and preprocess the title
#'
#' @param metadata_path Path to metadata file
#' @param global_config Global configuration list
#' @return Metadata with preprocessed title
#' @export
load_tlfs_meta <- function(metadata_path, global_config) {
meta <- yaml::read_yaml(metadata_path)
# Preprocess the title if display_tableid_in_title is TRUE
display_tableid <- global_config$formatting$display_options$display_tableid_in_title %||% FALSE
if (isTRUE(display_tableid)) {
  table_id <- meta$table_id %||% ""
  title <- meta$title %||% ""
  # Remove any leading/trailing whitespace or newlines from title
  title_clean <- trimws(title)
  meta$title <- paste0(table_id, "\t", title_clean)
}
return(meta)
}


#' Resolve GLOBAL references in metadata
#'
#' @param obj Metadata list with potential GLOBAL references
#' @param global_config Global configuration list
#' @return Metadata with resolved GLOBAL references
#' @export
 # Recursively replace any value in meta that contains 'GLOBAL.' with the corresponding value from global_config
resolve_global_in_meta <- function(obj, global_config) {
	if (is.list(obj)) {
	  lapply(obj, resolve_global_in_meta, global_config)
	} else if (is.character(obj) && any(grepl("GLOBAL\\.", obj))) {
	  # Replace all occurrences of GLOBAL.<path> in the string, even if there are multiple per string
	  s <- obj
	  # Find all matches of GLOBAL.<...>
	  matches <- gregexpr("GLOBAL\\.[A-Za-z0-9_.]+", s)[[1]]
	  if (matches[1] != -1) {
		# Replace from right to left to avoid messing up indices
		for (i in rev(seq_along(matches))) {
		  start <- matches[i]
		  len <- attr(matches, "match.length")[i]
		  global_ref <- substr(s, start, start + len - 1)
		  # Extract the path after GLOBAL.
		  path <- sub("^GLOBAL\\.", "", global_ref)
		  path_parts <- strsplit(path, "\\.")[[1]]
		  value <- global_config
		  for (part in path_parts) {
			if (is.list(value) && part %in% names(value)) {
			  value <- value[[part]]
			} else {
			  value <- global_ref
			  break
			}
		  }
		  # Replace the reference in the string at the correct position
		  s <- paste0(
			substr(s, 1, start - 1),
			as.character(value),
			substr(s, start + len, nchar(s))
		  )
		}
	  }
	  s
	} else {
	  obj
	}
}       

  #' Load analysis dataset
#'
#' @param dataset_name Name of dataset to load
#' @param global_config Global configuration
#' @param verbose Logical for progress messages
#' @return Data frame
load_analysis_dataset <- function(dataset_name, global_config, verbose = TRUE) {
  
  if (!dataset_name %in% names(global_config$datasets)) {
    stop(paste("Dataset", dataset_name, "not found in global configuration"))
  }
  
  dataset_info <- global_config$datasets[[dataset_name]]
  data_path <- file.path(global_config$paths$dataadam_path, paste0(dataset_info$filename,'.',dataset_info$format))
  
  if (!file.exists(data_path)) {
    stop(paste("Dataset file not found:", data_path))
  }
  
  if (verbose) cat("Loading dataset:", data_path, "\n")
  
  if (dataset_info$format == "rda") {
    env <- new.env()
    load(data_path, envir = env)
    dataset <- get(ls(env)[1], envir = env)
  } else if (dataset_info$format == "csv") {
    dataset <- read.csv(data_path, stringsAsFactors = FALSE)
  } else {
    stop(paste("Unsupported dataset format:", dataset_info$format))
  }
  
  if (verbose) cat("Dataset loaded:", nrow(dataset), "rows,", ncol(dataset), "columns\n")
  
  return(dataset)
}

#' Apply dataset filter
#'
#' @param dataset Input data frame
#' @param filter_expression Filter expression string
#' @param verbose Logical for progress messages
#' @return Filtered data frame
apply_dataset_filter <- function(dataset, filter_expression, verbose = TRUE) {
  
  if (is.null(filter_expression) || filter_expression == "") {
    if (verbose) cat("No dataset filter applied\n")
    return(dataset)
  }
  
  if (verbose) cat("Applying dataset filter:", filter_expression, "\n")
  
  tryCatch({
    filtered_dataset <- dataset %>% filter(!!rlang::parse_expr(filter_expression))
    
    if (verbose) {
      cat("Dataset filter applied:", nrow(filtered_dataset), "rows remaining\n")
    }
    
    if (nrow(filtered_dataset) == 0) {
      stop("No data remaining after applying dataset filter")
    }
    
    return(filtered_dataset)
    
  }, error = function(e) {
    stop(paste("Error applying dataset filter:", e$message))
  })
}


#' Save intermediate data
#'
#' @param data_table Data for generating table
#' @param meta Metadata configuration
#' @param global_config Global configuration
#' @param verbose Logical for progress messages
save_intermediate_data <- function(data_table, meta, global_config, verbose = TRUE) {
  
  data.format = meta$output_format$output_data_format
  
  project_name <- global_config$study_info$project
  outdata_dir <- file.path(global_config$paths$outdata_path, project_name)
  
  if (!dir.exists(outdata_dir)) {
    dir.create(outdata_dir, recursive = TRUE, showWarnings = FALSE)
  }

  if(is.null(data_table)) {
    data_table <- data.frame(Content = global_config$formatting$display_options$no_data_available_text)
  }
  
  # Save as CSV or RDS
  if (data.format == "csv") {
    data_file <- file.path(outdata_dir, paste0(meta$rename_output, ".csv"))
    write.csv(data_table, data_file, row.names = FALSE)
    if (verbose) {
      cat("Intermediate data saved:\n")
      cat("  CSV:", data_file, "\n")
    }
  } else if (data.format == "rds") {
    data_file <- file.path(outdata_dir, paste0(meta$rename_output, ".rds"))
    saveRDS(data_table, data_file)
    if (verbose) {
      cat("Intermediate data saved:\n")
      cat("  RDS:", data_file, "\n")
    }
  } else {
    stop("Unsupported data format")
  }

  return(data_file)

  # # Generate AI-ready data and narratives
  # if (verbose) cat("Generating AI-ready data and narratives...\n")
  # ai_files <- generate_ai_ready_outputs(data_table, meta, global_config, verbose)
  
  # return(list(
  #   data_file = data_file,
  #   ai_files = ai_files
  # ))
}

#' Helper function to check if path is absolute
#'
#' @param path Character path
#' @return Logical
file.path.is.absolute <- function(path) {
  if (.Platform$OS.type == "windows") {
    grepl("^[A-Za-z]:", path) || grepl("^\\\\\\\\", path)
  } else {
    grepl("^/", path)
  }
}

#' Null-coalescing operator
#'
#' @param x First value
#' @param y Second value (used if x is NULL)
#' @return x if not NULL, otherwise y
`%||%` <- function(x, y) if (is.null(x)) y else x



########################################
# functions to output log file
#########################################


#' Initialize comprehensive log file
#'
#' Creates a detailed log file with system information, session details, and run parameters
#'
#' @param global_config Global configuration list
#' @param meta Table metadata
#' @param log_messages Optional initial messages to include
#' @return Character string with path to log file
#' @export
initialize_log <- function(global_config, meta, verbose = TRUE, log_messages = character()) {
  
  table_id <- meta$table_id
  
  # Get log directory
  project_name <- global_config$study_info$project
  log_dir <- file.path(global_config$paths$outlog_path, project_name)
  
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }
  

  log_file <- file.path(log_dir, paste0(meta$rename_output,  ".log"))
  
  # Initialize log content
  log_content <- c(
    "===============================================================================",
    paste("TLF GENERATION LOG -", table_id),
    "===============================================================================",
    paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste("User:", Sys.getenv("USERNAME", "unknown")),
    paste("Working Directory:", getwd()),
    "",
    "--- SYSTEM INFORMATION ---",
    paste("R Version:", paste(R.version$major, R.version$minor, sep = ".")),
    paste("Platform:", R.version$platform),
    paste("OS:", R.version$os),
    paste("System:", Sys.info()["sysname"]),
    paste("Release:", Sys.info()["release"]),
    paste("Machine:", Sys.info()["machine"]),
    "",
    "--- SESSION INFORMATION ---"
  )
  
  # Add session info
  session_info <- capture.output(sessionInfo())
  log_content <- c(log_content, session_info, "")
  
  # # Add package information
  # log_content <- c(log_content, 
  #   "--- LOADED PACKAGES ---",
  #   capture.output(print(sessionInfo()$otherPkgs)),
  #   ""
  # )
  
  # Add configuration information
  log_content <- c(log_content,
    "--- TABLE CONFIGURATION ---",
    paste("Table ID:", meta$table_id %||% "Unknown"),
    paste("Title:", meta$title %||% "Unknown"),
    paste("Population From:", meta$population_from %||% "Unknown"),
    paste("Treatment Variable:", meta$treatment_var %||% "Unknown"),
    paste("Population Filter:", meta$population_filter %||% "None"),
    paste("Display Total Column:", meta$display_options$display_total_column %||% "Unknown"),
    ""
  )
  
  # Add metadata YAML content
  if (!is.null(meta)) {
    log_content <- c(log_content,
      "--- METADATA YAML CONTENT ---",
      "# Note: This shows the resolved metadata after global parameter substitution",
      capture.output(str(meta, max.level = 3)),
      ""
    )
  }
  
  # Add any initial messages
  if (length(log_messages) > 0) {
    log_content <- c(log_content,
      "--- INITIAL MESSAGES ---",
      log_messages,
      ""
    )
  }
  
  # Add separator for runtime messages
  log_content <- c(log_content,
    "--- RUNTIME LOG ---",
    paste(Sys.time(), "Log initialized")
  )
  
  # Write to file
  # if log_file exist overwrite it
  if (file.exists(log_file)) {
    file.remove(log_file)
  }

  writeLines(log_content, log_file)
  
  return(log_file)
}

#' Append message to log file
#'
#' @param log_file Path to log file
#' @param message Message to append
#' @param level Log level (INFO, WARNING, ERROR)
#' @export
append_log <- function(log_file, message, level = "INFO") {
  
  if (!file.exists(log_file)) {
    warning("Log file does not exist:", log_file)
    return(invisible())
  }
  
  timestamp <- format(Sys.time(), "%H:%M:%S")
  log_line <- paste(timestamp, paste0("[", level, "]"), message)
  
  # Append to file
  cat(log_line, "\n", file = log_file, append = TRUE)
  
  # Also print to console if verbose
  if (level %in% c("WARNING", "ERROR")) {
    message(log_line)
  }
}


#' Capture warnings and errors to log file
#'
#' @param expr Expression to evaluate
#' @param log_file Path to log file
#' @return Result of expression with warnings/errors logged
#' @export
with_message_logging <- function(expr, log_file) {
  
  # Storage for captured messages
  captured_warnings <- character()
  captured_errors <- character()
  
  result <- withCallingHandlers(
    tryCatch({
      eval(expr)
    }, error = function(e) {
      # Log error
      error_msg <- paste("ERROR:", conditionMessage(e))
      append_log(log_file, error_msg, "ERROR")
      captured_errors <<- c(captured_errors, error_msg)
      
      # Re-throw error
      stop(e)
    }),
    warning = function(w) {
      # Log warning
      warning_msg <- paste("WARNING:", conditionMessage(w))
      append_log(log_file, warning_msg, "WARNING")
      captured_warnings <<- c(captured_warnings, warning_msg)
      
      # Suppress the warning from console (it's now in log)
      invokeRestart("muffleWarning")
    }
  )
  
  # Store message counts for summary
  if (!exists(".message_counts", envir = .GlobalEnv)) {
    assign(".message_counts", list(warnings = 0, errors = 0), envir = .GlobalEnv)
  }
  
  counts <- get(".message_counts", envir = .GlobalEnv)
  counts$warnings <- counts$warnings + length(captured_warnings)
  counts$errors <- counts$errors + length(captured_errors)
  assign(".message_counts", counts, envir = .GlobalEnv)
  
  return(result)
}

#' Get message summary for finalize_log
#'
#' @return List with warning and error counts
#' @export
get_message_counts <- function() {
  if (exists(".message_counts", envir = .GlobalEnv)) {
    return(get(".message_counts", envir = .GlobalEnv))
  }
  return(list(warnings = 0, errors = 0))
}

#' Clear message counts
#'
#' @export
clear_message_counts <- function() {
  assign(".message_counts", list(warnings = 0, errors = 0), envir = .GlobalEnv)
}

#' Enhanced finalize_log with message summary
#'
#' @param log_file Path to log file
#' @param success Logical indicating if process was successful
#' @param output_files Named list of output files created
#' @param duration_seconds Processing duration in seconds
#' @export
finalize_log_with_messages <- function(log_file, success = TRUE, input_files = list(), output_files = list(), duration_seconds = NULL) {
  
  if (!file.exists(log_file)) {
    warning("Log file does not exist:", log_file)
    return(invisible())
  }
  
  # Get message counts
  message_counts <- get_message_counts()
  
  # Final summary
  summary_lines <- c(
    "",
    "--- EXECUTION SUMMARY ---",
    paste("Status:", if(success) "SUCCESS" else "FAILED"),
    paste("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste("Warnings captured:", message_counts$warnings),
    paste("Errors captured:", message_counts$errors)
  )
  
  if (!is.null(duration_seconds)) {
    summary_lines <- c(summary_lines, paste("Duration:", round(as.numeric(duration_seconds), 2), "seconds"))
  }

  # Add input files
  if (length(input_files) > 0) {
    summary_lines <- c(summary_lines, "", "--- INPUT FILES ---")
    for (name in names(input_files)) {
      file_path <- input_files[[name]]
      summary_lines <- c(summary_lines, paste(paste0(name, ":"), file_path))
    }
  }
  
  # Add output files
  if (length(output_files) > 0) {
    summary_lines <- c(summary_lines, "", "--- OUTPUT FILES ---")
    for (name in names(output_files)) {
      file_path <- output_files[[name]]
      file_exists <- file.exists(file_path)
      file_size <- if(file_exists) file.size(file_path) else 0
      summary_lines <- c(summary_lines, 
        paste(paste0(name, ":"), file_path, 
              if(file_exists) paste("(", file_size, "bytes)") else "(NOT FOUND)")
      )
    }
  }
  
  summary_lines <- c(summary_lines,
    "",
    "===============================================================================",
    paste("LOG COMPLETED:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "==============================================================================="
  )
  
  # Append to file
  cat(paste(summary_lines, collapse = "\n"), "\n", file = log_file, append = TRUE)
  
  # Clear message counts
  clear_message_counts()
}
