# =============================================================================
# Global Statistical Functions
# =============================================================================
# Program: statistical_functions.R
# Purpose: Common statistical functions for TLF generation
# Version: 2.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================

#' Process continuous variable
#'
#' @param dataset Input data frame
#' @param var_info Variable information
#' @param treatment_var Treatment variable name
#' @param col_structure Column structure
#' @param treatment_levels Treatment levels
#' @param display_options Display options
#' @param decimals Decimal configuration
#' @return Data frame with continuous variable summary
process_continuous_variable <- function(dataset, var_info, treatment_var, col_structure,
                                       treatment_levels, display_options, decimals) {
  
  source_var <- var_info$source_var
  var_name <- var_info$name
  
  if (!source_var %in% names(dataset)) {
    warning(paste("Variable", source_var, "not found in dataset"))
    return(NULL)
  }
  
  #-----------------------------------------
  # Create summary statistics
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    # Group by treatment
    summary_data <- dataset %>%
      group_by(!!sym(treatment_var)) %>%
      summarise(
        n = sum(!is.na(!!sym(source_var))),
        mean_val = mean(!!sym(source_var), na.rm = TRUE),
        sd_val = sd(!!sym(source_var), na.rm = TRUE),
        median_val = median(!!sym(source_var), na.rm = TRUE),
        min_val = min(!!sym(source_var), na.rm = TRUE),
        max_val = max(!!sym(source_var), na.rm = TRUE),
        Q1_val = quantile(!!sym(source_var), 0.25, na.rm = TRUE),
        Q3_val = quantile(!!sym(source_var), 0.75, na.rm = TRUE),
        missing = sum(is.na(!!sym(source_var))),
        .groups = 'drop'
      )
    
    # Add total row if needed
    if (col_structure == "treatment_with_total") {
      total_summary <- dataset %>%
        summarise(
          !!sym(treatment_var) := "Total",
          n = sum(!is.na(!!sym(source_var))),
          mean_val = mean(!!sym(source_var), na.rm = TRUE),
          sd_val = sd(!!sym(source_var), na.rm = TRUE),
          median_val = median(!!sym(source_var), na.rm = TRUE),
          min_val = min(!!sym(source_var), na.rm = TRUE),
          max_val = max(!!sym(source_var), na.rm = TRUE),
          Q1_val = quantile(!!sym(source_var), 0.25, na.rm = TRUE),
          Q3_val = quantile(!!sym(source_var), 0.75, na.rm = TRUE),
          missing = sum(is.na(!!sym(source_var)))
        )
      summary_data <- bind_rows(summary_data, total_summary)
    }
  } else {
    # Overall summary
    summary_data <- dataset %>%
      summarise(
        !!treatment_levels[1] := "Overall",
        n = sum(!is.na(!!sym(source_var))),
        mean_val = mean(!!sym(source_var), na.rm = TRUE),
        sd_val = sd(!!sym(source_var), na.rm = TRUE),
        median_val = median(!!sym(source_var), na.rm = TRUE),
        min_val = min(!!sym(source_var), na.rm = TRUE),
        max_val = max(!!sym(source_var), na.rm = TRUE),
        Q1_val = quantile(!!sym(source_var), 0.25, na.rm = TRUE),
        Q3_val = quantile(!!sym(source_var), 0.75, na.rm = TRUE),
        missing = sum(is.na(!!sym(source_var)))
      )
  }

   # Format statistics
  format_num <- function(x, dec = as.numeric(decimals$continuous)) {
    if (is.na(x) || !is.finite(x)) return("--")
    format(round(x, dec), nsmall = dec)
  }

  # Format percentages
  format_pct <- function(n, total, dec = as.numeric(decimals$percent)) {
    if (total == 0) return(paste0("0.",paste0(rep(0, dec), collapse = ""), "%"))
    pct <- (n / total) * 100
    format(round(pct, dec), nsmall = dec)
  }
  
  # Create formatted statistics rows
  stat_rows <- list()
  
  # Variable name row
  var_row <- data.frame(
    Variable = var_name,
    stringsAsFactors = FALSE
  )
  
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    for (trt in treatment_levels) {
      var_row[[trt]] <- ""
    }
  } else {
    var_row[["Overall"]] <- ""
  }
  
  stat_rows[[1]] <- var_row
  
  # N row
  n_row <- data.frame(
    Variable = "  n",
    stringsAsFactors = FALSE
  )
  
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    for (trt in treatment_levels) {
      trt_data <- summary_data[summary_data[[treatment_var]] == trt, ]
      n_row[[trt]] <- if(nrow(trt_data) > 0) as.character(trt_data$n) else "0"
    }
  } else {
    n_row[["Overall"]] <- as.character(summary_data$n)
  }
  
  stat_rows[[2]] <- n_row
  
  # Mean (SD) row
  mean_sd_row <- data.frame(
    Variable = "  Mean (SD)",
    stringsAsFactors = FALSE
  )
  
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    for (trt in treatment_levels) {
      trt_data <- summary_data[summary_data[[treatment_var]] == trt, ]
      if(nrow(trt_data) > 0) {
        mean_val <- format_num(trt_data$mean_val)
        sd_val <- format_num(trt_data$sd_val)
        mean_sd_row[[trt]] <- paste0(mean_val, " (", sd_val, ")")
      } else {
        mean_sd_row[[trt]] <- "--"
      }
    }
  } else {
    mean_val <- format_num(summary_data$mean_val)
    sd_val <- format_num(summary_data$sd_val)
    mean_sd_row[["Overall"]] <- paste0(mean_val, " (", sd_val, ")")
  }
  
  stat_rows[[3]] <- mean_sd_row
  
  # Median row
  median_row <- data.frame(
    Variable = "  Median",
    stringsAsFactors = FALSE
  )
  
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    for (trt in treatment_levels) {
      trt_data <- summary_data[summary_data[[treatment_var]] == trt, ]
      median_row[[trt]] <- if(nrow(trt_data) > 0) format_num(trt_data$median_val) else "--"
    }
  } else {
    median_row[["Overall"]] <- format_num(summary_data$median_val)
  }
  
  stat_rows[[4]] <- median_row
  
  # Min, Max row
  min_max_row <- data.frame(
    Variable = "  Min, Max",
    stringsAsFactors = FALSE
  )
  
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    for (trt in treatment_levels) {
      trt_data <- summary_data[summary_data[[treatment_var]] == trt, ]
      if(nrow(trt_data) > 0) {
        min_val <- format_num(trt_data$min_val)
        max_val <- format_num(trt_data$max_val)
        min_max_row[[trt]] <- paste0(min_val, ", ", max_val)
      } else {
        min_max_row[[trt]] <- "--"
      }
    }
  } else {
    min_val <- format_num(summary_data$min_val)
    max_val <- format_num(summary_data$max_val)
    min_max_row[["Overall"]] <- paste0(min_val, ", ", max_val)
  }
  
  stat_rows[[5]] <- min_max_row
  
  # Q1, Q3 row
  Q1_Q3_row <- data.frame(
    Variable = "  Q1, Q3",
    stringsAsFactors = FALSE
  )
  
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    for (trt in treatment_levels) {
      trt_data <- summary_data[summary_data[[treatment_var]] == trt, ]
      Q1_Q3_row[[trt]] <- if(nrow(trt_data) > 0) paste0(format_num(trt_data$Q1_val), ", ", format_num(trt_data$Q3_val)) else "--"
    }
  } else {
    Q1_Q3_row[["Overall"]] <- paste0(format_num(summary_data$Q1_val), ", ", format_num(summary_data$Q3_val))
  }
  
  stat_rows[[6]] <- Q1_Q3_row
  
  # Add missing row if there are missing values in any group
  missing_row <- data.frame(
    Variable = "  Missing",
    stringsAsFactors = FALSE
  )

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



  has_missing <- FALSE
  
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    for (trt in treatment_levels) {
      trt_data <- summary_data[summary_data[[treatment_var]] == trt, ]
      missing_count <- if (nrow(trt_data) > 0) trt_data$missing else 0
      if (!is.na(missing_count) && missing_count > 0) has_missing <- TRUE
      # if has missing, then output missing_count and percentage as xxx (xx.x%)
      missing_row[[trt]] <- if (!is.na(missing_count) && missing_count > 0) paste0(missing_count, " (", format_pct(missing_count, total_n[[trt]]), "%)") else format_pct(0,0)
    }
  } else {
    missing_count <- summary_data$missing
    if (!is.na(missing_count) && missing_count > 0) has_missing <- TRUE
    missing_row[["Overall"]] <- if (!is.na(missing_count) && missing_count > 0) paste0(missing_count, " (", format_pct(missing_count, total_n), "%)") else format_pct(0,0)
  }
  if (has_missing) {
    stat_rows[[length(stat_rows) + 1]] <- rep('',length(missing_row))
    stat_rows[[length(stat_rows) + 2]] <- missing_row
  }
  # Combine all statistic rows beside the first row
  stat_rows <- stat_rows[-1]
   if (length(stat_rows) > 0) {
    result <- do.call(rbind, stat_rows)
    # add the var_name as the first column named group, for tlf format
    result <- cbind(group = var_name, result)
    rownames(result) <- NULL
    return(result)
  }
  return(NULL)
}

