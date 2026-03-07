# eMove Architecture Call Graphs

Date: 2026-03-07

This document summarizes current call relationships for the new ingestion and self-report tooling.

## 1) Subject Ingestion Pipeline

```mermaid
flowchart TD
    A["buildSubjectTrialData"] --> B["parseViconCSV"]
    B --> C["getMarkerNamesFromViconCSV"]
    B --> D["getMetadataFromViconCSV"]
    D --> E["getStimVideoScheduling"]
    E --> F["getMetadataFromUnityLog"]

    A --> G["extractSubjectID"]
    G --> H["normalizeSubjectID"]

    A --> I["getSubjectModalityFileInventory"]
    I --> H
```

## 2) Unity Scheduling + Trial Mapping

```mermaid
flowchart TD
    A["buildSelfReportTrialToUnityMap"] --> B["getStimVideoScheduling"]
    B --> C["getMetadataFromUnityLog"]

    A --> D["Anchor Filter (BASELINE)"]
    D --> E["Candidate Stim Logs"]
    E --> F["trialKey G1..Gn Mapping"]
```

## 3) Self-Report Parsing (Wide CSV to Compact)

```mermaid
flowchart TD
    A["parseSelfReportBodyCSV"] --> B["detectImportOptions/readtable"]
    A --> C["localBuildBlockCatalog"]
    A --> D["localBuildTrialTable"]

    D --> E["normalizeSubjectID"]
    D --> F["GEW Columns (20 per block)"]
    D --> G["bodyActRaw / bodyDeactRaw / textRaw"]

    A --> H["includeBlockTypes Filter"]
    H --> I["trialTable (default: stim only)"]
```

## 4) Self-Report Body Map Visualization

```mermaid
flowchart TD
    A["plotSelfReportBodyMapsByVideo"] --> B["localResolveTrialTable"]
    A --> C["normalizeSubjectID"]
    A --> D["Stimulus Row Filter (G-blocks)"]

    D --> E["localParseBodyMapPoints"]
    E --> F["jsondecode path"]
    E --> G["regex fallback path"]

    A --> H["localRasterizePoints"]
    H --> I["localSmoothMap"]
    I --> J["subplot per video"]
```

## 5) Data Objects Passed Between Modules

```mermaid
flowchart LR
    A["Raw Subject Folder"] --> B["trialData struct"]
    B --> C["metaData.videoIDs + stimScheduling"]
    B --> D["metaData.modalityFileInventory"]

    E["Self-report-body.csv"] --> F["selfReport compact struct"]
    F --> G["trialTable"]
    G --> H["plotSelfReportBodyMapsByVideo"]

    I["Unity logs"] --> J["trialKey->videoID mapTable"]
    J --> K["Future join: self-report x motion"]
```

## 6) Notes

1. Call graphs describe orchestration and parsing only; they do not imply metric computation changes.
2. `plotSelfReportBodyMapsByVideo` currently visualizes self-report maps without emotion coding tables.
3. Mapping from self-report `G1..G15` is currently anchored to logs after `BASELINE` by default.
