# =============================================================================
# Baseline Characteristics Analysis Functions
# =============================================================================
# Program: baseline0char.R
# Purpose: Complete baseline analysis pipeline - setup, analysis, and output
# Version: 2.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================


#' Complete baseline analysis pipeline
#'
#' @param metadata_file Path to metadata YAML file
#' @param global_config_file Path to global configuration file
#' @param verbose Logical, whether to print progress messages
#' @return List with analysis results and output paths
#' @export
baseline0char <- function(meta, global_config= NULL, verbose = TRUE, log_file = NULL) {
  
 
  # Step 3: Load and prepare data
  if (verbose) cat("Loading and preparing data...\n")
  
  dataset <- load_analysis_dataset(meta$population_from, global_config, verbose)
  dataset <- apply_dataset_filter(dataset, meta$population_filter, verbose)
  
  # Step 4: Generate baseline table
  if (verbose) cat("Generating baseline analysis...\n")
  
  baseline_table <- generate_baseline_table(dataset, meta, global_config, verbose)
  
  # Step 5: Generate RTF output
  if (verbose) cat("Generating RTF output...\n")
  
  output_info <- generate_baseline_rtf(baseline_table, meta, global_config, verbose)
  
  # Step 6: Save intermediate data if requested
  if (meta$display_options$create_output_dataset=="TRUE"|isTRUE(meta$display_options$create_output_dataset)) {
      output_info$output_data <- save_intermediate_data(baseline_table, meta, global_config, verbose)
  }

  
  if (verbose) cat("=== Baseline Analysis Complete ===\n")
  
  return(list(
    baseline_table = baseline_table,
    output_files = output_info,
    metadata = meta,
    global_config = global_config
  ))
}


