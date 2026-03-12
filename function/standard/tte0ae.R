#!/usr/env/bin Rscript
# =============================================================================
# Time to First Adverse Event (tte0ae) Analysis Functions
# =============================================================================
# Program: tte0ae.R
# Purpose: Complete TTE analysis pipeline - setup, survival analysis, and output
# Version: 1.0.0
# Created: 2026-03-09
# Author: AutoRTLF Development Team (AI Assistant)
# =============================================================================

library(dplyr)
library(tidyr)
library(rlang)
library(r2rtf)
library(jsonlite)
library(yaml)
library(stringr)
library(survival)

#' Complete TTE AE analysis pipeline
#'
#' @param meta Metadata configuration
#' @param global_config Global configuration
#' @param verbose Logical, whether to print progress messages
#' @param log_file Path to log file
#' @return List with analysis results and output paths
#' @export
tte0ae <- function(meta, global_config = NULL, verbose = TRUE, log_file = NULL) {
    if (verbose) cat("Loading and preparing data...\n")

    # Load population dataset
    population_dataset <- load_analysis_dataset(meta$population_from, global_config, verbose)
    population_dataset <- apply_dataset_filter(population_dataset, meta$population_filter, verbose)

    # Load observation dataset
    observation_dataset <- load_analysis_dataset(meta$observation_from, global_config, verbose)
    observation_dataset <- apply_dataset_filter(observation_dataset, meta$observation_filter, verbose)

    if (verbose) cat("Generating Survival analysis...\n")

    tte_table <- generate_tte0ae_table(population_dataset, observation_dataset, meta, global_config, verbose)

    if (verbose) cat("Generating RTF output...\n")

    output_info <- generate_tte0ae_rtf(tte_table, meta, global_config, verbose)

    if (meta$display_options$create_output_dataset == "TRUE" | isTRUE(meta$display_options$create_output_dataset)) {
        output_info$output_data <- save_intermediate_data(tte_table, meta, global_config, verbose)
    }

    if (verbose) cat("=== TTE Analysis Complete ===\n")

    if (is.null(tte_table)) {
        tte_table <- data.frame(Content = global_config$formatting$display_options$no_data_available_text)
    }
    return(list(
        tte_table = tte_table,
        output_files = output_info,
        metadata = meta,
        global_config = global_config
    ))
}