#' Process categorical variable
#'
#' @param dataset Input data frame
#' @param var_info Variable information
#' @param treatment_var Treatment variable name
#' @param col_structure Column structure
#' @param treatment_levels Treatment levels
#' @param display_options Display options
#' @param decimals Decimal configuration
#' @return Data frame with categorical variable summary
process_categorical_variable <- function(dataset, var_info, treatment_var, col_structure,
                                       treatment_levels, display_options, decimals) {
  
  source_var <- var_info$source_var
  var_name <- var_info$name
  label_overrides <- var_info$label_overrides

  if (!source_var %in% names(dataset)) {
    warning(paste("Variable", source_var, "not found in dataset"))
    return(NULL)
  }

  ## convert the value of the variables to proper case
  dataset[[source_var]] <- str_to_title(dataset[[source_var]])
  
 
  # If variable has missing values (NA or ''), then replace them with "Missing"
  dataset[[source_var]] <- ifelse(is.na(dataset[[source_var]]) | dataset[[source_var]] == "", "Missing", dataset[[source_var]])
  
  # Get levels
  if (!is.null(var_info$levels)) {
    levels_to_use <- var_info$levels
    # Ensure all unique levels in the dataset are included in levels_to_use
    unique_levels <- sort(unique(dataset[[source_var]][!is.na(dataset[[source_var]])]))
    missing_levels <- setdiff(unique_levels, levels_to_use)
    if (length(missing_levels) > 0) {
      levels_to_use <- c(levels_to_use, missing_levels)
    }
  } else {
    levels_to_use <- sort(unique(dataset[[source_var]][!is.na(dataset[[source_var]])]))
  }
  # if has 'Missing' in levels_to_use, then move it to the end
  if ("Missing" %in% levels_to_use) {
    levels_to_use <- c(setdiff(levels_to_use, "Missing"), "Missing")
  }

#----------------------------------------------------
# Calculate column totals for percentage denominators
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    col_totals <- dataset %>%
      group_by(!!sym(treatment_var)) %>%
      summarise(total = n(), .groups = 'drop')
    
    # Add total row if needed
    if (col_structure == "treatment_with_total") {
      total_summary <- data.frame(
        treatment = "Total",
        total = nrow(dataset),
        stringsAsFactors = FALSE
      )
      names(total_summary)[1] <- treatment_var  # Fix column name
      col_totals <- bind_rows(col_totals, total_summary)
    }
  } else {
    col_totals <- data.frame(
      Overall = "Overall",
      total = nrow(dataset),
      stringsAsFactors = FALSE
    )
  }
  
  # Create summary statistics
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    # Group by treatment and categorical variable
    summary_data <- dataset %>%
      group_by(!!sym(treatment_var), !!sym(source_var)) %>%
      summarise(n = n(), .groups = 'drop') %>%
      complete(!!sym(treatment_var), !!sym(source_var), fill = list(n = 0))
    
    # Add total calculations if needed
    if (col_structure == "treatment_with_total") {
      total_summary <- dataset %>%
        group_by(!!sym(source_var)) %>%
        summarise(n = n(), .groups = 'drop') %>%
        mutate(!!sym(treatment_var) := "Total")
      
      # Reorder columns to match summary_data
      total_summary <- total_summary[, c(treatment_var, source_var, "n")]
      summary_data <- bind_rows(summary_data, total_summary)
    }
  } else {
    # Overall summary
    summary_data <- dataset %>%
      group_by(!!sym(source_var)) %>%
      summarise(n = n(), .groups = 'drop')
    summary_data[["Overall"]] <- "Overall"
  }
  
  # Format percentages
  format_pct <- function(n, total, dec = as.numeric(decimals$percent)) {
    if (total == 0) return(paste0("0.",paste0(rep(0, dec), collapse = ""), "%"))
    pct <- (n / total) * 100
    format(round(pct, dec), nsmall = dec)
  }
  
  # Create formatted rows
  stat_rows <- list()
  
  # Variable name row
  var_row <- data.frame(
    Variable = var_name,
    stringsAsFactors = FALSE
  )
  
  if (col_structure == "treatment" || col_structure == "treatment_with_total") {
    for (trt in treatment_levels) {
      var_row[[trt]] <- ""
    }
  } else {
    var_row[["Overall"]] <- ""
  }
  
  stat_rows[[1]] <- var_row
  
  # Create rows for each level
  for (i in seq_along(levels_to_use)) {
    level <- levels_to_use[i]
    # Apply label override if specified
    display_level <- level
    if (!is.null(label_overrides) && level %in% names(label_overrides)) {
      display_level <- label_overrides[[level]]
    }
    
    level_row <- data.frame(
      Variable = paste0("  ", display_level),
      stringsAsFactors = FALSE
    )
    
    if (col_structure == "treatment" || col_structure == "treatment_with_total") {
      for (trt in treatment_levels) {
        # Get count for this treatment and level
        level_data <- summary_data[summary_data[[treatment_var]] == trt & 
                                  summary_data[[source_var]] == level, ]
        count <- if(nrow(level_data) > 0) level_data$n else 0
        
        # Get total for percentage
        total <- col_totals[col_totals[[treatment_var]] == trt, ]$total
        total <- if(length(total) > 0) total else 0
        
        # Format as "n (xx.x%)"
        pct <- format_pct(count, total)
        level_row[[trt]] <- paste0(count, " (", pct, "%)")
      }
    } else {
      # Get count for this level
      level_data <- summary_data[summary_data[[source_var]] == level, ]
      count <- if(nrow(level_data) > 0) level_data$n else 0
      
      # Get total for percentage
      total <- col_totals$total
      
      # Format as "n (xx.x%)"
      pct <- format_pct(count, total)
      level_row[["Overall"]] <- paste0(count, " (", pct, "%)")
    }
    
    stat_rows[[length(stat_rows) + 1]] <- level_row
  }

# Combine all statistic rows beside the first row
  stat_rows <- stat_rows[-1]
  if (length(stat_rows) > 0) {
    result <- do.call(rbind, stat_rows)
    # add the var_name as the first column named group, for tlf format
    result <- cbind(group = var_name, result)
    rownames(result) <- NULL
    return(result)
  }
  return(NULL)
}


#' Calculate confidence interval
#'
#' @param x Numeric vector
#' @param conf_level Confidence level (default 0.95)
#' @param decimals Number of decimal places
#' @return Character string with CI
#' @export
calculate_confidence_interval <- function(x, conf_level = 0.95, decimals = 2) {
  
  x_clean <- x[!is.na(x)]
  n <- length(x_clean)
  
  if (n < 2) {
    return("--")
  }
  
  mean_val <- mean(x_clean)
  se <- sd(x_clean) / sqrt(n)
  alpha <- 1 - conf_level
  t_val <- qt(1 - alpha/2, df = n - 1)
  
  ci_lower <- mean_val - t_val * se
  ci_upper <- mean_val + t_val * se
  
  return(paste0("(", 
                format(round(ci_lower, decimals), nsmall = decimals), 
                ", ", 
                format(round(ci_upper, decimals), nsmall = decimals), 
                ")"))
}





  