# Metadata Library JSON Schema Documentation

## Overview

This document describes the JSON Schema files for the AutoRTLF metadata library. These schemas provide validation, documentation, and IDE support for the YAML configuration files used in the TLF generation system.

## Schema Files

### 1. `lib_config/study_config.schema.json`

**Purpose**: Validates the global study-level configuration file (`study_config.yaml`)

**Key Features**:
- **Study Information**: Study ID, title, project identifier, environment
- **Path Configuration**: File system paths for all input/output directories
- **Dataset Definitions**: ADaM dataset configurations with format specifications
- **Treatment Configuration**: Treatment arm variables, labels, and ordering
- **Population Definitions**: Analysis population filters and descriptions
- **Formatting Settings**: Decimal places, RTF settings, display options
- **Safety Parameters**: AE-specific variable mappings

**Global Reference Support**: This schema defines the source of all `GLOBAL.*` references used in analysis templates.

### 2. `lib_analysis/baseline0char.schema.json`

**Purpose**: Validates baseline characteristics table configuration templates

**Key Features**:
- **Table Metadata**: Table ID, output naming, titles and subtitles
- **Data Configuration**: Population dataset, filtering, treatment variables
- **Display Options**: Statistical measures to include (mean, median, range, IQR)
- **Variable Definitions**: List of variables with types and categorical level mappings
- **Output Formatting**: Decimal places, footnotes, data source text
- **Global References**: Support for `GLOBAL.*` parameter references

**Variable Types Supported**:
- `continuous`: Age, weight, lab values (displays N, mean±SD, median, min-max)
- `categorical`: Sex, race, region (displays N, n(%) per level)

### 3. `lib_analysis/ae0specific.schema.json`

**Purpose**: Validates adverse events specific table configuration templates

**Key Features**:
- **Dual Dataset Support**: Separate population and observation datasets
- **AE Parameters**: Threshold settings, term variables, grouping options
- **Advanced Sorting**: Multi-level sorting by frequency or alphabetical
- **Grouping Configuration**: SOC, body system, severity, or custom grouping
- **Filter Expressions**: Complex observation filters (e.g., treatment-emergent, serious AEs)
- **Display Customization**: Headers, proper case conversion, column selection

**AE-Specific Parameters**:
- `min_subjects_threshold`: Percentage threshold for AE display
- `ae_term_var`: Primary AE term (AEDECOD, AELLT, etc.)
- `group_by_var`: Grouping variable (AESOC, AEBODSYS, AESEV, etc.)
- `sort_options`: Complex sorting configuration

## Global Reference System

The schema system supports a global reference mechanism using the pattern `GLOBAL.path.to.parameter`. This allows analysis templates to reference values from the study configuration:

### Examples:
```yaml
# In analysis template
population_filter: GLOBAL.population.SAFETY.filter_expression
treatment_var: GLOBAL.treatment_config.treatment_actual_var
decimals:
  continuous: GLOBAL.formatting.decimals.continuous

# Resolves to values from study_config.yaml
population:
  SAFETY:
    filter_expression: 'SAFFL == "Y"'
treatment_config:
  treatment_actual_var: "TRT01A"
formatting:
  decimals:
    continuous: 1
```

## Schema Validation Features

### 1. **Type Safety**
- Ensures proper data types (string, number, boolean, array, object)
- Validates enum values for controlled vocabularies
- Enforces required fields and prevents unknown properties

### 2. **Pattern Validation**
- Table ID format validation (e.g., "Table 12.1.1.x")
- Output filename patterns (alphanumeric and underscore only)
- Date format validation (YYYY-MM-DD)
- Global reference pattern matching

### 3. **Conditional Logic**
- Categorical variables require `levels` and optional `label_overrides`
- AE grouping requires both `group_by_var` and `group_display_name`
- Sort options validation based on sort method

### 4. **Range Validation**
- Decimal places: 0-10
- Percentage thresholds: 0-100
- Font sizes: 6-72 points
- Margins: 0-10 inches

## Usage in Development

### 1. **IDE Integration**
Modern IDEs with YAML support can use these schemas for:
- Auto-completion of field names and values
- Real-time validation and error highlighting
- Documentation tooltips and help text

### 2. **Validation Scripts**
```r
# R validation example
library(jsonlite)
library(jsonvalidate)

# Validate study config
schema <- fromJSON("metadatalib/lib_config/study_config.schema.json")
config <- yaml::read_yaml("pgconfig/metadata/study_config.yaml")
validate <- json_validator(schema)
validate(toJSON(config, auto_unbox = TRUE))
```

### 3. **MCP Integration**
These schemas will be used by the Model Context Protocol (MCP) server to:
- Validate AI-generated configurations
- Provide structured prompts for configuration generation
- Enable intelligent configuration assistance

## Best Practices

### 1. **Template Development**
- Always validate templates against schemas before deployment
- Use meaningful descriptions in schema annotations
- Test global reference resolution

### 2. **Schema Maintenance**
- Update schemas when adding new features to R functions
- Maintain backward compatibility when possible
- Document breaking changes in version history

### 3. **Error Handling**
- Provide clear error messages for validation failures
- Include examples of correct usage in schema descriptions
- Test edge cases and boundary conditions

## Version Control

Each schema includes version information and change history:
- Schema version in `$id` field
- Change documentation in description
- Backward compatibility notes

## Future Enhancements

Planned improvements to the schema system:
1. **Additional Table Types**: Laboratory, vital signs, efficacy tables
2. **Enhanced Validation**: Cross-field validation, dependency checking
3. **Dynamic Schemas**: Runtime schema generation based on dataset structure
4. **Integration Testing**: Automated validation in CI/CD pipeline

## Support and Troubleshooting

For schema-related issues:
1. Check schema validation errors for specific field problems
2. Verify global reference paths exist in study configuration
3. Ensure required fields are present and properly formatted
4. Test with minimal valid examples before adding complexity
