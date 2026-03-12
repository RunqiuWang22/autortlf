/*
Prompt for AI Assistant: Develop New TLF - 'Time to First Adverse Event' Table (tte0ae)

Background:
You are tasked to develop a new Table/Listing/Figure (TLF) template in the AutoRTLF framework, named `tte0ae`, that summarizes the time to first adverse event (survival analysis) for trial participants. Before you begin, thoroughly read [documents/DEVELOPER_GUIDE.md](cci:7://file:///Users/runqiuwang/Downloads/autortlf-main/autorif/documents/DEVELOPER_GUIDE.md:0:0-0:0). Pay close attention to project architecture, template-driven workflow, schema-validation, and the **AI-Assisted Development** section guiding automated code and metadata creation. Review the existing `ae0specific` and `baseline0char` templates to understand conventions on dataset merging, population selection, data source, display options, configuration patterns, and output formatting.

TLF Purpose:
- Summarize the time to first adverse event (in days or months) for the specified population (e.g., Safety Population) by merging the ADSL and ADAE datasets.
- Time to event should be calculated (user-selectable via YAML metadata):
  1. From treatment start date (`adsl.TRTSDT`) to start date of the first adverse event (`adae.ASTDT`).
- Define specific censoring rules (user-selectable via YAML metadata):
  1. If a participant does not experience an AE, censor them at the treatment end date (`adsl.TRTEDT`), study cutoff date (`GLOBAL.study_info.data_cutoff_date`), or death date (`adsl.DTHDTC`) whichever comes first.
- The selection must be reflected in output, with appropriate footnote displayed:
    - Footnote 1: *Time to First Adverse Event is defined as the time from treatment start to the onset date of the first adverse event. Participants without an event are censored at their last known follow-up date.*
- Include survival analysis statistics using standard packages (e.g., Kaplan-Meier product-limit estimates):
  - Number of participants at risk, number with an event, number censored.
  - Median time to event (with 95% Confidence Interval) per treatment group.
  - Hazard Ratio (with 95% Confidence Interval) and p-value (e.g., log-rank test or Cox proportional hazards model) comparing treatment groups.
- Allow the YAML configuration to control:
  - Which population to display (Safety, ITT, etc.), referencing the `baseline0char` example for this pattern.
  - Whether to display time in months or days (user option).
  - Which treatment variable to use for group comparison.
  - Optional filtering criteria for Adverse Events in ADAE (e.g., Severe AEs only, or specific System Organ Class / Preferred Term).
- Use existing conventions for `rfunction`, data source, and output columns.
- Populate example YAML configuration showing all user-selectable options.

Instructions for AI Assistant:
1. Read [documents/DEVELOPER_GUIDE.md](cci:7://file:///Users/runqiuwang/Downloads/autortlf-main/autorif/documents/DEVELOPER_GUIDE.md:0:0-0:0). Adhere rigorously to project patterns for TLF creation, consolidated functions, and configuration structure.
2. Refer to the `ae0specific` template/examples for:
  - Dataset merging between `adae` (observation) and `adsl` (population).
  - Filtering events by population and specific AE criteria.
3. Refer to the `baseline0char` template/examples for:
  - Display/configuration options (e.g., treatment columns, display_total).
  - Output formatting and metadata.
  - Convert all date variables involved to Date format.
  - Default unit for analysis time to be months.
4. Create the following deliverables:
  - JSON Schema file: `metadatalib/lib_analysis/tte0ae.schema.json`
  - YAML template: `metadatalib/lib_analysis/tte0ae.yaml`
  - R function file: `function/standard/tte0ae.R` (utilizing the `survival` package for Kaplan-Meier/Cox models calculation)
  - CLI runner file: `pganalysis/run_tte0ae.R`
  - Test metadata instance: `pganalysis/metadata/tte0ae0test.yaml`
