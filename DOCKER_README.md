# AutoRTLF Docker Environment
AutoRTLF Development Team (Kan Li, Cursor) 2025-10-16

This document provides instructions for using AutoRTLF in a Docker container for reproducible, FDA-compliant clinical trial analysis.

## 📄 License

AutoRTLF is licensed under the MIT License. See [LICENSE](LICENSE) for details.

**Third-Party Dependencies:**
- **r2rtf**: Apache License 2.0 (Merck & Co., Inc.)
- **pharmaverseadam**: Apache License 2.0 (Pharmaverse contributors)
- **rocker/r-ver:4.4.2**: GPL-2 (Rocker Project)
- **rocker/rstudio:4.4.2**: GPL-2 (Rocker Project)

*Sample data is for demonstration purposes only.*

## 🐳 Quick Start

### Option 1: Use Pre-built Image (Recommended)

```bash
# Pull the latest image
docker pull lkboy2018/autortlf:latest

# Run with your data
docker run -it -v /path/to/your/data:/autortlf/dataadam lkboy2018/autortlf:latest bash
```

### Option 2: Build Locally

```bash
# Clone the repository
git clone https://github.com/kan-li/autortlf.git
cd autortlf

# Build the Docker image
docker build -t autortlf:latest .

# Run the container
docker run -it autortlf:latest bash
```

### Option 3: Use Docker Compose (Development)

```bash
# Start the development environment
docker-compose up -d

# Access the container
docker-compose exec autortlf bash
```

## 📋 Prerequisites

- Docker 20.10+ or Docker Desktop
- Git (for local builds)
- 2GB+ free disk space

## 🔧 Environment Details

### Base Image
- **R**: 4.4.2 (stable, FDA-compliant)
- **Python**: 3.11+ (for future MCP/AI integration)
- **OS**: Ubuntu 22.04 LTS

### Pinned R Packages (Exact Versions)
- yaml: 2.3.10
- jsonlite: 2.0.0
- dplyr: 1.1.4
- tidyr: 1.3.1
- rlang: 1.1.6
- stringr: 1.5.2
- r2rtf: 1.2.0
- optparse: 1.7.5
- jsonvalidate: 1.3.2

## 🚀 Usage Examples

### Run Single Analysis

```bash
# Baseline characteristics table
docker run -v /path/to/data:/autortlf/dataadam autortlf:latest \
  Rscript pganalysis/run_baseline0char.R \
  pganalysis/metadata/baseline0char0itt.yaml \
  pgconfig/metadata/study_config.yaml

# Adverse events table
docker run -v /path/to/data:/autortlf/dataadam autortlf:latest \
  Rscript pganalysis/run_ae0specific.R \
  pganalysis/metadata/ae0specific0dec0sae01.yaml \
  pgconfig/metadata/study_config.yaml
```

### Run Batch Processing

```bash
# Run all analyses in sequence
docker run -v /path/to/data:/autortlf/dataadam autortlf:latest \
  bash -c "cd /autortlf && ./run_batch_sequential.ps1"
```

### Interactive Development

```bash
# Start interactive session
docker run -it -v /path/to/data:/autortlf/dataadam autortlf:latest bash

# Inside container:
Rscript docker_validate.R  # Validate environment
Rscript pganalysis/run_baseline0char.R [args]  # Run analysis
```

## 📁 Data Mounting

### External Data Directory
Mount your ADaM datasets to `/autortlf/dataadam`:

```bash
docker run -v /path/to/your/adam/data:/autortlf/dataadam:ro autortlf:latest
```

### Output Directory
Mount output directory to save results:

```bash
docker run -v /path/to/outputs:/autortlf/outtable autortlf:latest
```

### Full Development Mount
For development with live code changes:

```bash
docker run -it \
  -v /path/to/autortlf:/autortlf \
  -v /path/to/data:/autortlf/dataadam:ro \
  autortlf:latest bash
```

## 🔍 Validation

### Environment Validation
```bash
# Run comprehensive validation
docker run autortlf:latest Rscript docker_validate.R
```

