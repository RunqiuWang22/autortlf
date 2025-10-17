# =============================================================================
# AutoRTLF Docker Environment
# =============================================================================
# Purpose: Reproducible R environment for AutoRTLF framework
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================

# Use R 4.4.x base image for stability and FDA compliance
FROM rocker/r-ver:4.4.2

# Set environment variables
ENV R_LIBS_USER=/usr/local/lib/R/site-library
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # R package dependencies
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    # Python for future MCP/AI integration
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # Additional utilities
    git \
    curl \
    wget \
    vim \
    nano \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set working directory
WORKDIR /autortlf

# Copy package installation script first (for Docker layer caching)
COPY install_packages.R .

# Install R packages with exact versions for reproducibility
RUN Rscript install_packages.R

# Copy project files
COPY . .

# Create output directories with proper permissions
RUN mkdir -p outdata outgraph outlist outlog outtable \
    && chmod 755 outdata outgraph outlist outlog outtable

# Create Python virtual environment for future MCP/AI integration
RUN python3 -m venv /autortlf/venv \
    && /autortlf/venv/bin/pip install --upgrade pip

# Set up Python environment activation
ENV PATH="/autortlf/venv/bin:$PATH"

# Create entry point script
RUN echo '#!/bin/bash\n\
echo "=== AutoRTLF Docker Environment ==="\n\
echo "R version: $(R --version | head -1)"\n\
echo "Python version: $(python3 --version)"\n\
echo "Working directory: $(pwd)"\n\
echo "Available commands:"\n\
echo "  - Rscript pganalysis/run_baseline0char.R [metadata] [config]"\n\
echo "  - Rscript pganalysis/run_ae0specific.R [metadata] [config]"\n\
echo "  - Rscript docker_validate.R (run validation)"\n\
echo "  - bash (interactive shell)"\n\
echo ""\n\
if [ "$1" = "bash" ] || [ "$1" = "sh" ]; then\n\
    exec "$@"\n\
else\n\
    exec "$@"\n\
fi' > /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Set entry point
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["bash"]

# Metadata
LABEL maintainer="AutoRTLF Development Team" \
      version="1.0.0" \
      description="AutoRTLF - Automated Regulatory Tables, Listings, and Figures" \
      r.version="4.4.2" \
      python.version="3.11+" \
      reproducibility="FDA-compliant"
