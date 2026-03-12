#!/usr/env/bin Rscript
# =============================================================================
# Independent Verification for Time to First Adverse Event (tte0ae)
# =============================================================================

library(dplyr)
library(survival)

# Configuration from YAMLs
adsl_path <- "dataadam/adsl.rda"
adae_path <- "dataadam/adae.rda"
output_data_path <- "outdata/X99-ia01/tte0ae_test_output.rds"

# Load datasets
load(adsl_path) # provides adsl object
load(adae_path) # provides adae object
framework_result <- readRDS(output_data_path)

cat("--- Testing Framework Output vs Independent Calculation ---\n\n")

# 1. Prepare data
cat("1. Preparing Independent Test Dataset...\n")

# Apply filters
adsl_filtered <- adsl %>% filter(SAFFL == "Y")
adae_filtered <- adae %>% filter(TRTEMFL == "Y")

# Find first AE
first_ae <- adae_filtered %>%
    filter(!is.na(ASTDT) & as.character(ASTDT) != "") %>%
    mutate(event_dt_val = as.Date(na_if(as.character(ASTDT), ""))) %>%
    group_by(USUBJID) %>%
    summarise(
        first_event_date = if (all(is.na(event_dt_val))) as.Date(NA) else min(event_dt_val, na.rm = TRUE),
        .groups = "drop"
    )

# Merge and calculate censoring
cutoff_date <- as.Date("2025-10-01")

my_test_data <- adsl_filtered %>%
    left_join(first_ae, by = "USUBJID") %>%
    mutate(
        TRTSDT = as.Date(na_if(as.character(TRTSDT), "")),
        TRTEDT = as.Date(na_if(as.character(TRTEDT), "")),
        DTHDTC = as.Date(na_if(as.character(DTHDTC), ""))
    ) %>%
    rowwise() %>%
    mutate(
        censor_date = min(c(TRTEDT, cutoff_date, DTHDTC), na.rm = TRUE)
    ) %>%
    ungroup() %>%
    mutate(
        EVENT = ifelse(!is.na(first_event_date) & first_event_date >= TRTSDT, 1, 0),
        END_DATE = as.Date(ifelse(EVENT == 1, first_event_date, censor_date), origin = "1970-01-01"),
        TIME_DAYS = as.numeric(END_DATE - TRTSDT) + 1,
        TIME_UNIT = TIME_DAYS / 30.4375
    ) %>%
    filter(!is.na(TIME_UNIT) & TIME_UNIT >= 0)

cat(sprintf("Test data built. Total subjects: %d\n\n", nrow(my_test_data)))

# 2. Replicate Statistics calculations
cat("2. Replicating Statistics Calculations...\n")

ref_trt <- "Placebo"
treatments <- c("Xanomeline High Dose", "Xanomeline Low Dose", "Placebo")
trt_labels <- c("X High Dose", "X Low Dose", "Placebo")
names(trt_labels) <- treatments

results_compare <- data.frame(
    Metric = c("Subjects", "Events", "Median Time (months)", "Hazard Ratio", "p-value"),
    stringsAsFactors = FALSE
)

format_num <- function(x, d) {
    if (is.na(x)) {
        return("NE/NC")
    }
    d <- as.numeric(d)
    formatC(round(as.numeric(x), d), format = "f", digits = d)
}

for (trt in treatments) {
    cat(sprintf("\n-- Evaluating Treatment: %s --\n", trt))
    ds_trt <- my_test_data %>% filter(TRT01A == trt)

    col_name <- trt_labels[trt]
    framework_col <- framework_result[[col_name]]

    n_subj <- nrow(ds_trt)
    n_event <- sum(ds_trt$EVENT == 1, na.rm = TRUE)

    # Kaplan Meier fit
    km_fit <- survfit(Surv(TIME_UNIT, EVENT) ~ 1, data = ds_trt)
    median_val <- summary(km_fit)$table["median"]

    hr_val <- NA
    pval_val <- NA

    if (trt != ref_trt) {
        # Cox PH vs Placebo
        ds_comp <- my_test_data %>% filter(TRT01A %in% c(trt, ref_trt))
        if (sum(ds_comp$EVENT == 1) > 0) {
            ds_comp$TRT01A <- factor(ds_comp$TRT01A, levels = c(ref_trt, trt))
            cox_fit <- try(coxph(Surv(TIME_UNIT, EVENT) ~ TRT01A, data = ds_comp), silent = TRUE)
            if (!inherits(cox_fit, "try-error")) {
                summ <- summary(cox_fit)
                hr_val <- summ$conf.int[1, "exp(coef)"]
                pval_val <- summ$sctest["pvalue"]
            }
        }
    } else {
        hr_val <- "Reference"
        pval_val <- "--"
    }

    cat(sprintf("Independent N: %d, Events: %d, Median: %s\n", n_subj, n_event, format_num(median_val, 1)))
    cat(sprintf(
        "Framework   N: %s  Events: %s  Median: %s\n",
        framework_col[2], # Subjects at risk row in framework output
        framework_col[3], # Events row
        framework_col[5]
    )) # Median Time row
    cat(sprintf(
        "Independent HR: %s, p-value: %s\n",
        ifelse(is.numeric(hr_val), format_num(hr_val, 2), hr_val),
        ifelse(is.numeric(pval_val), format_num(pval_val, 2), pval_val)
    ))
    cat(sprintf(
        "Framework   HR: %s  p-value: %s\n",
        framework_col[6], # HR row
        framework_col[7]
    )) # p-value row
}

cat("\n--- Verification completed ---\n")
