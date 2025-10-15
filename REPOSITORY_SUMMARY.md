# Repository Summary - Climate Model Diagnostics

## Complete Package Contents

This repository contains everything needed to run comprehensive climate model diagnostics for the TaiESM (Taiwan Earth System Model).

---

## Directory Structure

```
climate-model-diagnostics/
├── README.md                           # Main documentation (16KB)
├── LICENSE                             # MIT License
├── .gitignore                         # Git ignore rules
│
├── scripts/                           # Main diagnostic scripts
│   ├── diag_ice.ncl                  # Sea ice concentration analysis (520 lines)
│   ├── diag_precipitation.ncl        # Precipitation comparison (588 lines)
│   ├── diag_SAT.ncl                  # Surface air temperature (409 lines)
│   └── diag_SST.ncl                  # Sea surface temperature (543 lines)
│
├── docs/                              # Detailed documentation
│   ├── SCRIPT_DETAILS.md             # In-depth technical docs (40KB)
│   ├── QUICKSTART.md                 # 5-minute getting started guide
│   ├── troubleshooting.md            # Common issues & solutions (14KB)
│   └── workflow_guide.md             # Workflows & best practices (12KB)
│
├── examples/                        
│   ├── figures                 
│   
│
└── .github/
    └── workflows/
        └── documentation.yml          # GitHub Actions workflow
```

---

## Script Capabilities Overview

### 1. Sea Ice Concentration Analysis (`diag_ice.ncl`)

**What It Does:**
- Analyzes sea ice concentration from CICE model output
- Calculates Sea Ice Area (SIA) for both hemispheres
- Compares against NOAA/NSIDC satellite observations
- Handles Arctic pole hole filling

**Key Features:**
- ✅ NaN handling in grid coordinates
- ✅ Pole hole treatment (>84°N)
- ✅ Hemispheric SIA calculation with 15% threshold
- ✅ Statistical metrics (bias, RMSE, correlation)
- ✅ Spatial maps for NH and SH
- ✅ Annual time series comparison

**Critical Code Sections:**
1. **Lines 85-126:** NaN filling in latitude/longitude coordinates
2. **Lines 127-155:** Pole hole identification and 100% ice filling
3. **Lines 38-54:** SIA calculation function with area weighting
4. **Lines 392-438:** High-quality polar projection plotting

**Typical Runtime:** 3-5 minutes for 27 years (1979-2005)

**Output Files:**
- `Figure10_Mean_SIC_1979-2005.png` - Spatial distribution
- `Figure11_Annual_SIA_1979-2005.png` - Time series
- Console statistics

---

### 2. Precipitation Analysis (`diag_precipitation.ncl`)

**What It Does:**
- Combines PRECC + PRECL for total precipitation
- Converts units from m/s to mm/day
- Regrids model output to GPCP observational grid
- Calculates trends with significance testing

**Key Features:**
- ✅ Automatic grid detection (1D/2D coordinates)
- ✅ Unit conversion (m/s → mm/day)
- ✅ Latitude orientation fixing
- ✅ Area-weighted global means
- ✅ Linear trend analysis
- ✅ Three-panel spatial comparison

**Critical Code Sections:**
1. **Lines 71-98:** Precipitation component combination
2. **Lines 103-108:** Unit conversion (86400 × 1000)
3. **Lines 113-133:** Adaptive coordinate handling
4. **Lines 190-199:** Latitude reversal for monotonicity
5. **Lines 401-414:** Cosine latitude weighting

**Typical Runtime:** 2-4 minutes for 20 years (1980-1999)

**Output Files:**
- `precipitation_spatial_1980-1999.png` - Model, Obs, Difference maps
- `precipitation_timeseries_1980-1999.png` - Annual means
- `precipitation_statistics_1980-1999.txt` - Comprehensive stats

---

### 3. Surface Air Temperature Analysis (`diag_SAT.ncl`)

**What It Does:**
- Evaluates surface air temperature from CAM
- Calculates temperature anomalies relative to baseline period
- Compares against Berkeley Earth observations
- Performs long-term historical analysis

**Key Features:**
- ✅ Kelvin to Celsius conversion
- ✅ YYYYMM time format parsing
- ✅ Longitude convention conversion (−180:180 → 0:360)
- ✅ Monthly climatology for anomaly calculation
- ✅ Weighted global mean time series
- ✅ Historical period analysis (1870-1970)

