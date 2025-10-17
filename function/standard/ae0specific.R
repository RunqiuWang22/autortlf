# =============================================================================
# AE Specific Analysis Functions
# =============================================================================
# Program: ae0specific.R
# Purpose: Complete AE analysis pipeline - setup, analysis, and output
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================


#' Complete AE analysis pipeline
#'
#' @param meta Metadata configuration
#' @param global_config Global configuration
#' @param verbose Logical, whether to print progress messages
#' @param log_file Path to log file
#' @return List with analysis results and output paths
#' @export
ae0specific <- function(meta, global_config = NULL, verbose = TRUE, log_file = NULL) {
  

  # Step 3: Load and prepare data
  if (verbose) cat("Loading and preparing data...\n")
  
  # Load population dataset
  population_dataset <- load_analysis_dataset(meta$population_from, global_config, verbose)
  population_dataset <- apply_dataset_filter(population_dataset, meta$population_filter, verbose)
  
  # Load observation dataset
  observation_dataset <- load_analysis_dataset(meta$observation_from, global_config, verbose)
  observation_dataset <- apply_dataset_filter(observation_dataset, meta$observation_filter, verbose)
  
  # keep specific variables and USUBJID in population from that are not in observation from
  population_dataset <- population_dataset %>%
    select(all_of(c(meta$var_keep_in_population_from, "USUBJID", meta$treatment_var)))
  # check if there are existing variables in observation_from, if have, remove those columns from observation_dataset
  if (any(names(population_dataset) %in% names(observation_dataset))) {
    observation_dataset <- observation_dataset %>%
      select(-all_of(names(population_dataset)), "USUBJID")
  }
  # merge population_dataset with observation_dataset by USUBJID, only keep the subjects exist in population_from by USUBJID
  observation_dataset <-  observation_dataset%>%
    left_join(population_dataset, by = "USUBJID")
  
  
  # Step 4: Generate AE table
  if (verbose) cat("Generating AE analysis...\n")
  
  ae_table <- generate_ae_table(population_dataset, observation_dataset, meta, global_config, verbose)
  
  # Step 5: Generate RTF output
  if (verbose) cat("Generating RTF output...\n")
  
  output_info <- generate_ae_rtf(ae_table, meta, global_config, verbose)
  
  # Step 6: Save intermediate data if requested
  if (meta$display_options$create_output_dataset=="TRUE"|isTRUE(meta$display_options$create_output_dataset)) {
      output_info$output_data <- save_intermediate_data(ae_table, meta, global_config, verbose)
  }

  
  if (verbose) cat("=== AE Analysis Complete ===\n")
  
  if(is.null(ae_table)) {
    ae_table <- data.frame(Content = global_config$formatting$display_options$no_data_available_text)
  }
  return(list(
    ae_table = ae_table,
    output_files = output_info,
    metadata = meta,
    global_config = global_config
  ))
}