### FDA Compliance Check
```bash
# Verify exact package versions
docker run autortlf:latest Rscript -e "
for(pkg in c('yaml','dplyr','r2rtf')) {
  cat(sprintf('%s: %s\n', pkg, packageVersion(pkg)))
}
"
```

## 🏗️ Building Images

### Local Build
```bash
# Build with version tag
docker build -t autortlf:1.0.0 .

# Build with Docker Hub username
docker build -t lkboy2018/autortlf:1.0.0 .
```

### Push to Registry
```bash
# Tag for Docker Hub
docker tag autortlf:1.0.0 lkboy2018/autortlf:1.0.0
docker tag autortlf:1.0.0 lkboy2018/autortlf:latest

# Push to Docker Hub
docker push lkboy2018/autortlf:1.0.0
docker push lkboy2018/autortlf:latest

# Push to GitHub Container Registry
docker tag autortlf:1.0.0 ghcr.io/lkboy2018/autortlf:1.0.0
docker push ghcr.io/lkboy2018/autortlf:1.0.0
```

## 📦 Adding New R Packages

### Update Package Dependencies
When you need to add new R packages to the Docker image:

1. **Edit `install_packages.R`**:
```r
# Add new packages to the packages list
packages <- c(
  "yaml", "jsonlite", "dplyr", "tidyr", "rlang", "stringr", 
  "r2rtf", "optparse", "jsonvalidate",
  "new_package_1", "new_package_2"  # Add your new packages here
)

# Add version specifications
versions <- c(
  "yaml" = "2.3.10",
  "jsonlite" = "2.0.0",
  # ... existing packages ...
  "new_package_1" = "1.0.0",  # Specify exact versions
  "new_package_2" = "2.1.0"
)
```

2. **Rebuild the Docker image**:
```bash
# Build new image with updated packages
docker build -t autortlf:latest .

# Test the new packages
docker run autortlf:latest Rscript -e "library(new_package_1); packageVersion('new_package_1')"
```

3. **Update documentation**:
   - Update the "Pinned R Packages" section in this README
   - Update `docker_validate.R` if needed
   - Test with `docker run autortlf:latest Rscript docker_validate.R`

### Package Version Management
- **Always pin exact versions** for reproducibility
- **Test packages** before adding to production
- **Document changes** in commit messages
- **Update validation script** if new packages are required

## 📁 Essential Docker Files

### Core Files (Required)
- **`Dockerfile`**: Main Docker image definition
- **`docker-compose.yml`**: Container orchestration configuration  
- **`install_packages.R`**: R package installation with pinned versions
- **`docker_validate.R`**: Environment validation and testing

### File Purposes
- **`Dockerfile`**: Defines the base image, R environment, and package installation
- **`docker-compose.yml`**: Orchestrates multiple containers for development
- **`install_packages.R`**: Ensures exact package versions for reproducibility
- **`docker_validate.R`**: Tests the environment and runs sample analyses

### Optional Files
- **`run_batch_*.ps1`**: Windows PowerShell batch processing scripts (optional)
- **`.dockerignore`**: Excludes unnecessary files from Docker build context

## 📊 FDA Submission Workflow

### 1. Prepare Submission Package
```bash
# Create submission directory
mkdir fda_submission
cd fda_submission

# Pull exact version used in analysis
docker pull [registry]/autortlf:1.0.0-fda

# Save image for offline use
docker save [registry]/autortlf:1.0.0-fda | gzip > autortlf-1.0.0-fda.tar.gz
```

### 2. Document Environment
```bash
# Generate environment report
docker run [registry]/autortlf:1.0.0-fda Rscript docker_validate.R > environment_report.txt

# Save package versions
docker run [registry]/autortlf:1.0.0-fda Rscript -e "
write.csv(installed.packages()[,c('Package','Version')], 'package_versions.csv', row.names=FALSE)
" && docker cp $(docker ps -lq):/autortlf/package_versions.csv .
```

### 3. Reproduce Analysis
```bash
# Load saved image
docker load < autortlf-1.0.0-fda.tar.gz

# Run exact same analysis
docker run -v /path/to/data:/autortlf/dataadam autortlf:1.0.0-fda \
  Rscript pganalysis/run_baseline0char.R [metadata] [config]
```