#' Generate TTE summary table
generate_tte0ae_table <- function(population_dataset, observation_dataset, meta, global_config, verbose = TRUE) {
    treatment_var <- meta$treatment_var
    tte_params <- meta$tte_parameters
    display_options <- meta$display_options
    decimals <- meta$decimals

    start_dt <- tte_params$start_date_var
    event_dt <- tte_params$event_date_var
    ref_trt <- tte_params$reference_treatment
    unit_conv <- tte_params$time_unit_conversion %||% 1

    # Ensure population dataset has at least some records
    if (nrow(population_dataset) == 0) {
        return(NULL)
    }

    # Find first AE per subject
    first_ae <- observation_dataset %>%
        filter(!is.na(!!sym(event_dt)) & as.character(!!sym(event_dt)) != "") %>%
        mutate(event_dt_val = as.Date(na_if(as.character(!!sym(event_dt)), ""))) %>%
        group_by(USUBJID) %>%
        summarise(first_event_date = if (all(is.na(event_dt_val))) as.Date(NA) else min(event_dt_val, na.rm = TRUE), .groups = "drop")

    # Helper: evaluate censoring dates
    get_date_val <- function(rule_val, ds) {
        if (grepl("^GLOBAL\\.", rule_val)) {
            path_parts <- strsplit(sub("^GLOBAL\\.", "", rule_val), "\\.")[[1]]
            val <- global_config
            for (p in path_parts) {
                if (!is.null(val) && p %in% names(val)) val <- val[[p]] else val <- NA
            }
            rule_val <- val
        }

        if (!is.na(rule_val) && rule_val %in% names(ds)) {
            dt_str <- ds[[rule_val]]
            as.Date(na_if(as.character(dt_str), ""))
        } else {
            if (is.na(rule_val) || rule_val == "") {
                return(as.Date(rep(NA, nrow(ds))))
            }
            tryCatch(as.Date(rep(rule_val, nrow(ds))), error = function(e) as.Date(rep(NA, nrow(ds))))
        }
    }

    survival_data <- population_dataset %>%
        left_join(first_ae, by = "USUBJID") %>%
        mutate(
            start_date_str = !!sym(start_dt),
            start_date = as.Date(na_if(as.character(start_date_str), ""))
        )

    # Calculate Earliest Censoring Date
    censor_dates <- lapply(tte_params$censoring_rules, get_date_val, ds = survival_data)
    survival_data$first_censor_date <- do.call(pmin, c(censor_dates, list(na.rm = TRUE)))

    # Calculate Event status and Time
    survival_data <- survival_data %>%
        mutate(
            EVENT = ifelse(!is.na(first_event_date) & first_event_date >= start_date, 1, 0),
            END_DATE = ifelse(EVENT == 1, first_event_date, first_censor_date),
            END_DATE = as.Date(END_DATE, origin = "1970-01-01"),
            TIME = as.numeric(END_DATE - start_date) + 1,
            TIME_UNIT = TIME / unit_conv
        ) %>%
        filter(!is.na(TIME_UNIT) & TIME_UNIT >= 0)

    # Determine treatments order
    treatment_levels <- sort(unique(survival_data[[treatment_var]]))
    if (!is.null(global_config$treatment_config$treatment_order)) {
        ordered <- intersect(global_config$treatment_config$treatment_order, treatment_levels)
        treatment_levels <- c(ordered, setdiff(treatment_levels, ordered))
    }

    # Precompute treatment mappings to match display
    trt_labels <- global_config$treatment_config$treatment_labels

    results <- list()

    format_num <- function(x, d) {
        d <- as.numeric(d)
        formatC(round(as.numeric(x), d), format = "f", digits = d)
    }

    # For each treatment, calculate metrics
    row_risk <- data.frame(Variable = "  Subjects at Risk", stringsAsFactors = FALSE)
    row_event <- data.frame(Variable = "  Subjects with Event (%)", stringsAsFactors = FALSE)
    row_censor <- data.frame(Variable = "  Subjects Censored (%)", stringsAsFactors = FALSE)
    row_median <- data.frame(Variable = sprintf("  Median Time to Event (%s) (95%% CI)", tte_params$time_unit), stringsAsFactors = FALSE)
    row_hr <- data.frame(Variable = "  Hazard Ratio (95% CI) vs Reference", stringsAsFactors = FALSE)
    row_pval <- data.frame(Variable = "  p-value (Log-rank)", stringsAsFactors = FALSE)

    for (trt in treatment_levels) {
        ds_trt <- survival_data %>% filter(!!sym(treatment_var) == trt)
        n_subj <- nrow(ds_trt)
        n_event <- sum(ds_trt$EVENT == 1, na.rm = TRUE)
        n_censor <- n_subj - n_event

        pct_event <- if (n_subj > 0) n_event / n_subj * 100 else 0
        pct_censor <- if (n_subj > 0) n_censor / n_subj * 100 else 0

        col_name <- if (!is.null(trt_labels) && !is.null(trt_labels[[trt]])) trt_labels[[trt]] else trt

        row_risk[[col_name]] <- as.character(n_subj)
        row_event[[col_name]] <- sprintf("%d (%s%%)", n_event, format_num(pct_event, decimals$percent))
        row_censor[[col_name]] <- sprintf("%d (%s%%)", n_censor, format_num(pct_censor, decimals$percent))

        # Kaplan-Meier Median
        if (n_event > 0) {
            km_fit <- survfit(Surv(TIME_UNIT, EVENT) ~ 1, data = ds_trt)
            km_median <- summary(km_fit)$table["median"]
            km_lcl <- summary(km_fit)$table["0.95LCL"]
            km_ucl <- summary(km_fit)$table["0.95UCL"]

            med_str <- ifelse(is.na(km_median), "NE", format_num(km_median, decimals$continuous))
            lcl_str <- ifelse(is.na(km_lcl), "NE", format_num(km_lcl, decimals$continuous))
            ucl_str <- ifelse(is.na(km_ucl), "NE", format_num(km_ucl, decimals$continuous))

            row_median[[col_name]] <- sprintf("%s (%s, %s)", med_str, lcl_str, ucl_str)
        } else {
            row_median[[col_name]] <- "NE (NE, NE)"
        }

        # Hazard Ratio comparisons
        if (trt == ref_trt) {
            row_hr[[col_name]] <- "Reference"
            row_pval[[col_name]] <- "--"
        } else {
            ds_comp <- survival_data %>% filter(!!sym(treatment_var) %in% c(trt, ref_trt))
            if (sum(ds_comp$EVENT == 1) > 0 && n_subj > 0) {
                ds_comp[[treatment_var]] <- factor(ds_comp[[treatment_var]], levels = c(ref_trt, trt))
                form <- reformulate(treatment_var, response = "Surv(TIME_UNIT, EVENT)")
                cox_fit <- try(coxph(form, data = ds_comp), silent = TRUE)
                if (!inherits(cox_fit, "try-error")) {
                    summ <- summary(cox_fit)
                    if (!is.null(summ$conf.int) && nrow(summ$conf.int) >= 1) {
                        hr <- summ$conf.int[1, "exp(coef)"]
                        lcl <- summ$conf.int[1, "lower .95"]
                        ucl <- summ$conf.int[1, "upper .95"]
                        pval <- summ$sctest["pvalue"]

                        row_hr[[col_name]] <- sprintf("%s (%s, %s)", format_num(hr, decimals$hr_pvalue), format_num(lcl, decimals$hr_pvalue), format_num(ucl, decimals$hr_pvalue))
                        row_pval[[col_name]] <- format_num(pval, decimals$hr_pvalue)
                    } else {
                        row_hr[[col_name]] <- "NC"
                        row_pval[[col_name]] <- "NC"
                    }
                } else {
                    row_hr[[col_name]] <- "NC"
                    row_pval[[col_name]] <- "NC"
                }
            } else {
                row_hr[[col_name]] <- "NC"
                row_pval[[col_name]] <- "NC"
            }
        }
    }

    final_table <- as.data.frame(bind_rows(row_risk, row_event, row_censor, row_median, row_hr, row_pval))
    # Prepend bolded group row
    group_row <- final_table[1, ]
    group_row[1, ] <- ""
    group_row$Variable <- "\\b Statistics"
    final_table <- bind_rows(group_row, final_table)

    return(final_table)
}