#' Generate AE summary table
#'
#' @param population_dataset Population data frame
#' @param observation_dataset Observation data frame
#' @param meta Metadata configuration
#' @param global_config Global configuration
#' @param verbose Logical for progress messages
#' @return Data frame with AE table
generate_ae_table <- function(population_dataset, observation_dataset, meta, global_config, verbose = TRUE) {
  
  treatment_var <- meta$treatment_var
  ae_params <- meta$ae_parameters
  display_options <- meta$display_options
  decimals <- meta$decimals

  # check if observation_dataset has values, if not, return null and stop the function
  if(nrow(observation_dataset) == 0) {
    cat("No values in observation_dataset, returning null\n")
    return(NULL)
  }
  
  # Get AE parameters
  ae_term_var <- ae_params$ae_term_var %||% "AEDECOD"
  if(!is.null(ae_params$group_by_var) && ae_params$group_by_var %in% names(observation_dataset)) {
    group_by_var <- ae_params$group_by_var
  } else {
    group_by_var <- NULL
  }
  min_threshold_pct <- ae_params$min_subjects_threshold %||% 5  # Now percentage
  sort_opts <- ae_params$sort_options %||% list()
  sort_order <- sort_opts$sort_order %||% "desc"  # Default to descending
  

  # title case the values in observation_dataset for ae_term_var and ae_group_by_var
  if (isTRUE(ae_params$to_proper_case)) { 
    observation_dataset[[ae_term_var]] <- str_to_title(observation_dataset[[ae_term_var]])
    if (!is.null(group_by_var) && group_by_var %in% names(observation_dataset)) {
      observation_dataset[[group_by_var]] <- str_to_title(observation_dataset[[group_by_var]])
    } 
  }

# Determine treatment levels
    if (!is.null(treatment_var) && treatment_var %in% names(population_dataset)) {
      # Determine treatment levels order
      treatment_codes <- NULL
      if (!is.null(meta$treatment_code) && meta$treatment_code %in% names(population_dataset)) {
        # Use treatment_code to sort treatment_var
        code_var <- meta$treatment_code
      code_vals <- population_dataset[[code_var]]
      treat_vals <- population_dataset[[treatment_var]]
      # Get unique pairs and order by code
      treat_df <- unique(data.frame(treat = treat_vals, code = code_vals, stringsAsFactors = FALSE))
      treat_df <- treat_df[order(treat_df$code), ]
      treatment_levels <- treat_df$treat
    } else if (!is.null(global_config$treatment_config$treatment_order)) {
      # Use global_config treatment order
      all_treats <- unique(population_dataset[[treatment_var]])
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


  # Calculate N subjects per treatment group from population dataset
  n_subjects_per_trt <- population_dataset %>%
    group_by(!!sym(treatment_var)) %>%
    summarise(n_subj = n_distinct(USUBJID), .groups = 'drop')
  # Add total if needed
  if (display_options$display_total_column=='TRUE'|isTRUE(display_options$display_total_column)){
    overall_n_subj <- population_dataset %>% 
      summarise(n_subj = n_distinct(USUBJID))
    total_row <- data.frame(n_subj = overall_n_subj$n_subj)
    names(total_row)[1] <- "n_subj"
    total_row[[treatment_var]] <- "Total"
    total_row <- total_row[, c(treatment_var, "n_subj")]
    n_subjects_per_trt <- bind_rows(n_subjects_per_trt, total_row)
  }

  n_subjects_per_trt <- n_subjects_per_trt %>%
      arrange(factor(!!sym(treatment_var), levels = treatment_levels))
  
  if (verbose) {
    cat("Sample sizes per treatment:\n")
    for (i in 1:nrow(n_subjects_per_trt)) {
      cat("  ", n_subjects_per_trt[[treatment_var]][i], ":", n_subjects_per_trt$n_subj[i], "\n")
    }
  }
  
  # Summarize AE data from observation dataset
  ae_summary_raw <- observation_dataset %>%
    filter(!!sym(ae_term_var) != "" & !is.na(!!sym(ae_term_var))) %>%
    group_by(!!sym(treatment_var), !!sym(ae_term_var)) %>%
    summarise(n_ae = n_distinct(USUBJID), .groups = 'drop') %>%
    ungroup()
  
   # Add overall counts if total column is enabled
  if (display_options$display_total_column=='TRUE'|isTRUE(display_options$display_total_column)) {
    overall_ae_summary <- observation_dataset %>%
      filter(!!sym(ae_term_var) != "" & !is.na(!!sym(ae_term_var))) %>%
      group_by(!!sym(ae_term_var)) %>%
      summarise(n_ae = n_distinct(USUBJID), .groups = 'drop')
    overall_ae_summary[[treatment_var]] <- "Total"
     
    ae_summary_raw <- bind_rows(ae_summary_raw, overall_ae_summary)

  }
  
  # Merge with N_subjects to calculate percentages
  ae_summary_processed <- ae_summary_raw %>%
    left_join(n_subjects_per_trt, by = treatment_var) %>%
    mutate(pct = round(n_ae / n_subj * 100, as.numeric(decimals$percent)))
  
  
  # Apply percentage threshold filter
  if (verbose) cat("Applying", min_threshold_pct, "% threshold filter...\n")
  
  if(min_threshold_pct >= 0){
    ae_summary_filtered <- ae_summary_processed %>%
      group_by(!!sym(ae_term_var)) %>%
      filter(any(pct >= min_threshold_pct)) %>%
      ungroup() 
    }else{
    ae_summary_filtered <- ae_summary_processed %>%
      group_by(!!sym(ae_term_var)) %>%
      filter(any(pct < abs(min_threshold_pct))) %>%
      ungroup()
    }
  
  # check if ae_summary_filtered has values, if not, return null and stop the function
  if(nrow(ae_summary_filtered) == 0) {
    cat("No values in ae_summary_filtered, returning null\n")
    return(NULL)
  }

  if (verbose) cat("AE terms after threshold filter:", length(unique(ae_summary_filtered[[ae_term_var]])), "\n")
  
  # Format display values
  ae_summary_display <- ae_summary_filtered %>%
    mutate(display_value = paste0(n_ae, " (", format(pct, nsmall = as.numeric(decimals$percent)), "%)"))

  # Pivot to wide format for display
  ae_display_wide <- ae_summary_display %>%
    select(!!sym(ae_term_var), !!sym(treatment_var), display_value) %>%
    pivot_wider(
      names_from = !!sym(treatment_var), 
      values_from = display_value, 
      values_fill = paste0("0 ( 0.",paste0(rep(0, as.numeric(decimals$percent)), collapse = ""), "%)")
    )
  
  # check the ae_display_wide column has all the treatment_levels, if not, then add the missed treatment_levels to the ae_display_wide column and assign 0 ( 0.0%) to the missed treatment_levels
  missed_treatment_levels <- setdiff(treatment_levels, names(ae_display_wide))
  if (length(missed_treatment_levels) > 0) {
    # For each missing treatment level, add a column with the default value
    for (missed_col in missed_treatment_levels) {
      ae_display_wide[[missed_col]] <- paste0("0 ( 0.", paste0(rep(0, as.numeric(decimals$percent)), collapse = ""), "%)")
    }
  }
 
  
  # Add grouping variable back if needed
  if (!is.null(group_by_var)) {
    
  # Add grouping variable if specified
    group_mapping <- observation_dataset %>%
      select(!!sym(ae_term_var), !!sym(group_by_var)) %>%
      distinct()
    
    ae_display_wide <- ae_display_wide %>%
      left_join(group_mapping, by = ae_term_var)

    # by group count
    ae_summary_group_raw <- observation_dataset %>%
      filter(!!sym(ae_term_var) != "" & !is.na(!!sym(ae_term_var))&!!sym(ae_term_var) %in% ae_summary_filtered[[ae_term_var]]) %>%
      group_by(!!sym(treatment_var), !!sym(group_by_var)) %>%
      summarise(n_ae = n_distinct(USUBJID), .groups = 'drop') %>%
      ungroup()
    
    overall_ae_summary_group <- observation_dataset %>%
      filter(!!sym(ae_term_var) != "" & !is.na(!!sym(ae_term_var))&!!sym(ae_term_var) %in% ae_summary_filtered[[ae_term_var]]) %>%
      group_by(!!sym(group_by_var)) %>%
      summarise(n_ae = n_distinct(USUBJID), .groups = 'drop')
    overall_ae_summary_group[[treatment_var]] <- "Total"
    
    ae_summary_group_raw <- bind_rows(ae_summary_group_raw, overall_ae_summary_group)

    # process ae_summary_group_raw dataset
    ae_summary_group_processed <- ae_summary_group_raw %>%
      left_join(n_subjects_per_trt, by = treatment_var) %>%
      mutate(pct = round(n_ae / n_subj * 100, as.numeric(decimals$percent)))

    # keep only the ae group that in ae_display_wide in ae_summary_group_processed dataset
    ae_summary_group_filtered <- ae_summary_group_processed %>%
      filter(!!sym(group_by_var) %in% ae_display_wide[[group_by_var]])
    
    ae_group_display <- ae_summary_group_filtered %>%
      mutate(display_value = paste0(n_ae, " (", format(pct, nsmall = as.numeric(decimals$percent)), "%)"))

    ae_group_display_wide <- ae_group_display %>%
      select(!!sym(group_by_var), !!sym(treatment_var), display_value) %>%
      pivot_wider(
        names_from = !!sym(treatment_var), 
        values_from = display_value, 
        values_fill = paste0("0 ( 0.",paste0(rep(0, as.numeric(decimals$percent)), collapse = ""), "%)")
      )

      # check the ae_group_display_wide column has all the treatment_levels, if not, then add the missed treatment_levels to the ae_group_display_wide column and assign 0 ( 0.0%) to the missed treatment_levels
    missed_treatment_levels <- setdiff(treatment_levels, names(ae_group_display_wide))
    if (length(missed_treatment_levels) > 0) {
      # For each missing treatment level, add a column with the default value
      for (missed_col in missed_treatment_levels) {
        ae_group_display_wide[[missed_col]] <- paste0("0 ( 0.", paste0(rep(0, as.numeric(decimals$percent)), collapse = ""), "%)")
      }
    }
  }

  # Apply enhanced grouping and sorting
  final_table <- apply_enhanced_grouping_and_sorting(
    ae_display = ae_display_wide, 
    ae_group_display = ae_group_display_wide,
    ae_term_var = ae_term_var, 
    group_by_var = group_by_var, 
    group_display_name = ae_params$group_display_name %||% "Group",
    display_headers = ae_params$display_grouping_headers %||% TRUE,
    sort_by = sort_opts$sort_by %||% "frequency",
    sort_column = sort_opts$sort_column %||% "Total",
    sort_order = sort_order,
    group_sort = sort_opts$group_sort %||% "frequency",
    within_group_sort = sort_opts$within_group_sort %||% TRUE,
    treatment_levels = treatment_levels,
    dataset = observation_dataset
  )
  
  # add total row as the first row showing N=xx for each arm (and Total if present)
  total_row <- data.frame(
    Variable = "\\b Participants in population",
    as.list(n_subjects_per_trt$n_subj%>%as.character()),
    group_by_var = 'Participants',
    stringsAsFactors = FALSE
  )
  colnames(total_row) <- if(!is.null(group_by_var)) colnames(final_table) else c(colnames(final_table), 'group_by_var')

  # participants with one or more adverse events
  participants_with_ae <- observation_dataset %>%
    filter(!!sym(ae_term_var) != "" & !is.na(!!sym(ae_term_var))) %>%
    group_by(!!sym(treatment_var)) %>%
    summarise(n_subj = n_distinct(USUBJID), .groups = 'drop')
   # Add total if needed
  if (display_options$display_total_column=='TRUE'|isTRUE(display_options$display_total_column)){
    overall_n_ae_subj <- observation_dataset %>%
      filter(!!sym(ae_term_var) != "" & !is.na(!!sym(ae_term_var))) %>%
      summarise(n_subj = n_distinct(USUBJID))
    total_ae_row <- data.frame(n_subj = overall_n_ae_subj$n_subj)
    names(total_ae_row)[1] <- "n_subj"
    total_ae_row[[treatment_var]] <- "Total"
    total_ae_row <- total_ae_row[, c(treatment_var, "n_subj")]
    participants_with_ae <- bind_rows(participants_with_ae, total_ae_row)
  }
  # check the values in  !!(sym(treatment_var)) column of participants_with_ae,  if has not have all the treatment_levels, then add the missed levels to !!(sym(treatment_var)) column and assign 0 to n_subj column
  missed_treatment_levels <- setdiff(treatment_levels, participants_with_ae[[treatment_var]])
  if (length(missed_treatment_levels) > 0) {
    missed_df <- data.frame(
      n_subj = 0,
      stringsAsFactors = FALSE  
    )
    missed_df[[treatment_var]] <- missed_treatment_levels
    participants_with_ae <- bind_rows(participants_with_ae, missed_df)
  }
    # order the participants_with_ae by treatment_var with order treatment_levels
  participants_with_ae <- participants_with_ae %>%
    arrange(factor(!!sym(treatment_var), levels = treatment_levels))

  participants_with_ae_row <- data.frame(
    Variable = "\\b with one or more adverse events",
    # number of participants and percentage show as x (xx.x%
    as.list(paste0(participants_with_ae$n_subj, " (", format(round(participants_with_ae$n_subj / n_subjects_per_trt$n_subj * 100, as.numeric(decimals$percent)), nsmall = as.numeric(decimals$percent)), "%)")),
    group_by_var = 'Participants',
    stringsAsFactors = FALSE
  )
  colnames(participants_with_ae_row) <- if(!is.null(group_by_var)) colnames(final_table) else c(colnames(final_table), 'group_by_var')

 # participants with no adverse events
 participants_with_no_ae <- n_subjects_per_trt$n_subj - participants_with_ae$n_subj
 participants_with_no_ae_row <- data.frame(
    Variable = "\\b   with no adverse events",
    # number of participants and percentage show as x (xx.x%
    as.list(paste0(participants_with_no_ae, " (", format(round(participants_with_no_ae / n_subjects_per_trt$n_subj * 100, as.numeric(decimals$percent)), nsmall = as.numeric(decimals$percent)), "%)")),
    group_by_var = 'Participants',
    stringsAsFactors = FALSE
  )
  colnames(participants_with_no_ae_row) <- if(!is.null(group_by_var)) colnames(final_table) else c(colnames(final_table), 'group_by_var')
 
 # a empty row between header rows and final table
 empty_row <- data.frame(
    Variable = "",
    as.list(rep("", length(treatment_levels))),
    group_by_var = 'Participants',
    stringsAsFactors = FALSE
  )
  colnames(empty_row) <- if(!is.null(group_by_var)) colnames(final_table) else c(colnames(final_table), 'group_by_var')

 #combine header rows and final table
 if (!is.null(group_by_var) && group_by_var %in% names(final_table)) {
  final_table <- bind_rows(total_row, participants_with_ae_row, participants_with_no_ae_row, empty_row, final_table)
  final_table <- final_table %>% select(all_of(group_by_var), Variable, all_of(treatment_levels))
  # bold the grouping row
  final_table <- final_table %>% mutate(bold_flag = ifelse(!!sym(group_by_var) == Variable, 'Y', 'N'))
  for (i in which(final_table$bold_flag == 'Y')) {
    final_table[i, "Variable"] <- paste0("\\b ", final_table[i, "Variable"])
    final_table[i, treatment_levels] <- paste0("\\b ", final_table[i, treatment_levels])
  }
  final_table <- final_table %>% select(-bold_flag)
  
} else {
  # total_row drop the last column
  final_header <- bind_rows(total_row, participants_with_ae_row, participants_with_no_ae_row, empty_row)%>%select(-'group_by_var')
  final_table <- bind_rows(final_header, final_table)
 }# total_row drop the last column

 
  return(final_table)
}

#' Apply enhanced grouping and sorting to AE display data
#'
#' @param ae_display data.frame with AE display data
#' @param ae_term_var string, AE term variable name
#' @param group_by_var string or NULL, grouping variable
#' @param group_display_name string, display name for grouping
#' @param display_headers logical, whether to show group headers
#' @param sort_by string, sort method
#' @param sort_column string, column to sort by
#' @param sort_order string, "desc" or "asc"
#' @param group_sort string, how to sort groups
#' @param within_group_sort logical, sort within groups
#' @param treatment_levels vector, treatment column names
#' @param dataset data.frame, original dataset for group mapping
#' @return data.frame with grouped and sorted display table
apply_enhanced_grouping_and_sorting <- function(ae_display, ae_group_display, ae_term_var, group_by_var, 
                                               group_display_name, display_headers, 
                                               sort_by, sort_column, sort_order, 
                                               group_sort, within_group_sort, 
                                               treatment_levels, dataset) {
  
  # Step 1: Apply sorting to AE terms
  # Check if grouping is specified
  if (!is.null(group_by_var) && group_by_var != "" && group_by_var %in% names(ae_display)) {
    # Grouping is specified
    # Determine group order
    if (group_sort == "frequency" && !is.null(sort_column) && sort_column %in% names(ae_group_display)) {
      # Sort groups by frequency (percent) in ae_group_display
      ae_group_display <- ae_group_display %>% mutate( sort_value = as.numeric(gsub(" \\(.*\\)", "", .data[[sort_column]])))

      if (sort_order == "desc") {
        ae_group_display <- ae_group_display %>% arrange(desc(sort_value))
      } else {
        ae_group_display <- ae_group_display %>% arrange(sort_value)
      }
    } else{
        ae_group_display <- ae_group_display %>% arrange(!!sym(group_by_var))
    }
    group_order <- ae_group_display[[group_by_var]]

    # Sort within each group
    ae_display <- ae_display %>%
      mutate(
        group_factor = factor(.data[[group_by_var]], levels = group_order)
      ) %>%
      arrange(group_factor)

    if (!is.null(within_group_sort) && within_group_sort != "") {
      # Sort within each group by frequency or alphabetical
      if (within_group_sort == "frequency" && !is.null(sort_column) && sort_column %in% names(ae_display)) {
        ae_display <- ae_display %>%
          group_by(group_factor) %>%
          mutate(
            sort_value = as.numeric(gsub(" \\(.*\\)", "", .data[[sort_column]]))
          ) %>%
          {
            if (sort_order == "desc") {
              arrange(., desc(sort_value), .by_group = TRUE)
            } else {
              arrange(., sort_value, .by_group = TRUE)
            }
          } %>%
          ungroup() %>%
          select(-sort_value, -group_factor)
      } else {
        # Alphabetical within group
        ae_display <- ae_display %>%
          group_by(group_factor) %>%
          { 
            # if (sort_order == "desc") arrange(., desc(!!sym(ae_term_var)), .by_group = TRUE)
            # else arrange(., !!sym(ae_term_var), .by_group = TRUE)
            arrange(., !!sym(ae_term_var), .by_group = TRUE)
          } %>%
          ungroup() %>%
          select(-group_factor)
      }
    } else {
      ae_display <- ae_display %>% select(-group_factor)
    }
  } else {
    # No grouping, sort by AE term
    if (sort_by == "frequency" && !is.null(sort_column) && sort_column %in% names(ae_display)) {
      ae_display <- ae_display %>%
        mutate(
          sort_value = as.numeric(gsub(" \\(.*\\)", "", .data[[sort_column]]))
        )
      if (sort_order == "desc") {
        ae_display <- ae_display %>% arrange(desc(sort_value))
      } else {
        ae_display <- ae_display %>% arrange(sort_value)
      }
      ae_display <- ae_display %>% select(-sort_value)
    } else {
      # Alphabetical
      if (sort_order == "desc") {
        ae_display <- ae_display %>% arrange(desc(!!sym(ae_term_var)))
      } else {
        ae_display <- ae_display %>% arrange(!!sym(ae_term_var))
      }
    }
  }


  # Step 2: Apply grouping if specified
  if (!is.null(group_by_var) && group_by_var != "" && 
      group_by_var %in% names(ae_display) && display_headers) {
    
    # Create grouped display with headers
    display_rows <- list()
    current_group <- ""

    group_mapping <- dataset %>%
      select(!!sym(ae_term_var), !!sym(group_by_var)) %>%
      distinct()
    
    for (i in 1:nrow(ae_display)) {
      group_value <- ae_display[[group_by_var]][i]
      ae_term <- ae_display[[ae_term_var]][i]
      
      # Add group header if different from previous
      if (group_value != current_group) {
        group_row <- data.frame(
          Variable =  group_value,
          stringsAsFactors = FALSE
        )
        # # Add corresponding values from ae_group_display, where group_by_var is the same as group_value, to treatment columns
        for (trt in treatment_levels) {
          group_row[[trt]] <- ae_group_display[[trt]][ae_group_display[[group_by_var]] == group_value]
        }

        display_rows <- append(display_rows, list(group_row), after = length(display_rows))
        current_group <- group_value
      }
      
      # Add AE term row with indentation
      ae_row <- data.frame(
        Variable = paste0("  ", ae_term),
        stringsAsFactors = FALSE
      )
      # Add treatment data
      for (trt in treatment_levels) {
        ae_row[[trt]] <- ae_display[[trt]][i]
      }
      display_rows <- append(display_rows, list(ae_row), after = length(display_rows))
    }
    
    final_table <- do.call(rbind, display_rows)

    final_table <- final_table %>%left_join(group_mapping%>%rename(Variable = !!sym(ae_term_var))%>%mutate(Variable = paste0("  ", Variable)), by = "Variable")
    
    # if group_by_var is NA, then set it to Variable
    final_table <- final_table %>% mutate(tmp = ifelse(is.na(!!sym(group_by_var)), Variable, !!sym(group_by_var)))
    final_table[[group_by_var]] <- final_table[["tmp"]]
    final_table <- final_table %>% select(-tmp)
 
   
  } else {
    # No grouping - simple format
    final_table <- ae_display %>%
      rename(Variable = !!sym(ae_term_var)) %>%
      select(Variable, all_of(treatment_levels))
  }

  
  return(final_table)
}

#' Generate RTF output for AE table
#'
#' @param ae_table AE summary table
#' @param meta Metadata configuration
#' @param global_config Global configuration
#' @param verbose Logical for progress messages
#' @return List with output file information
generate_ae_rtf <- function(ae_table, meta, global_config, verbose = TRUE) {
  

  # Step 1: Determine output path using project name
  project_name <- global_config$study_info$project
  group_by_var <- meta$ae_parameters$group_by_var

  display_only_total <- meta$display_options$display_only_total_column
  if (display_only_total == "TRUE" | isTRUE(display_only_total)) {
    ae_table <- ae_table[, c(group_by_var, "Variable", "Total")]
  }

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
  
  # Step 2: Get RTF settings
  rtf_settings <- global_config$formatting$rtf_settings
  total_width <- rtf_settings$page_width %||% 8.5
  
  
  # Step 3: prepare the title and subtitle
  title_string <- paste0(meta$title %||% "AE Summary", ' ',meta$append_title %||% "")
  subtitle_string <- paste0(meta$subtitle1 %||% "", " \n",meta$subtitle2 %||% "")

  # if subtitle_string has {}, then replace it with the value in {}
  pct_threshold <- meta$ae_parameters$min_subjects_threshold %||% 0
  if(pct_threshold >= 0){
    subtitle_string <- str_split(subtitle_string, "\\{ae_parameters.min_subjects_threshold\\}")%>%unlist()
    if(pct_threshold == 0){
      subtitle_string <- paste0(subtitle_string[1], paste0('> ', pct_threshold, "%"), subtitle_string[2])
    }else{
      subtitle_string <- paste0(subtitle_string[1], paste0('\\geq ', pct_threshold, "%"), subtitle_string[2])
    }
  }else if(pct_threshold < 0){
    subtitle_string <- str_replace_all(subtitle_string, "\\{ae_parameters.min_subjects_threshold\\}", paste0("< ", abs(pct_threshold), "%"))
  }

  # step 4: Generate RTF, if ae_table is not null, output the table, if null, output no data table.
  if(!is.null(ae_table)) {

      # Determine table structure
    if (!is.null(global_config$treatment_config$treatment_labels)) {
      label_overrides <- global_config$treatment_config$treatment_labels  #replace with treatment labels want to display
      # if display_total_column is TRUE, then add "Total" to the label_overrides
      if (meta$display_options$display_total_column == "TRUE") {
        if (!is.null(group_by_var) && group_by_var %in% names(ae_table)) {
          names(ae_table)[-c(1,2)] <- c(unlist(lapply(names(ae_table)[-c(1,2)], function(x) label_overrides[[x]])), 'Total')
        } else {
          names(ae_table)[-c(1)] <- c(unlist(lapply(names(ae_table)[-c(1)], function(x) label_overrides[[x]])), 'Total')
        }
      }else{
        if (!is.null(group_by_var) && group_by_var %in% names(ae_table)) {
          names(ae_table)[-c(1,2)] <- c(unlist(lapply(names(ae_table)[-c(1,2)], function(x) label_overrides[[x]])))
        } else {
          names(ae_table)[-c(1)] <- c(unlist(lapply(names(ae_table)[-c(1)], function(x) label_overrides[[x]])))
        }
      }
    } 

    if (!is.null(group_by_var) && group_by_var %in% names(ae_table)) {
      treatment_cols <- names(ae_table)[-c(1,2)]
    } else {
      treatment_cols <- names(ae_table)[-c(1)]
    }
    n_treatments <- length(treatment_cols)
    
    # Calculate column widths
    variable_width <- if (n_treatments <= 3) 2.5 else 3
    remaining_width <- total_width - variable_width

    if (!is.null(group_by_var) && group_by_var %in% names(ae_table)) {
      # by group term display
      rtf_obj <- ae_table %>%
      rtf_page(orientation = rtf_settings$orientation %||% "portrait",
              height = rtf_settings$page_height %||% 11.0,
              width = total_width, 
              margin = c(rtf_settings$margin_left %||% 1.0, rtf_settings$margin_right %||% 1.0, rtf_settings$margin_top %||% 1.0, rtf_settings$margin_bottom %||% 1.0, rtf_settings$margin_header %||% 0.5, rtf_settings$margin_footer %||% 0.5)) %>%
      rtf_title(title_string,
                subtitle_string) %>%
      rtf_colheader(
        paste(" |", paste(treatment_cols, collapse = " | "), "|"),
        col_rel_width = c(variable_width, rep(remaining_width / n_treatments, n_treatments)),
        border_bottom = c("", rep("single", n_treatments)),
        text_font_size = rtf_settings$font_size %||% 10
      ) %>%
      rtf_colheader(
        paste0( rep('| n (%)', n_treatments), collapse = " "),
        col_rel_width = c(variable_width, rep(remaining_width / n_treatments, n_treatments)),
        border_top = c("",  rep("single", n_treatments)),
        border_bottom = "single",
        text_font_size = rtf_settings$font_size %||% 10
      ) %>%
      rtf_body(
        page_by = group_by_var,
        pageby_row = 'first_row',
        col_rel_width = c(variable_width, variable_width, rep(remaining_width / n_treatments, n_treatments)),
        border_first = "",
        text_justification = c("l", "l", rep("c", n_treatments)),
        text_format = c("b", "", rep("", n_treatments)),
        border_left = c("single", "single", rep("single", n_treatments)),
        border_top = c("single", "", rep("", n_treatments)),
        border_bottom = c("single", "", rep("", n_treatments)),
        text_font_size = rtf_settings$font_size %||% 10
      )
    } else {
      # no group term display
      rtf_obj <- ae_table %>%
      rtf_page(orientation = rtf_settings$orientation %||% "portrait",
              height = rtf_settings$page_height %||% 11.0,
              width = total_width, 
              margin = c(rtf_settings$margin_left %||% 1.0, rtf_settings$margin_right %||% 1.0, rtf_settings$margin_top %||% 1.0, rtf_settings$margin_bottom %||% 1.0, rtf_settings$margin_header %||% 0.5, rtf_settings$margin_footer %||% 0.5)) %>%
      rtf_title(title_string,
                subtitle_string) %>%
      rtf_colheader(
        paste(" |", paste(treatment_cols, collapse = " | "), "|"),
        col_rel_width = c(variable_width, rep(remaining_width / n_treatments, n_treatments)),
        border_bottom = c("", rep("single", n_treatments)),
        text_font_size = rtf_settings$font_size %||% 10
      ) %>%
      rtf_colheader(
        paste0( rep('| n (%)', n_treatments), collapse = " "),
        col_rel_width = c(variable_width, rep(remaining_width / n_treatments, n_treatments)),
        border_top = c("",  rep("single", n_treatments)),
        border_bottom = "single",
        text_font_size = rtf_settings$font_size %||% 10
      ) %>%
      rtf_body( 
        col_rel_width = c(variable_width,  rep(remaining_width / n_treatments, n_treatments)),
        text_justification = c("l", rep("c", n_treatments)),
        text_format = c( "", rep("", n_treatments)),
        border_left = c("single" , rep("single", n_treatments)),
        border_top = c("", rep("", n_treatments)),
        border_bottom = c("", rep("", n_treatments)),
        text_font_size = rtf_settings$font_size %||% 10
      )
    }
    # Add footnotes
    if (!is.null(meta$footnotes)) {
      footnote_list <- NULL
      for (footnote in meta$footnotes) {
        footnote_list <- c(footnote_list, footnote)
      }
      rtf_obj <- rtf_obj %>% rtf_footnote(paste(footnote_list, collapse = "\n"))
    }

  }else {

    # if table is null, then output no data table
    rtf_obj <- data.frame(Content = global_config$formatting$display_options$no_data_available_text) %>%
      rtf_page(orientation = rtf_settings$orientation %||% "portrait",
              height = rtf_settings$page_height %||% 11.0,
              width = total_width, 
              margin = c(rtf_settings$margin_left %||% 1.0, rtf_settings$margin_right %||% 1.0, rtf_settings$margin_top %||% 1.0, rtf_settings$margin_bottom %||% 1.0, rtf_settings$margin_header %||% 0.5, rtf_settings$margin_footer %||% 0.5)
              ) %>%
      rtf_title(title_string,
                subtitle_string)%>%
      rtf_body(
        text_justification = "l",
         as_colheader = FALSE,
        text_format = "",
        border_left = "single",
        border_top = "",
        border_bottom = "",
        text_font_size = rtf_settings$font_size %||% 10
      )
  }
  
  # Add data source
  if (!is.null(meta$data_source)) {
    rtf_obj <- rtf_obj %>% rtf_source(meta$data_source_text)
  }

  # step 5: Encode and write
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