**Critical Code Sections:**
1. **Lines 45-46:** Temperature unit conversion (K → °C)
2. **Lines 62-75:** Time format parsing (YYYYMM integer)
3. **Lines 82-88:** Longitude conversion and sorting
4. **Lines 179-192:** Monthly climatology calculation
5. **Lines 194-202:** Anomaly calculation
6. **Lines 213-227:** Cosine latitude weighting

**Typical Runtime:** 5-8 minutes for 100 years (1870-1970)

**Output Files:**
- `temperature_spatial_1870-1970.png` - Climatology and difference
- `temperature_timeseries_1870-1970.png` - Anomaly time series
- `temperature_statistics_1870-1970.txt` - Statistics summary

---

### 4. Sea Surface Temperature Analysis (`diag_SST.ncl`)

**What It Does:**
- Analyzes ocean surface temperature from TIMCOM/POP
- Calculates volume-averaged ocean temperature
- Compares against HadISST observations
- Computes decadal trends

**Key Features:**
- ✅ Complex file naming with year offset
- ✅ Grid topology from separate TOPO.nc file
- ✅ SST extraction from 3D temperature field
- ✅ Volume-averaged temperature calculation
- ✅ Automatic land/ice masking
- ✅ Dynamic time axis labeling

**Critical Code Sections:**
1. **Lines 71-85:** File naming with model year offset
2. **Lines 100-136:** Grid topology loading from TOPO.nc
3. **Lines 142-155:** SST extraction (top ocean level)
4. **Lines 157-159:** Quality masking (−5°C to 50°C)
5. **Lines 233-311:** Volume-averaged temperature (depth integration)
6. **Lines 463-491:** Adaptive time axis labels

**Typical Runtime:** 10-15 minutes for 100 years (1870-1970)

**Output Files:**
- `TaiESM_HadISST_comparison_1870-1970_spatial.png` - SST patterns
- `TaiESM_HadISST_comparison_1870-1970_timeseries.png` - SST & volume-avg
- `TaiESM_HadISST_comparison_1870-1970_statistics.txt` - Full stats

---

## Critical Points & Algorithms

### Sea Ice Script
**Most Critical:** Pole hole treatment (Lines 127-155)
- **Why:** Arctic satellite data gaps >84°N must be filled
- **Method:** Assume 100% ice concentration in pole hole
- **Impact:** Adds ~0.5 × 10¹² m² to Arctic SIA
- **Validation:** Standard practice in sea ice community

### Precipitation Script
**Most Critical:** Unit conversion (Lines 103-108)
- **Why:** Model outputs m/s, observations use mm/day
- **Formula:** mm/day = m/s × 86400 × 1000
- **Verification:** Check global mean ~2.7 mm/day
- **Common error:** Forgetting conversion leads to 10⁵× error

### Temperature Script
**Most Critical:** Anomaly calculation (Lines 194-202)
- **Why:** Removes seasonal cycle to isolate trends
- **Method:** Subtract monthly climatology (12 values)
- **Baseline:** Typically 1951-1980 or 1961-1990
- **Interpretation:** Shows warming/cooling relative to baseline

### SST Script
**Most Critical:** Volume averaging (Lines 233-311)
- **Why:** Represents total ocean heat content
- **Method:** Integrate T × volume over all depths
- **Formula:** VAT = Σ(T × Area × dz) / Σ(Area × dz)
- **Physical meaning:** Bulk ocean temperature

---

## Configuration Quick Reference

### Standard Configuration Block (All Scripts)

```ncl
;=======================================================================
; USER SETTINGS - MODIFY THESE
;=======================================================================

; Time period
year_start = 1980
year_end = 2000

; Data directories
model_dir = "/path/to/model/output/"
obs_dir = "/path/to/observations/"
output_dir = "./output/"

; Plotting
plot_type = "png"  ; or "pdf", "ps"
```

### Script-Specific Settings

**Sea Ice:**
```ncl
climo_year_start = 1979
climo_year_end = 2005
sic_threshold = 15.0  ; Sea ice concentration threshold (%)
```

**Precipitation:**
```ncl
color_levels_precip = (/1.0, 12.0, 1.0/)  ; min, max, spacing
color_levels_diff = (/-3.0, 3.0, 0.2/)    ; for difference plots
```

**Temperature:**
```ncl
climo_year_start = 1951  ; Anomaly baseline
climo_year_end = 1980
```

**SST:**
```ncl
model_start_year = 1850  ; Model calendar reference
plot_model_spatial = True
```