## 🖥️ RStudio Server Development Environment

### Quick Start with RStudio Server (RECOMMENDED)
```bash
# Use official RStudio Server image (fastest and most reliable setup)
docker run -d --name autortlf-rstudio \
  -p 8787:8787 \
  -e PASSWORD=tlf123 \
  -v ${PWD}:/home/rstudio/autortlf \
  rocker/rstudio:4.4.2

# Install AutoRTLF packages in the running container
docker exec -it autortlf-rstudio bash -c "cd /home/rstudio/autortlf && Rscript install_packages.R"

# Fix path configuration for RStudio environment
docker exec -it autortlf-rstudio bash -c "cd /home/rstudio/autortlf && sed -i 's|/autortlf|/home/rstudio/autortlf|g' pgconfig/metadata/study_config.yaml"

# Access RStudio Server
# Open browser: http://localhost:8787
# Username: rstudio, Password: tlf123
```

### Alternative: Pre-installed Packages (Optional)
```bash
# If you want to pre-install packages in a custom image
docker build -f Dockerfile.rstudio -t lkboy2018/autortlf-rstudio:latest .

# Run with custom image (packages already installed)
docker run -d --name autortlf-rstudio \
  -p 8787:8787 \
  -e PASSWORD=tlf123 \
  -v ${PWD}:/autortlf \
  lkboy2018/autortlf-rstudio:latest
```

**Note**: The official `rocker/rstudio:4.4.2` image is recommended for better reliability and faster setup.

### RStudio Server Features
- **Interactive Development**: Full RStudio IDE in browser
- **Package Management**: AutoRTLF packages installed on demand
- **File System Access**: Mount project directory for development
- **Persistent Sessions**: Save work between container restarts
- **Multi-user Support**: Multiple developers can use same container
- **Official Image**: Uses tested `rocker/rstudio:4.4.2` for reliability

## 📁 Advanced Data Mounting Options

### Mount User Data Locations
```bash
# Mount external data directory
docker run -d --name autortlf-rstudio \
  -p 8787:8787 \
  -e PASSWORD=tlf123 \
  -v /path/to/your/data:/home/rstudio/data \
  -v ${PWD}:/home/rstudio/autortlf \
  rocker/rstudio:4.4.2

# Mount multiple data sources
docker run -d --name autortlf-rstudio \
  -p 8787:8787 \
  -e PASSWORD=tlf123 \
  -v /path/to/adam/data:/home/rstudio/dataadam \
  -v /path/to/sdtm/data:/home/rstudio/datasdtm \
  -v ${PWD}:/home/rstudio/autortlf \
  rocker/rstudio:4.4.2
```

### Network Storage Mounting
```bash
# Mount network drives (Windows)
docker run -d --name autortlf-rstudio \
  -p 8787:8787 \
  -e PASSWORD=tlf123 \
  -v "//server/share/data:/home/rstudio/data" \
  -v ${PWD}:/home/rstudio/autortlf \
  rocker/rstudio:4.4.2

# Mount network drives (Linux/Mac)
docker run -d --name autortlf-rstudio \
  -p 8787:8787 \
  -e PASSWORD=tlf123 \
  -v /mnt/network/data:/home/rstudio/data \
  -v ${PWD}:/home/rstudio/autortlf \
  rocker/rstudio:4.4.2
```

## 🐍 Python Environment for Extensions

### Enable Python Integration
```bash
# Run with Python environment
docker run -d --name autortlf-rstudio \
  -p 8787:8787 \
  -e PASSWORD=tlf123 \
  -v ${PWD}:/home/rstudio/autortlf \
  rocker/rstudio:4.4.2

# Install Python packages in container
docker exec -it autortlf-rstudio bash -c "
  pip install pandas numpy scipy scikit-learn jupyter
  Rscript -e 'install.packages(c(\"reticulate\", \"keras\"))'
"
```

