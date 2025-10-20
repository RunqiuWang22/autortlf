# AutoRTLF - Open Source Edition
AutoRTLF Development Team (Kan Li, Cursor) 2025-10-16

## Overview

AutoRTLF (Automatic R Tables, Listings, and Figures) is a metadata-driven R framework for generating clinical trial Tables, Listings, and Figures (TLFs) with production-ready quality. This open source edition provides the core framework for reproducible clinical trial reporting and development platform for statistical analyses and TLFs.


## 🚀 Key Advantages

### **⚡ Production-Ready Features**
- **Batch Processing**: Generate multiple tables simultaneously
- **Template-Based**: YAML-driven configuration, no R programming required
- **Comprehensive Logging**: Detailed execution logs for validation
- **Zero Configuration**: One-command setup with Docker

### **🤖 AI & MCP Integration Ready**
- **Metadata-Driven Architecture**: YAML configurations facilitate seamless AI integration
- **MCP Server Compatibility**: Framework designed for AI agent collaboration
- **Rich Documentation for AI Learning**: Comprehensive guides and schema definitions for both human and LLM understanding.
- **AI-Assisted Development**: Fast template creation with AI coding assistants
- **Extensible Design**: Easy to add new TLF types and analysis functions

### **🐳 Container-Based Development**
- **Developer Friendly**: One-command Docker setup for instant environment
- **Regulatory Reproducible**: Identical results across all systems and time periods
- **Version Locked**: Exact R package versions for audit trail compliance
- **Isolated Environment**: No conflicts with existing R installations



## 🌟 Vision & Mission

AutoRTLF is more than just a framework for creating clinical trial TLFs. The vision extends beyond this project is to inspire a new generation of statistical developers and researchers to embrace a movement toward:

- **🤖 Democratizing AI-Assisted Development**: Making complex statistical programming accessible through AI partnerships
- **📊 Advancing Open Source Software in Regulatory Environments**: Proving open-source software value in mission-critical FDA submissions
- **🌱 Growing the Open Source Ecosystem**: Creating sustainable, community-driven solutions for clinical research
- **🚀 Inspiring Innovation**: Encouraging developers to build the next generation of clinical trial tools

**Join us in shaping the future of clinical trial reporting—one template, one contribution, one breakthrough at a time.**


## 🎯 Target Audience

### **Statistical Programmers & Statisticians**
- Generate standardized TLFs for clinical study reports
- Ensure regulatory compliance with reproducible environments
- Customize analyses through configuration files

### **Pharmaceutical & CRO Companies**
- Standardize TLF generation across studies and teams
- Reduce development time with template-based approach
- Ensure quality with validated output formats

### **Regulatory Professionals**
- Audit-ready execution logs and metadata
- Standardized output formats for submissions
- Quality-controlled table generation


## 🎥 Watch the 2-Minute Demo (MUST-SEE):
See how I created a brand new TLF from scratch in minutes with AutoRTLF and an AI assistant. This is a glimpse into a future that is inspiring, eye-opening, and perhaps a little daunting. Don't wait anymore and be left behind, start building now!

<video src="https://www.youtube.com/embed/G-cqRFdvkRA?si=TOmXN2VtK4NkWQej" width="560" height="315" controls></video>


## 🛠️ Core Features

### **Metadata-Driven Configuration**
```yaml
# Example YAML configuration
rfunction: "baseline0char"
type: "Table"
title: "Baseline Characteristics"
population_from: "ADSL"
treatment_var: "TRT01P"
variables:
  - name: "Age (years)"
    source_var: "AGE"
    type: "continuous"
```

### **Docker-Based Development**
```bash
# One-command setup
docker-compose up tlf-dev

# Access RStudio at http://localhost:8787
# username: rstudio, password: tlf123
```

### **Batch Processing System**
```bash
# Generate commands for all tables
Rscript generate_batch_commands.R

# Execute in parallel
.\run_batch_parallel.ps1
```

### **Production-Ready Outputs**
- **RTF Files**: Publication-ready tables with proper formatting
- **Intermediate Data**: RDS and CSV files for validation
- **Execution Logs**: Comprehensive audit trails
- **Multiple Formats**: Support for PDF, DOCX, HTML (Unix systems)

## 📚 Documentation & Learning Resources

### **Getting Started**
1. **User Guide**: `documents/USER_GUIDE.md` - Complete usage instructions
2. **Quick Start**: 5-minute setup guide for immediate results
3. **Examples**: Pre-configured analysis templates in `pganalysis/metadata/`

### **Advanced Development**
1. **Developer Guide**: `TLF_DEVELOPMENT_GUIDE.md` - Complete development framework
2. **API Documentation**: Function references and code examples
3. **Best Practices**: Coding standards and patterns

### **Example Configurations**
- `baseline0char0itt.yaml`: Intent-to-Treat baseline characteristics
- `ae0specific0soc05.yaml`: Adverse events with 5% threshold
- `ae0specific0dec0sae01.yaml`: Serious adverse events with 1% threshold