#' Generate RTF output for TTE table
generate_tte0ae_rtf <- function(tte_table, meta, global_config, verbose = TRUE) {
    project_name <- global_config$study_info$project
    output_dir <- file.path(global_config$paths$outtable_path, project_name)
    if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    }

    output_file <- file.path(output_dir, paste0(meta$rename_output, ".rtf"))

    if (verbose) cat("Writing RTF to:", output_file, "\n")

    rtf_settings <- global_config$formatting$rtf_settings
    total_width <- rtf_settings$page_width %||% 8.5

    title_string <- meta$title %||% "Time to First Adverse Event"
    subtitle_string <- paste0(meta$subtitle1 %||% "", " \n", meta$subtitle2 %||% "")

    treatment_cols <- names(tte_table)[-1]
    n_treatments <- length(treatment_cols)
    variable_width <- 3.5
    remaining_width <- total_width - variable_width

    rtf_obj <- tte_table %>%
        rtf_page(
            orientation = rtf_settings$orientation %||% "portrait",
            height = rtf_settings$page_height %||% 11.0, width = total_width,
            margin = c(1.0, 1.0, 1.0, 1.0, 0.5, 0.5)
        ) %>%
        rtf_title(title_string, subtitle_string) %>%
        rtf_colheader(
            paste(" |", paste(treatment_cols, collapse = " | "), "|"),
            col_rel_width = c(variable_width, rep(remaining_width / n_treatments, n_treatments)),
            border_top = c("", rep("single", n_treatments)),
            border_bottom = "single",
            text_font_size = rtf_settings$font_size %||% 10
        ) %>%
        rtf_body(
            col_rel_width = c(variable_width, rep(remaining_width / n_treatments, n_treatments)),
            text_justification = c("l", rep("c", n_treatments)),
            border_left = c("single", rep("single", n_treatments)),
            border_top = c("", rep("", n_treatments)),
            border_bottom = c("", rep("", n_treatments)),
            text_font_size = rtf_settings$font_size %||% 10
        )

    if (!is.null(meta$footnotes)) {
        footnote_list <- unlist(meta$footnotes)
        rtf_obj <- rtf_obj %>% rtf_footnote(paste(footnote_list, collapse = "\n"))
    }

    if (!is.null(meta$data_source)) {
        rtf_obj <- rtf_obj %>% rtf_source(meta$data_source_text)
    }

    rtf_obj %>%
        rtf_encode() %>%
        write_rtf(file = output_file)

    # Check formats
    if (.Platform$OS.type == "unix" && global_config$output_format$output_tlf_format != "rft") {
        if (global_config$output_format$output_tlf_format %in% c("pdf", "docx", "html")) {
            tryCatch(
                {
                    r2rtf:::rtf_convert_format(input = output_file, output_file = file.path(output_dir, paste0(meta$rename_output, ".", global_config$output_format$output_tlf_format)), format = global_config$output_format$output_tlf_format)
                },
                error = function(e) {
                    cat("Cannot parse PDF locally, skipping.. \n")
                }
            )
        }
    }

    return(list(rtf_file = output_file))
}