### Custom Python Environment
```bash
# Create custom Dockerfile with Python
cat > Dockerfile.python << 'EOF'
FROM rocker/rstudio:4.4.2

# Install Python and packages
RUN apt-get update && apt-get install -y python3-pip && \
    pip install pandas numpy scipy scikit-learn tensorflow jupyter

# Install R packages for Python integration
RUN Rscript -e "install.packages(c('reticulate', 'keras', 'tensorflow'))"

# Set working directory
WORKDIR /autortlf
EOF

# Build and run
docker build -f Dockerfile.python -t autortlf-python:latest .
docker run -d --name autortlf-python \
  -p 8787:8787 \
  -e PASSWORD=tlf123 \
  -v ${PWD}:/autortlf \
  autortlf-python:latest
```

### Jupyter Integration
```bash
# Start Jupyter alongside RStudio
docker run -d --name autortlf-jupyter \
  -p 8787:8787 \
  -p 8888:8888 \
  -e PASSWORD=tlf123 \
  -v ${PWD}:/home/rstudio/autortlf \
  rocker/rstudio:4.4.2

# Access both interfaces
# RStudio: http://localhost:8787
# Jupyter: http://localhost:8888
```

## 🔧 Troubleshooting

### Common Issues

**Permission Denied**
```bash
# Fix file permissions
docker run --rm -v /path/to/data:/autortlf/dataadam autortlf:latest \
  chown -R $(id -u):$(id -g) /autortlf/dataadam
```

**Missing Data Files**
```bash
# Check mounted data
docker run -v /path/to/data:/autortlf/dataadam autortlf:latest \
  ls -la /autortlf/dataadam
```

**Package Version Mismatch**
```bash
# Verify exact versions
docker run autortlf:latest Rscript -e "
cat('R version:', R.version.string, '\n')
for(pkg in c('yaml','dplyr','r2rtf')) {
  cat(sprintf('%s: %s\n', pkg, packageVersion(pkg)))
}
"
```

**RStudio Server Connection Issues**
```bash
# Check if RStudio Server is running
docker exec autortlf-rstudio ps aux | grep rstudio-server

# Restart RStudio Server
docker exec autortlf-rstudio sudo rstudio-server restart

# Check RStudio Server logs
docker exec autortlf-rstudio tail -f /var/log/rstudio-server.log
```

**Path Configuration Issues**
```bash
# If you get "Dataset file not found" errors, fix the path configuration:
docker exec -it autortlf-rstudio bash -c "cd /home/rstudio/autortlf && sed -i 's|/autortlf|/home/rstudio/autortlf|g' pgconfig/metadata/study_config.yaml"

# Verify the fix worked:
docker exec -it autortlf-rstudio bash -c "cd /home/rstudio/autortlf && grep study_root pgconfig/metadata/study_config.yaml"
```

**Path Configuration Summary:**
- **Local Environment**: `study_root: "."` (relative paths)
- **Docker Container**: `study_root: "/autortlf"` (container paths)
- **RStudio Container**: `study_root: "/home/rstudio/autortlf"` (RStudio paths)

The local `study_config.yaml` is configured for local usage. Docker containers automatically handle path mapping.

**Port Already in Use**
```bash
# Find what's using port 8787
netstat -tulpn | grep 8787

# Stop conflicting containers
docker stop $(docker ps -q --filter "publish=8787")

# Use different port
docker run -d --name autortlf-rstudio \
  -p 8788:8787 \
  -e PASSWORD=tlf123 \
  -v ${PWD}:/home/rstudio/autortlf \
  rocker/rstudio:4.4.2
```

### Debug Mode
```bash
# Run with debug output
docker run -it autortlf:latest bash
# Inside container:
Rscript pganalysis/run_baseline0char.R [args] --verbose
```

## 📚 Additional Resources

- [AutoRTLF User Guide](documents/USER_GUIDE.md)
- [Developer Guide](documents/DEVELOPER_GUIDE.md)
- [Project Architecture](documents/PROJECT_ARCHITECTURE.md)


## 🤝 Support

- **Issues**: [GitHub Issues](https://github.com/kan-li/autortlf/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kan-li/autortlf/discussions)



---

**For FDA submissions**: Always use the exact image version specified in your analysis documentation. Pin all versions for complete reproducibility.