## ⚡ Quick Start

Choose your preferred setup method:

### Option 1: Local R Environment (Recommended for Quick Testing)

#### Prerequisites
- R 4.0+ installed
- Git for version control

#### Installation & Setup
```bash
# Clone the repository
git clone https://github.com/kan-li/autortlf.git
cd autortlf

# Install required R packages (one-time setup)
Rscript install_packages.R

# Generate all tables with one command
.\run_batch_sequential.ps1
```

#### Generate Individual Tables
```bash
# Generate baseline characteristics table
Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0itt.yaml pgconfig/metadata/study_config.yaml

# Generate adverse events table
Rscript pganalysis/run_ae0specific.R pganalysis/metadata/ae0specific0dec0sae01.yaml pgconfig/metadata/study_config.yaml
```

### Option 2: Docker Container Environment (Recommended for Production)

#### Prerequisites
- Docker Desktop installed and running
- Git for version control

#### Installation & Setup
```bash
# Clone the repository
git clone https://github.com/kan-li/autortlf.git
cd autortlf

# Build the Docker image
docker build -t autortlf:latest .

# Run analysis in container
docker run --rm -v ${PWD}/outtable:/autortlf/outtable -v ${PWD}/outlog:/autortlf/outlog autortlf:latest bash -c "cd /autortlf && Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0itt.yaml pgconfig/metadata/study_config.yaml"
```

#### Interactive Development Environment

**Option A: Command Line Interface**
```bash
# Start interactive development environment
docker run -it --rm -v ${PWD}:/autortlf -p 8787:8787 autortlf:latest bash

# Or use docker-compose for easier management
docker-compose up autortlf
```

**Option B: RStudio Server Interface (Recommended for Interactive Development)**
```bash
# Quick start with official RStudio Server image (RECOMMENDED)
docker run -d --name autortlf-rstudio -p 8787:8787 -e PASSWORD=tlf123 -v ${PWD}:/home/rstudio/autortlf rocker/rstudio:4.4.2

# Install AutoRTLF packages in the running container
docker exec -it autortlf-rstudio bash -c "cd /home/rstudio/autortlf && Rscript install_packages.R"

# Fix path configuration for RStudio environment
docker exec -it autortlf-rstudio bash -c "cd /home/rstudio/autortlf && sed -i 's|/autortlf|/home/rstudio/autortlf|g' pgconfig/metadata/study_config.yaml"
```

#### Access RStudio Server (Docker Option)
1. Open browser: http://localhost:8787
2. Login: username `rstudio`, password `tlf123`
3. Start developing in pre-configured RStudio environment


#### Using Pre-built Docker Images
```bash
# Pull the latest image from Docker Hub
docker pull lkboy2018/autortlf:latest

# Run with pre-built image
docker run --rm -v ${PWD}/outtable:/autortlf/outtable -v ${PWD}/outlog:/autortlf/outlog lkboy2018/autortlf:latest bash -c "cd /autortlf && Rscript pganalysis/run_baseline0char.R pganalysis/metadata/baseline0char0itt.yaml pgconfig/metadata/study_config.yaml"
```

### Path Configuration Notes

**Different environments use different path configurations:**

- **Local R Environment**: Uses relative paths (`study_root: "."`)
- **Docker Container**: Uses absolute paths (`study_root: "/autortlf"`)
- **RStudio Container**: Requires path fix for `/home/rstudio/autortlf`

The `study_config.yaml` file is automatically configured for local usage. For Docker containers, the paths are handled automatically.

### Docker File Management

**Essential Docker Files:**
- **`Dockerfile`**: Main Docker image definition
- **`docker-compose.yml`**: Container orchestration configuration  
- **`install_packages.R`**: R package installation with pinned versions
- **`docker_validate.R`**: Environment validation and testing

**Adding New R Packages:**
1. Edit `install_packages.R` to add new packages with exact versions
2. Rebuild the Docker image: `docker build -t autortlf:latest .`
3. Test the new packages: `docker run autortlf:latest Rscript docker_validate.R`
4. Update documentation with new package versions

**For detailed Docker instructions, see [DOCKER_README.md](DOCKER_README.md)**

### Expected Outputs

After running either option, you'll find:

#### Generated Files
- **RTF Tables**: `outtable/X99-ia01/` - Publication-ready tables
- **Intermediate Data**: `outdata/X99-ia01/` - RDS files for validation
- **Execution Logs**: `outlog/X99-ia01/` - Detailed audit trails
- **Combined Output**: `outtable/X99-ia01/combined/` - Merged RTF files

#### Sample Outputs Include

### Baseline Characteristics
- **`baseline0char0itt.rtf`** - Intent-to-Treat population baseline demographics
- **`baseline0char0itt0overall.rtf`** - Overall baseline characteristics summary (only totoal column)
- **`baseline0char0white.rtf`** - White population baseline characteristics