#' Generate baseline characteristics table
#'
#' @param dataset Input data frame
#' @param meta Metadata configuration
#' @param global_config Global configuration
#' @param verbose Logical for progress messages
#' @return Data frame with baseline table
generate_baseline_table <- function(dataset, meta, global_config, verbose = TRUE) {
  
  treatment_var <- meta$treatment_var
  display_options <- meta$display_options
  decimals <- meta$decimals
  
  # Determine treatment levels
  if (!is.null(treatment_var) && treatment_var %in% names(dataset)) {
    # Determine treatment levels order
    treatment_codes <- NULL
    if (!is.null(meta$treatment_code) && meta$treatment_code %in% names(dataset)) {
      # Use treatment_code to sort treatment_var
      code_var <- meta$treatment_code
      code_vals <- dataset[[code_var]]
      treat_vals <- dataset[[treatment_var]]
      # Get unique pairs and order by code
      treat_df <- unique(data.frame(treat = treat_vals, code = code_vals, stringsAsFactors = FALSE))
      treat_df <- treat_df[order(treat_df$code), ]
      treatment_levels <- treat_df$treat
    } else if (!is.null(global_config$treatment_config$treatment_order)) {
      # Use global_config treatment order
      all_treats <- unique(dataset[[treatment_var]])
      treatment_levels <- intersect(global_config$treatment_config$treatment_order, all_treats)
      # Add any not in order at the end
      treatment_levels <- c(treatment_levels, setdiff(all_treats, treatment_levels))
    } else {
      # Default: sort alphabetically
      treatment_levels <- sort(unique(dataset[[treatment_var]]))
    }
    
    col_structure <- "treatment"
    if (display_options$display_total_column=='TRUE'|isTRUE(display_options$display_total_column)) {
      treatment_levels <- c(treatment_levels, "Total")
      col_structure <- "treatment_with_total"
    }

  } else {
    treatment_levels <- "Overall"
    col_structure <- "overall"
  }
  
  if (verbose) cat("Treatment levels:", paste(treatment_levels, collapse = ", "), "\n")
  
  # Process each variable
  all_results <- list()
  
  for (var_info in meta$variables) {
    if (verbose) cat("Processing variable:", var_info$name, "\n")
    
    if (var_info$type == "continuous") {
      var_results <- process_continuous_variable(dataset, var_info, treatment_var, col_structure,
                                               treatment_levels, display_options, decimals)
    } else if (var_info$type == "categorical") {
      var_results <- process_categorical_variable(dataset, var_info, treatment_var, col_structure,
                                                treatment_levels, display_options, decimals)
    } else {
      warning(paste("Unknown variable type:", var_info$type))
      next
    }
    
    all_results <- append(all_results, list(var_results), after = length(all_results))
  }
  
  # Combine all results
  final_table <- do.call(rbind, all_results)
  rownames(final_table) <- NULL

  
  # Add a "Total" row as the first row, showing N=xx for each arm (and Total if present)
  total_n <- sapply(treatment_levels, function(trt) {
    if (col_structure == "treatment" || col_structure == "treatment_with_total") {
      if (trt == "Total") {
        nrow(dataset)
      } else {
        sum(dataset[[treatment_var]] == trt, na.rm = TRUE)
      }
    } else {
      nrow(dataset)
    }
  })



  # If there are multiple treatment columns, set up columns accordingly
  if (length(treatment_levels) > 1) {
    # The first two column are "group" and "Variable", the rest are treatment columns
    total_row <- data.frame(
      group = "",
      Variable = "",
      as.list(paste0("N = ", total_n)),
      stringsAsFactors = FALSE
    )
    colnames(total_row) <- colnames(final_table)
  } else {
    # Only one column (overall)
    total_row <- data.frame(
      group = "",
      Variable = "",
      Overall = paste0("N=", total_n[1])
    )
    colnames(total_row) <- colnames(final_table)
  }
  # Prepend the total_row to the final_table
  final_table <- rbind(total_row, final_table)

  # Based on display_options, remove rows where Variable is not in the list
  if (!display_options$display_n) {
    final_table <- final_table %>% filter(Variable != "  n")
  }
  if (!display_options$display_mean) {
    final_table <- final_table %>% filter(Variable != "Mean (SD)")
  }
  if (!display_options$display_median) {
    final_table <- final_table %>% filter(Variable != "Median")
  }
  if (!display_options$display_range) {
    final_table <- final_table %>% filter(Variable != "Range")
  }
  if (!display_options$display_IQR) {
    final_table <- final_table %>% filter(Variable != "Q1, Q3")
  }
  
  
  return(final_table)
}



