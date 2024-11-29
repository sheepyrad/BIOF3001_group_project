# Project Documentation: Mpox Transmission Analysis and CFR Estimation

## Overview

This project involves the estimation of the reproduction number (Rt) and the Case Fatality Rate (CFR) for the Mpox epidemic in several countries. The analysis includes deconvolution of reported case data to estimate infection curves, followed by Rt estimation using the **EpiEstim** package and CFR analysis with different smoothing methods. Interactive visualizations are provided through Shiny apps, allowing users to explore the data for different countries and time periods.

The following steps are involved in the analysis pipeline:

1. **Data Preprocessing**: Import and clean the data, including handling missing values and converting date formats.
2. **Deconvolution of Case Data**: Using the **DeconvolutionIncidence1** function, we obtain infection dates from reported case counts.
3. **Rt Estimation**: Estimate the reproduction number (Rt) using the **EpiEstim** package.

4. **CFR Calculation**: Estimate the case fatality rate (CFR) for different hypothetical values of the time lag (T).
5. **Visualization**: Use Shiny apps for interactive visualizations of Rt and CFR trends.

## Work distribution

1. **Conrad**: 
    - Data cleaning [/data/mpox.csv, /data/mpox_USA.csv]
    - Rt estimation [/rt/main_mpox_USA.R, main_deconvol_US.R]
    - Overall Data visualization [plot_with_epi.R] 
    - CFR estimation for USA and DRC [cfr_T.R]
2. **Joanne**: 
    - DRC data cleaning [/data/mpox_DRC.csv]  
    - Rt estimation [/rt/main_mpox_DRC.R, main_deconvol_DRC.R]
3. **Martin**: 
    - UG data cleaning [/data/mpox_UG.csv]  
    - Rt estimation [/rt/main_mpox_UG.R, main_deconvol_UG.R]
4. **Coco**: 
    - BU data cleaning [/data/mpox_BU.csv]  
    - Rt estimation [/rt/main_mpox_BU.R, main_deconvol_BU.R]

## Workflow

### 1. Processed Data Files

The processed data files for different countries are stored in the `/rds/` directory and include:
- **transmissibility_USA.rds**: Rt estimation data for the United States.
- **transmissibility_DRC.rds**: Rt estimation data for the Democratic Republic of Congo (DRC).
- **transmissibility_UG.rds**: Rt estimation data for Uganda.
- **transmissibility_BU.rds**: Rt estimation data for Burundi.
- **mpox_data.rds**: Case incidence and death data for United states and Democratic Republic of Congo.

### 2. Deconvolution of Case Data

The deconvolution step estimates the underlying infection curve based on reported cases. This process uses the **DeconvolutionIncidence1** function, which is called in the country-specific scripts under the `/rt/[Country]/` folder. For example, the file `/rt/US/main_deconvol_US.R` estimates the infection curve for the United States.

Key steps in this process:
- Load and preprocess raw case data (`mpox_USA.csv`) [stored in the /data directory].
- Apply a gamma distribution to model the incubation period.
- Estimate the convolution of the case data using the `pgamma` function to obtain the infection curve.
- Plot the results and save the deconvolution output as a CSV file to the `/output/[Country]` directory.

### 3. Rt Estimation

The Rt estimation process is handled by the **EpiEstim** package. For each country, the deconvolved infection data is used to estimate Rt over time. The Rt estimation script for the United States is found in `/rt/US/main_mpox_US.R`, which performs the following:
- Use the infection curve (`/output/[Country]/deconvolInfection_[Country]_R.csv`).
- Estimate the serial interval and apply the **EpiEstim** method to calculate Rt.
- Save the results to `/output/[Country]/mpox_Rt_local_transmissibility_[Country].xlsx`.
- Save the serial interval estimation to `/output/[Country]/mpox_Rt_serial_interval_[Country].xlsx`

### 4. CFR Calculation

The Case Fatality Rate (CFR) is calculated based on the total number of deaths and cases over time. The calculation can be done for a single hypothetical value of the time lag (T) or multiple T values (for comparison). This is handled in the `cfr_T.R` script. The CFR is calculated for different smoothing options (raw, 7-day moving average, loess smoothing, or spline smoothing) and displayed in an interactive plot.

The steps involved in CFR calculation:
- Import and preprocess the data.
- Calculate the CFR for a given time lag (T).
- Provide options for smoothing the CFR data.
- Render interactive plots using Plotly for visualization.

### 5. Interactive Visualizations

There are two primary interactive visualizations available:

1. **Rt Visualization**: This visualization shows the Rt over time, along with the confidence intervals and reproduction thresholds. The plot is created by the `plot_with_epi.R` script and is displayed using Plotly in a Shiny app.
2. **CFR Visualization**: The CFR visualization allows users to explore how the CFR changes over time for different hypothetical T values. This visualization is rendered using the `cfr_T.R` script and is available in a separate Shiny app.

### 6. Running the Analysis

To run the analysis, follow these steps:

1. **Deconvolution**: First, run the deconvolution script for the selected country. For example, run `/rt/US/main_deconvol_US.R` for the United States, followed by `/rt/US/main_mpox_US.R` to estimate Rt.
2. **CFR Calculation**: For CFR visualization, run the `cfr_T.R` script directly, which will process the data and display the CFR plot.
3. **Rt Visualization**: After running the deconvolution and Rt estimation scripts for the four countries, execute the `plot_with_epi.R` script to generate the Rt visualization.

### 7. Attribution

We would like to express our heartfelt gratitude to **Prof. Kathy Leung** for her invaluable guidance and mentorship throughout this project. Our special thanks go to **Ms. Chrissy Pang** and **Mr. Zhenyu Wang** for their generous assistance and contributions, particularly for providing the `DeconvolutionIncidence1.R` function, which serves as a core component in the Rt analysis.

Additionally, we acknowledge the use of **ChatGPT 4o** and **ChatGPT o1-preview** for generating and annotating code, which significantly facilitated our workflow.