### Adverse Events
- **`ae0specific0des0sae01.rtf`** - Serious adverse events (≥1% threshold) by decreasing incidence
- **`ae0specific0des0sae05.rtf`** - Serious adverse events (≥5% threshold) by decreasing incidence, no AE term meets the threshold.
- **`ae0specific0soc05.rtf`** - Adverse events by System Organ Class (≥5% threshold)
- **`ae0specific0soc050overall.rtf`** - Overall adverse events summary (only total column)

### Combined Output
- **`combined/X99-ia01_combined_tlf_20251014.rtf`** - Selected tables combined into single document

### Troubleshooting

#### Local R Environment Issues
```bash
# Check R version (requires 4.0+)
R --version

# Install missing packages
Rscript install_packages.R

# Check package installation
Rscript -e "library(yaml); library(dplyr); library(r2rtf)"
```

#### Docker Environment Issues
```bash
# Check Docker is running
docker --version

# Rebuild image if needed
docker build --no-cache -t autortlf:latest .

# Check container logs
docker run --rm autortlf:latest Rscript docker_validate.R
```

#### RStudio Container Path Issues
```bash
# If you get "Dataset file not found" errors in RStudio container, fix paths:
docker exec -it autortlf-rstudio bash -c "cd /home/rstudio/autortlf && sed -i 's|/autortlf|/home/rstudio/autortlf|g' pgconfig/metadata/study_config.yaml"

# Verify the fix worked:
docker exec -it autortlf-rstudio bash -c "cd /home/rstudio/autortlf && grep study_root pgconfig/metadata/study_config.yaml"
```

## 🏢 Full Edition Features

**AutoRTLF Full Edition** - Currently evolving from prototype to enterprise-ready solution, with advanced AI integration and professional deployment capabilities.

### **🤖 Advanced AI Integration**
- **MCP Server AI Agent Support**: Full integration with AI assistants for automated TLF generation
- **AI-Ready Data Pipeline**: Structured data preparation for AI narrative generation to support downstream automated Clinical Study Report
- **Intelligent Template Generation**: AI-powered creation of new TLF templates

### **📊 Extended Analysis Capabilities**
- **Expanded TLF Library**: Comprehensive collection of analysis functions and templates
- **Advanced Statistical Methods**: Proprietary algorithms for complex clinical trial analyses
- **Cross-Table Validation**: Automated consistency checking across multiple outputs
- **Schema Validation**: Built-in validation of data structures and configurations

### **🛠️ Supporting Tools**
- **Table Combination**: Advanced merging and consolidation of multiple TLF outputs
- **Editable Figure Output**: Modifiable graphical outputs
- **Quality Assurance**: Automated validation and quality control systems
- **And More**



## 🤝 Contributing

We welcome contributions from the community! Here's how you can help:

### **Code Contributions**
- Fork the repository
- Create feature branches
- Submit pull requests with comprehensive tests

### **AI-Assisted Template Development**
- Use AI coding assistants (ChatGPT, Claude, Cursor) to generate new TLF templates
- Share your AI-generated templates with the community
- Document your AI prompting strategies for others to learn
- Contribute to our AI-assisted development guide

### **Documentation Improvements**
- Update user guides and examples
- Translate documentation
- Create tutorial videos or blog posts

### **Bug Reports & Feature Requests**
- Use GitHub Issues for bug reports
- Suggest new features through discussions
- Help triage and reproduce issues

### **Community Support**
- Help other users in discussions
- Share your use cases and success stories
- Participate in code reviews

## 📊 Project Structure

```
autortlf/
├── pganalysis/              # Analysis configurations
│   ├── metadata/            # YAML metadata files
│   └── run_*.R             # Runner scripts
├── function/               # R function libraries
│   ├── global/             # Shared utilities
│   └── standard/           # Analysis-specific functions
├── pgconfig/              # Global configuration
│   └── metadata/          # Study-wide settings
├── documents/             # Comprehensive documentation
├── docker/               # Docker configuration
└── examples/             # Sample data and analyses
```


## 🚀 Next Steps

1. **Read the User Guide**: `documents/USER_GUIDE.md` for complete instructions
2. **Try the Examples**: Start with pre-configured templates
3. **Customize for Your Study**: Modify YAML files for your specific needs
4. **Join the Community**: Participate in discussions and contribute

*If you really have difficulty understanding any of the documentation, feel free to let AI handle the things.*





## 📄 License

AutoRTLF is licensed under the MIT License. See [LICENSE](LICENSE) for details.

**Third-Party Dependencies:**
- **r2rtf**: Apache License 2.0 (Merck & Co., Inc.)
- **pharmaverseadam**: Apache License 2.0 (Pharmaverse contributors)
- **rocker/r-ver:4.4.2**: GPL-2 (Rocker Project)
- **rocker/rstudio:4.4.2**: GPL-2 (Rocker Project)

*Sample data is for demonstration purposes only.*




