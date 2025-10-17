# =============================================================================
# R Package Installation Script for AutoRTLF Docker Environment
# =============================================================================
# Program: install_packages.R
# Purpose: Install exact versions of R packages for reproducibility
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================

# Install remotes package first for version control
if (!require("remotes", quietly = TRUE)) {
  install.packages("remotes")
}

# Define exact package versions for reproducibility
packages <- list(
  yaml = "2.3.10",
  jsonlite = "2.0.0", 
  dplyr = "1.1.4",
  tidyr = "1.3.1",
  rlang = "1.1.6",
  stringr = "1.5.2",
  r2rtf = "1.2.0",
  optparse = "1.7.5",
  jsonvalidate = "1.3.2"
)

cat("=== Installing R Packages for AutoRTLF ===\n")
cat("R version:", R.version.string, "\n\n")

# Install packages with exact versions
for (pkg in names(packages)) {
  version <- packages[[pkg]]
  cat(sprintf("Installing %s version %s...\n", pkg, version))
  
  tryCatch({
    remotes::install_version(pkg, version = version, upgrade = "never", quiet = TRUE)
    cat(sprintf("✓ Successfully installed %s version %s\n", pkg, version))
  }, error = function(e) {
    cat(sprintf("✗ Error installing %s: %s\n", pkg, e$message))
    # Try alternative installation method
    tryCatch({
      install.packages(pkg, quiet = TRUE)
      cat(sprintf("✓ Installed %s (latest version)\n", pkg))
    }, error = function(e2) {
      cat(sprintf("✗ Failed to install %s: %s\n", pkg, e2$message))
    })
  })
}

cat("\n=== Package Installation Complete ===\n")

# Verify installations
cat("\n=== Verifying Package Versions ===\n")
for (pkg in names(packages)) {
  if (require(pkg, character.only = TRUE, quietly = TRUE)) {
    installed_version <- as.character(packageVersion(pkg))
    expected_version <- packages[[pkg]]
    status <- if (installed_version == expected_version) "✓" else "⚠"
    cat(sprintf("%s %s: %s (expected: %s)\n", status, pkg, installed_version, expected_version))
  } else {
    cat(sprintf("✗ %s: Not available\n", pkg))
  }
}

cat("\n=== AutoRTLF Environment Ready ===\n")
