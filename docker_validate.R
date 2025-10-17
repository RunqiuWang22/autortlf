# =============================================================================
# Docker Validation Script for AutoRTLF
# =============================================================================
# Program: docker_validate.R
# Purpose: Validate Docker environment and run sample analyses
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================

cat("=== AutoRTLF Docker Environment Validation ===\n")
cat("Validation started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n\n")

# Check R environment
cat("=== R Environment ===\n")
cat("R version:", R.version.string, "\n")
cat("Platform:", R.version$platform, "\n")
cat("Working directory:", getwd(), "\n\n")

# Check required packages
required_packages <- c("yaml", "jsonlite", "dplyr", "tidyr", "rlang", "stringr", "r2rtf", "optparse")
cat("=== Package Validation ===\n")

package_status <- data.frame(
  Package = character(),
  Version = character(),
  Status = character(),
  stringsAsFactors = FALSE
)

for (pkg in required_packages) {
  if (require(pkg, character.only = TRUE, quietly = TRUE)) {
    version <- as.character(packageVersion(pkg))
    status <- "✓ Available"
  } else {
    version <- "Not installed"
    status <- "✗ Missing"
  }
  
  package_status <- rbind(package_status, data.frame(
    Package = pkg,
    Version = version,
    Status = status,
    stringsAsFactors = FALSE
  ))
}

print(package_status)
cat("\n")

# Check project structure
cat("=== Project Structure Validation ===\n")
required_dirs <- c("function", "metadatalib", "pganalysis", "pgconfig", "dataadam")
required_files <- c(
  "function/global/setup_functions.R",
  "function/global/statistical_functions.R",
  "pgconfig/metadata/study_config.yaml",
  "pganalysis/metadata/baseline0char0itt.yaml"
)

dir_status <- sapply(required_dirs, function(dir) {
  if (dir.exists(dir)) "✓" else "✗"
})

file_status <- sapply(required_files, function(file) {
  if (file.exists(file)) "✓" else "✗"
})

cat("Directories:\n")
for (dir in required_dirs) {
  cat(sprintf("  %s %s\n", dir_status[dir], dir))
}

cat("\nFiles:\n")
for (file in required_files) {
  cat(sprintf("  %s %s\n", file_status[file], file))
}
cat("\n")

# Test AutoRTLF environment setup
cat("=== AutoRTLF Environment Test ===\n")
tryCatch({
  source("function/global/setup_functions.R")
  setup_tlf_environment(verbose = FALSE)
  cat("✓ AutoRTLF environment setup successful\n")
}, error = function(e) {
  cat("✗ AutoRTLF environment setup failed:", e$message, "\n")
})
cat("\n")

# Test data loading
cat("=== Data Loading Test ===\n")
tryCatch({
  # Check if sample data exists
  data_files <- list.files("dataadam", pattern = "\\.rda$", full.names = TRUE)
  if (length(data_files) > 0) {
    cat("✓ Found", length(data_files), "data files in dataadam/\n")
    for (file in data_files) {
      cat("  -", basename(file), "\n")
    }
  } else {
    cat("⚠ No .rda files found in dataadam/ directory\n")
    cat("  This is normal if using external data mounting\n")
  }
}, error = function(e) {
  cat("✗ Data loading test failed:", e$message, "\n")
})
cat("\n")

# Test configuration loading
cat("=== Configuration Loading Test ===\n")
tryCatch({
  if (file.exists("pgconfig/metadata/study_config.yaml")) {
    global_config <- yaml::read_yaml("pgconfig/metadata/study_config.yaml")
    cat("✓ Global configuration loaded successfully\n")
    cat("  Study ID:", global_config$study_info$study_id, "\n")
    cat("  Project:", global_config$study_info$project, "\n")
  } else {
    cat("⚠ Global configuration file not found\n")
  }
}, error = function(e) {
  cat("✗ Configuration loading failed:", e$message, "\n")
})
cat("\n")

# Test sample analysis (if data available)
cat("=== Sample Analysis Test ===\n")
tryCatch({
  if (file.exists("dataadam/adsl.rda") && file.exists("pganalysis/metadata/baseline0char0itt.yaml")) {
    cat("Running sample baseline characteristics analysis...\n")
    
    # Load and run baseline analysis
    source("function/global/setup_functions.R")
    source("function/standard/baseline0char.R")
    
    # Set up environment
    setup_tlf_environment(verbose = FALSE)
    global_config <- load_global_config("pgconfig/metadata/study_config.yaml")
    meta <- load_tlfs_meta("pganalysis/metadata/baseline0char0itt.yaml", global_config)
    meta <- resolve_global_in_meta(meta, global_config)
    
    # Run analysis
    results <- baseline0char(meta, global_config, verbose = FALSE)
    
    if (!is.null(results) && !is.null(results$output_files)) {
      cat("✓ Sample analysis completed successfully\n")
      cat("  Output file:", results$output_files$rtf_file, "\n")
      cat("  Table rows:", nrow(results$baseline_table), "\n")
    } else {
      cat("⚠ Sample analysis completed but no output generated\n")
    }
  } else {
    cat("⚠ Sample data or configuration not available for testing\n")
    cat("  This is normal if using external data mounting\n")
  }
}, error = function(e) {
  cat("✗ Sample analysis failed:", e$message, "\n")
})
cat("\n")

# Python environment check (for future MCP/AI integration)
cat("=== Python Environment Check ===\n")
tryCatch({
  python_version <- system("python3 --version", intern = TRUE)
  cat("✓ Python available:", python_version, "\n")
  
  if (dir.exists("venv")) {
    cat("✓ Python virtual environment found\n")
  } else {
    cat("⚠ Python virtual environment not found\n")
  }
}, error = function(e) {
  cat("✗ Python environment check failed:", e$message, "\n")
})
cat("\n")

# Summary
cat("=== Validation Summary ===\n")
all_packages_ok <- all(package_status$Status == "✓ Available")
all_dirs_ok <- all(dir_status == "✓")
all_files_ok <- all(file_status == "✓")

if (all_packages_ok && all_dirs_ok && all_files_ok) {
  cat("✓ Docker environment validation PASSED\n")
  cat("✓ AutoRTLF is ready for use\n")
} else {
  cat("⚠ Docker environment validation completed with warnings\n")
  cat("  Some components may need attention\n")
}

cat("\nValidation completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("=== End of Validation ===\n")