#' Generate RTF output for baseline table
#'
#' @param baseline_table Baseline summary table
#' @param meta Metadata configuration
#' @param global_config Global configuration
#' @param verbose Logical for progress messages
#' @return List with output file information
generate_baseline_rtf <- function(baseline_table, meta, global_config, verbose = TRUE) {
  
  display_only_total <- meta$display_options$display_only_total_column
  if (display_only_total == "TRUE" | isTRUE(display_only_total)) {
    baseline_table <- baseline_table[, c("group", "Variable", "Total")]
  }
  # Determine output path using project name
  project_name <- global_config$study_info$project
  #based on meta$type, if it is "Table" or 'List', then output_dir is global_config$paths$outtable_path, if it is "Graph", then output_dir is global_config$paths$outgraph_path, else type report error
  if (meta$type == "Table" || meta$type == "List") {
    output_dir <- file.path(global_config$paths$outtable_path, project_name)
  } else if (meta$type == "Graph") {
    output_dir <- file.path(global_config$paths$outgraph_path, project_name)
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  output_file <- file.path(output_dir, paste0(meta$rename_output, ".rtf"))
  
  if (verbose) cat("Writing RTF to:", output_file, "\n")
  
  # Get RTF settings
  rtf_settings <- global_config$formatting$rtf_settings
  
  # Determine table structure
  if (!is.null(global_config$treatment_config$treatment_labels)) {
    label_overrides <- global_config$treatment_config$treatment_labels  #replace with treatment labels want to display
    # if display_total_column is TRUE, then add "Total" to the label_overrides
    if (meta$display_options$display_total_column == "TRUE") {
      names(baseline_table)[-c(1,2)] <- c(unlist(lapply(names(baseline_table)[-c(1,2)], function(x) label_overrides[[x]])), 'Total')
    }else{
      names(baseline_table)[-c(1,2)] <- c(unlist(lapply(names(baseline_table)[-c(1,2)], function(x) label_overrides[[x]])))
    }
  } 
  treatment_cols <- names(baseline_table)[-c(1,2)]
  n_treatments <- length(treatment_cols)
  
  # Calculate column widths
  total_width <-  rtf_settings$page_width %||% 8.5
  variable_width <- if (n_treatments <= 3) 3.0 else 3
  remaining_width <- total_width - variable_width
  
  # Generate RTF
  rtf_obj <- baseline_table[-1,] %>%
    rtf_page(orientation = rtf_settings$orientation %||% "portrait",
             height = rtf_settings$page_height %||% 11.0,
             width = total_width, 
             margin = c(rtf_settings$margin_left %||% 1.0, rtf_settings$margin_right %||% 1.0, rtf_settings$margin_top %||% 1.0, rtf_settings$margin_bottom %||% 1.0, rtf_settings$margin_header %||% 0.5, rtf_settings$margin_footer %||% 0.5)) %>%
    rtf_title(meta$title %||% "Baseline Characteristics",
              meta$subtitle %||% "") %>%
    rtf_colheader(
      paste(" |", paste(treatment_cols, collapse = " | "), "|"),
      col_rel_width = c(variable_width, rep(remaining_width / n_treatments, n_treatments)),
      border_top = c("", rep("single", n_treatments)),
      border_left = c("single", rep("single", n_treatments))
    ) %>%
     rtf_colheader(
      paste(" |", paste(baseline_table[1, -c(1,2)], collapse = " | "), "|"),
      col_rel_width = c(variable_width, rep(remaining_width / n_treatments, n_treatments)),
      border_top = c("", rep("single", n_treatments)),
      border_left = c("single", rep("single", n_treatments))
    ) %>%
    rtf_body(
      page_by = "group",
      col_rel_width = c(variable_width, variable_width, rep(remaining_width / n_treatments, n_treatments)),
      text_justification = c("l", "l", rep("c", n_treatments)),
      text_format = c("b", "", rep("", n_treatments)),
      border_left = c("single", "single", rep("single", n_treatments)),
      border_top = c("single", "", rep("", n_treatments)),
      border_bottom = c("single", "", rep("", n_treatments)),,
      text_font_size = rtf_settings$font_size %||% 10
    )
  
  # Add footnotes
  if (!is.null(meta$footnotes)) {
    footnote_list <- NULL
    for (footnote in meta$footnotes) {
     footnote_list <- c(footnote_list, footnote)
    }
     rtf_obj <- rtf_obj %>% rtf_footnote(paste(footnote_list, collapse = "\n"))
  }

  # Add data source
  if (!is.null(meta$data_source)) {
    rtf_obj <- rtf_obj %>% rtf_source(meta$data_source_text)
  }
  
  # Encode and write
  rtf_obj %>%
    rtf_encode() %>%
    write_rtf(file = output_file)

    # save the rtf to other formats. Only support unix system for now.
  if( .Platform$OS.type == "unix" && global_config$output_format$output_tlf_format !='rft'){
    cat("Saving RTF to other formats:", global_config$output_format$output_tlf_format, "\n")
    if(global_config$output_format$output_tlf_format %in% c('pdf', 'docx', 'html')){
      r2rtf:::rtf_convert_format(input=output_file, output_file=file.path(output_dir, paste0(meta$rename_output, ".", global_config$output_format$output_tlf_format)), format=global_config$output_format$output_tlf_format)
    }else{
      cat("Unsupported output format: ", global_config$output_format$output_tlf_format)
    }
  }
  
  return(list(
    rtf_file = output_file
  ))
}


