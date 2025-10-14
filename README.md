# Climate Model Diagnostics - TaiESM Analysis Scripts

[![NCL Version](https://img.shields.io/badge/NCL-6.6.2+-blue.svg)](https://www.ncl.ucar.edu/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Project Overview

This repository contains **NCL (NCAR Command Language)** diagnostic scripts for analyzing and validating climate model outputs from the **TaiESM (Taiwan Earth System Model)**. The scripts compare model simulations against observational datasets across multiple climate variables including sea ice concentration, precipitation, surface air temperature, and sea surface temperature.

### Purpose

These diagnostic scripts are designed to:
- Evaluate model performance against observational data
- Generate publication-quality visualizations
- Calculate key statistical metrics (bias, RMSE, correlation, trends)
- Support climate model development and validation workflows

---

## Table of Contents

1. [Repository Structure](#repository-structure)
2. [Installation & Dependencies](#installation--dependencies)
3. [Quick Start Guide](#quick-start-guide)
4. [Script Documentation](#script-documentation)
   - [Sea Ice Concentration Analysis](#1-sea-ice-concentration-analysis)
   - [Precipitation Analysis](#2-precipitation-analysis)
   - [Surface Air Temperature Analysis](#3-surface-air-temperature-analysis)
   - [Sea Surface Temperature Analysis](#4-sea-surface-temperature-analysis)
5. [Common Workflows](#common-workflows)
6. [Output Files](#output-files)
7. [Contributing](#contributing)
8. [License](#license)
9. [Contact](#contact)

---

## Repository Structure

```
TaiESM-TIMCOM-Diags/
├── README.md                     # This file - main documentation
├── LICENSE                       # License information
├── scripts/                      # Main diagnostic scripts
│   ├── diag_ice.ncl             # Sea ice concentration analysis
│   ├── diag_precipitation.ncl    # Precipitation comparison
│   ├── diag_SAT.ncl             # Surface air temperature analysis
│   └── diag_SST.ncl             # Sea surface temperature analysis
├── docs/                         # Detailed documentation
│   ├── script_details.md        # In-depth script explanations
│   ├── data_requirements.md     # Data format specifications
│   └── troubleshooting.md       # Common issues and solutions
└── examples/                     # Example output files
    ├── figures/                 # Sample visualization outputs
    └── statistics/              # Sample statistics files
```

---

## Installation & Dependencies

### System Requirements

- **NCL (NCAR Command Language)** version 6.6.2 or higher
- Linux/Unix operating system (tested on Ubuntu 24)
- Minimum 8GB RAM (16GB+ recommended for large datasets)
- Storage space for model output and observational data

### NCL Installation

#### Option 1: Conda (Recommended)
```bash
conda create -n ncl_env -c conda-forge ncl
conda activate ncl_env
```

#### Option 2: From Source
Follow the official NCL installation guide: https://www.ncl.ucar.edu/Download/

### Required NCL Libraries

The scripts automatically load these standard NCL libraries:
- `gsn_code.ncl` - Core NCL graphics functions
- `gsn_csm.ncl` - Climate-specific plotting functions
- `contributed.ncl` - Community-contributed functions

### Environment Setup

Set the NCL root directory (if not already configured):
```bash
export NCARG_ROOT=/path/to/ncl
```

Verify installation:
```bash
ncl -V
```

---

## Quick Start Guide

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/TaiESM-TIMCOM-Diags.git
cd TaiESM-TIMCOM-Diags
```

### 2. Prepare Your Data

Ensure your data follows the expected structure:
```
/your/data/path/
├── MOD/                    # Model output directory
│   └── [model_name]/
│       ├── ice/hist/       # Sea ice model output
│       ├── atm/hist/       # Atmospheric model output
│       └── ocn/hist/       # Ocean model output
└── OBS/                    # Observational data directory
    └── OBS/
        ├── seaice_conc_*.nc
        ├── gpcp.*.nc
        ├── best.tas.*.nc
        └── hadisst.sst.*.nc
```

### 3. Configure Script Paths

Edit the configuration section in each script to match your data locations:

```ncl
; Example configuration
model_dir = "/path/to/your/MOD/B1850_TAI/ice/hist/"
obs_dir   = "/path/to/your/OBS/OBS/"
output_dir = "./output/"
```

### 4. Run a Script

```bash
ncl scripts/diag_ice.ncl
```

### 5. Check Output

Results will be saved in the specified output directory:
- PNG/PDF visualization files
- Text files with statistical metrics
- Log output in terminal

---

## Script Documentation

### 1. Sea Ice Concentration Analysis

**Script:** `scripts/diag_ice.ncl`

**[📄 Detailed Documentation](#sea-ice-concentration-analysis-detailed)**

#### Overview
Analyzes sea ice concentration from CESM/CICE model output and compares against NOAA/NSIDC Climate Data Record observations for both Northern and Southern Hemispheres.

#### Key Features
- Calculates Sea Ice Area (SIA) with 15% concentration threshold
- Handles pole hole filling for Arctic region
- Processes monthly data and computes climatological means
- Generates spatial maps and time series plots
- Computes statistical metrics (bias, RMSE, correlation)

#### Input Requirements
- **Model Data:** CICE monthly history files (`.nc`)
  - Variables: `aice` (ice concentration), `tarea` (grid cell area), `TLAT`, `TLON`
- **Observational Data:** NOAA/NSIDC CDR sea ice concentration
  - Northern Hemisphere: `seaice_conc_monthly_nh_*.nc`
  - Southern Hemisphere: `seaice_conc_monthly_sh_*.nc`

#### Configuration Parameters
```ncl
climo_year_start = 1979    ; Start year for analysis
climo_year_end = 2005      ; End year for analysis
start_year = 129           ; Model year start (relative to model calendar)
end_year = 155             ; Model year end
sic_threshold = 15.0       ; Sea ice concentration threshold (%)
```

#### Output Files
- `Figure10_Mean_SIC_1979-2005.png` - Spatial distribution maps (NH & SH)
- `Figure11_Annual_SIA_1979-2005.png` - Time series comparison
- Console output with statistical summary

#### Usage Example
```bash
# Edit configuration section in the script
vi scripts/diag_ice.ncl

# Run the analysis
ncl scripts/diag_ice.ncl
```

---

### 2. Precipitation Analysis

**Script:** `scripts/diag_precipitation.ncl`

**[📄 Detailed Documentation](#precipitation-analysis-detailed)**

#### Overview
Compares model precipitation output from TaiESM/CAM against GPCP (Global Precipitation Climatology Project) observational data.

#### Key Features
- Combines convective (PRECC) and large-scale (PRECL) precipitation
- Unit conversion from m/s to mm/day
- Automatic grid regridding to observational grid
- Adaptive coordinate handling (1D or 2D grids)
- Calculates global mean time series and trends

#### Input Requirements
- **Model Data:** CAM atmospheric model output (`.nc`)
  - Variables: `PRECC`, `PRECL` (precipitation rates in m/s)
- **Observational Data:** GPCP monthly mean precipitation
  - File: `gpcp.mon.mean.*.nc`
  - Variable: `precip` (mm/day)

#### Configuration Parameters
```ncl
year_start = 1980                              ; Analysis start year
year_end = 1999                                ; Analysis end year
color_levels_precip = (/1.0, 12.0, 1.0/)      ; Min, max, spacing for plots
color_levels_diff = (/-3.0, 3.0, 0.2/)        ; Difference plot levels
```

#### Output Files
- `precipitation_spatial_1980-1999.png` - Three-panel spatial comparison
- `precipitation_timeseries_1980-1999.png` - Annual mean time series
- `precipitation_statistics_1980-1999.txt` - Comprehensive statistics file

#### Usage Example
```bash
# Configure analysis period
ncl scripts/diag_precipitation.ncl
```

---

### 3. Surface Air Temperature Analysis

**Script:** `scripts/diag_SAT.ncl`

**[📄 Detailed Documentation](#surface-air-temperature-analysis-detailed)**

#### Overview
Evaluates surface air temperature from TaiESM/CAM against Berkeley Earth Surface Temperature (BEST) observations with anomaly analysis.

#### Key Features
- Temperature unit conversion (Kelvin to Celsius)
- Monthly climatology-based anomaly calculation
- Baseline period configuration (1951-1980)
- Weighted global mean with cosine latitude weighting
- Long-term trend analysis (1870-1970)

#### Input Requirements
- **Model Data:** CAM atmospheric history files
  - Variable: `TREFHT` (reference height temperature in K)
- **Observational Data:** Berkeley Earth surface temperature
  - File: `best.tas.*.nc`
  - Variable: `tas` (surface temperature in °C)
  - Time format: YYYYMM integer

#### Configuration Parameters
```ncl
year_start = 1870              ; Historical period start
year_end = 1970                ; Historical period end
climo_year_start = 1951        ; Anomaly baseline start
climo_year_end = 1980          ; Anomaly baseline end
```

#### Output Files
- `temperature_spatial_1870-1970.png` - Climatology maps and difference
- `temperature_timeseries_1870-1970.png` - Anomaly time series
- `temperature_statistics_1870-1970.txt` - Statistical summary

#### Usage Example
```bash
ncl scripts/diag_SAT.ncl
```

---

### 4. Sea Surface Temperature Analysis

**Script:** `scripts/diag_SST.ncl`

**[📄 Detailed Documentation](#sea-surface-temperature-analysis-detailed)**

#### Overview
Compares ocean model SST from TaiESM/TIMCOM with HadISST observational dataset, including volume-averaged ocean temperature analysis.

#### Key Features
- Processes 3D ocean temperature fields
- Calculates volume-averaged temperature using layer depths
- Handles complex ocean model grid topology
- Masks land/ice regions automatically
- Computes decadal trends

#### Input Requirements
- **Model Data:** 
  - Monthly ocean history files: `DATA_YYYYMM.nc`
  - Grid topology file: `TOPO.nc`
  - Variables: `temperature` (3D field), `lev_c`, `lev_f`
- **Observational Data:** HadISST
  - File: `hadisst.sst.*.nc`
  - Variable: `sst` (sea surface temperature)
  - Time format: YYYYMM integer

#### Configuration Parameters
```ncl
start_year = 1870                   ; Analysis start year
end_year = 1970                     ; Analysis end year
model_start_year = 1850             ; Model calendar reference year
plot_model_spatial = True           ; Enable/disable spatial plots
```

#### Output Files
- `TaiESM_HadISST_comparison_1870-1970_spatial.png` - SST spatial patterns
- `TaiESM_HadISST_comparison_1870-1970_timeseries.png` - Time series (SST & volume-averaged)
- `TaiESM_HadISST_comparison_1870-1970_statistics.txt` - Statistical metrics

#### Usage Example
```bash
ncl scripts/diag_SST.ncl
```

---

## Common Workflows

### Workflow 1: Complete Model Validation Suite

Run all diagnostic scripts sequentially for comprehensive model evaluation:

```bash
#!/bin/bash
# run_all_diagnostics.sh

echo "Starting climate model diagnostics..."

# 1. Sea ice analysis
echo "=== Sea Ice Analysis ==="
ncl scripts/diag_ice.ncl

# 2. Precipitation analysis
echo "=== Precipitation Analysis ==="
ncl scripts/diag_precipitation.ncl

# 3. Surface air temperature
echo "=== Surface Air Temperature ==="
ncl scripts/diag_SAT.ncl

# 4. Sea surface temperature
echo "=== Sea Surface Temperature ==="
ncl scripts/diag_SST.ncl

echo "All diagnostics complete! Check ./output/ for results."
```

### Workflow 2: Time Period Comparison

Modify scripts to compare different time periods:

```ncl
; Compare pre-industrial vs. modern period
; Run 1: 1850-1900
year_start = 1850
year_end = 1900

; Run 2: 1950-2000
year_start = 1950
year_end = 2000
```

### Workflow 3: Multi-Model Comparison

Create batch processing for multiple models:

```bash
for model in B1850_TAI BTHIST_test08a B20TR_LENS; do
    sed "s/MODEL_NAME/$model/g" diag_template.ncl > diag_${model}.ncl
    ncl diag_${model}.ncl
done
```

---

## Output Files

### Visualization Outputs

All scripts generate publication-quality PNG figures:

| Output Type | Description | Typical Resolution |
|-------------|-------------|-------------------|
| Spatial Maps | Geographic distribution with coastlines | 1200x800 pixels |
| Time Series | Annual/monthly evolution plots | 1000x600 pixels |
| Panel Plots | Multi-panel comparisons | 1200x1600 pixels |

### Statistical Output Files

Text files containing:
- Global/regional mean values
- Bias (Model - Observation)
- RMSE (Root Mean Square Error)
- Spatial correlation coefficients
- Linear trends with significance tests
- Annual time series data tables

### Example Statistics Output

```
======================================================
Precipitation Statistics: TaiESM vs GPCP
======================================================
Analysis Period: 1980-1999

SPATIAL STATISTICS:
  Model global mean: 2.847 mm/day
  Observation global mean: 2.734 mm/day
  Bias (Model - Obs): +0.113 mm/day
  RMSE: 0.856 mm/day
  Spatial correlation: 0.924

TIME SERIES STATISTICS:
  Model trend: +0.0127 mm/day/decade (p=0.234)
  Observation trend: +0.0098 mm/day/decade (p=0.412)
======================================================
```

---

## Advanced Topics

### Custom Color Schemes

Modify color palettes in plotting sections:

```ncl
; Use custom colormap
gsn_define_colormap(wks, "BlueWhiteOrangeRed")

; Or specify exact colors
res@cnFillColors = (/2, 20, 40, 60, 80, 100/)
```

### Grid Handling

Scripts automatically detect and handle:
- 1D rectilinear grids (`lat`, `lon`)
- 2D curvilinear grids (`TLAT`, `TLONG`)
- Tripolar ocean grids (with special pole treatment)

### Memory Optimization

For large datasets, use NCL's chunking capabilities:

```ncl
; Read data in chunks
setfileoption("nc", "Format", "NetCDF4")
setfileoption("nc", "CompressionLevel", 1)
```

---

## Troubleshooting

### Common Issues

#### Issue 1: File Not Found
```
ERROR: No model files found for period 1980-1999
```
**Solution:** Verify file paths and naming conventions in configuration section.

#### Issue 2: Memory Error
```
fatal:Number of elements does not match dimensions
```
**Solution:** Check data dimensions and ensure coordinate variables are properly assigned.

#### Issue 3: Missing Values in Output
```
WARNING: All values missing in regridded field
```
**Solution:** Verify grid coordinate ranges and regridding method. Try conservative remapping for irregular grids.

### Debug Mode

Enable verbose output:
```ncl
; Add at beginning of script
print_clock("Start time")
```

### Contact & Support

For issues specific to these scripts:
- Open an issue on GitHub
- Check NCL documentation: https://www.ncl.ucar.edu/
- NCL community forum: https://www.ncl.ucar.edu/support.shtml

---

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/new-diagnostic`)
3. **Commit changes** (`git commit -am 'Add new diagnostic script'`)
4. **Push to branch** (`git push origin feature/new-diagnostic`)
5. **Open a Pull Request**

### Code Standards

- Use clear variable names
- Add comments for complex algorithms
- Include configuration section at top of scripts
- Test with sample datasets before submitting
- Update documentation for new features

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Citation

If you use these scripts in your research, please cite:

```bibtex
@software{taiESM_diagnostics,
  title = {Climate Model Diagnostics for TaiESM},
  author = {[Your Name/Team]},
  year = {2025},
  url = {https://github.com/yourusername/TaiESM-TIMCOM-Diags}
}
```

---

## Acknowledgments

- NCAR Command Language (NCL) development team
- CESM/CICE model developers
- Observational data providers:
  - NOAA/NSIDC Climate Data Record
  - GPCP (Global Precipitation Climatology Project)
  - Berkeley Earth Surface Temperature
  - HadISST (Hadley Centre Sea Ice and SST)

---

## Change Log

### Version 1.0.0 (2025-01-14)
- Initial release
- Four core diagnostic scripts
- Comprehensive documentation
- Example outputs

---

**Last Updated:** October 2025  
**Repository:** https://github.com/saberio13/TaiESM-TIMCOM-Diags  
**Documentation:** https://saberio13.github.io/TaiESM-TIMCOM-Diags