---

## Workflow Recommendations

### Quick Validation (30 minutes)
1. Set time period: 1990-2000 (10 years)
2. Run precipitation script (fastest)
3. Check statistics file
4. Verify plots look reasonable
5. Run other scripts

### Comprehensive Analysis (2-3 hours)
1. Full historical period (1850-2005)
2. Run all four scripts
3. Generate summary report
4. Compare trends across variables
5. Document findings

### Production Run (overnight)
1. Multiple model ensemble members
2. Sensitivity tests (different baselines)
3. Regional analysis (modify scripts)
4. Generate publication figures
5. Archive results

---

## Getting Started (5 Steps)

### Step 1: Install NCL
```bash
conda create -n ncl_env -c conda-forge ncl
conda activate ncl_env
```

### Step 2: Clone Repository
```bash
git clone https://github.com/yourusername/climate-model-diagnostics.git
cd climate-model-diagnostics
```

### Step 3: Organize Data
```
/data/
├── MOD/YourModel/
│   ├── ice/hist/
│   ├── atm/hist/
│   └── ocn/hist/
└── OBS/OBS/
    └── [observation files]
```

### Step 4: Configure Script
Edit `scripts/diag_precipitation.ncl`:
```ncl
model_dir = "/data/MOD/YourModel/atm/hist/"
obs_dir = "/data/OBS/OBS/"
year_start = 1980
year_end = 1999
```

### Step 5: Run
```bash
mkdir output
ncl scripts/diag_precipitation.ncl
ls output/
```

---


##  Common Pitfalls

### Pitfall 1: Wrong File Paths
**Symptom:** "File not found" errors
**Solution:** Use absolute paths, verify with `ls`

### Pitfall 2: Unit Mismatches
**Symptom:** Unrealistic statistics (values too large/small)
**Solution:** Check unit conversions, verify against known values

### Pitfall 3: Grid Misalignment
**Symptom:** All missing values after regridding
**Solution:** Check coordinate ranges, ensure monotonicity

### Pitfall 4: Memory Issues
**Symptom:** Segmentation fault or killed process
**Solution:** Reduce time period, delete arrays, use chunking

### Pitfall 5: Incorrect Time Selection
**Symptom:** Wrong years processed or no data found
**Solution:** Print time arrays, verify time format (YYYYMM vs calendar)


## Customization Examples

### Change Plot Title
```ncl
res@tiMainString = "Your Custom Title Here"
```

### Add Regional Box
```ncl
; Define region
lat_min = 20.0
lat_max = 40.0
lon_min = -130.0
lon_max = -110.0

; Extract data
regional_data = data({lat_min:lat_max}, {lon_min:lon_max})
```

### Export Data for Python
```ncl
; Save as NetCDF
fout = addfile("processed_data.nc", "c")
fout->model_clim = model_clim
fout->obs_clim = obs_clim
```

### Change Baseline Period
```ncl
; Pre-industrial
climo_year_start = 1850
climo_year_end = 1900

; Recent past
climo_year_start = 1981
climo_year_end = 2010
```

---

## External Resources

### NCL Resources
- Main site: https://www.ncl.ucar.edu/
- Examples: https://www.ncl.ucar.edu/Applications/
- Functions: https://www.ncl.ucar.edu/Document/Functions/

### Climate Model Resources
- CESM: https://www.cesm.ucar.edu/
- CMIP: https://www.wcrp-climate.org/wgcm-cmip

### Observational Data
- NOAA/NSIDC: https://nsidc.org/data/
- GPCP: https://www.ncei.noaa.gov/products/global-precipitation-climatology-project
- Berkeley Earth: http://berkeleyearth.org/
- HadISST: https://www.metoffice.gov.uk/hadobs/hadisst/

---

##  Pre-Flight Checklist

Before running scripts:

- [ ] NCL installed and working (`ncl -V`)
- [ ] Data files available and accessible
- [ ] File paths configured in scripts
- [ ] Output directory exists and writable
- [ ] Sufficient disk space (>10GB for outputs)
- [ ] Time period valid for both model and obs
- [ ] Variable names verified (`ncdump -h file.nc`)

---

**Repository Version:** 1.0  
**Total Lines of Code:** ~2,060 lines (NCL scripts)  
**Total Documentation:** ~100KB (Markdown files)  
**Last Updated:** October 14, 2025

**Ready to analyze climate models!**
