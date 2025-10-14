# Detailed Script Documentation

This document provides in-depth technical explanations for each diagnostic script, including critical code sections, algorithms, and important implementation details.

---

## Table of Contents

1. [Sea Ice Concentration Analysis - Detailed](#sea-ice-concentration-analysis-detailed)
2. [Precipitation Analysis - Detailed](#precipitation-analysis-detailed)
3. [Surface Air Temperature Analysis - Detailed](#surface-air-temperature-analysis-detailed)
4. [Sea Surface Temperature Analysis - Detailed](#sea-surface-temperature-analysis-detailed)

---

## Sea Ice Concentration Analysis - Detailed

**Script:** `diag_ice.ncl`

### Process Flow

```
1. Configuration & Setup
   ↓
2. Load Model Grid & Data
   ↓
3. Handle NaN Values & Pole Hole
   ↓
4. Calculate Sea Ice Area (SIA)
   ↓
5. Load & Process Observations
   ↓
6. Calculate Climatology
   ↓
7. Statistical Analysis
   ↓
8. Generate Visualizations
```

### Critical Code Sections

#### 1. NaN Handling in Grid Coordinates

**Purpose:** CICE grid files often contain NaN values at land points or grid boundaries, which must be filled to enable proper plotting and calculation.

**Code Location:** Lines 85-126

```ncl
; Linear interpolation to fill NaN values
nan_lat = num(ismissing(tlat))
if (nan_lat .gt. 0) then
    print("  Filling " + nan_lat + " NaN in latitude...")
    tlat = linmsg(tlat, 0)  ; Fill with linear interpolation
    
    ; Secondary pass: nearest neighbor for remaining NaNs
    if (any(ismissing(tlat))) then
        do i = 0, nj-1
            do j = 0, ni-1
                if (ismissing(tlat(i,j))) then
                    if (i .gt. 0 .and. .not. ismissing(tlat(i-1,j))) then
                        tlat(i,j) = tlat(i-1,j)  ; Copy from adjacent cell
                    else if (j .gt. 0 .and. .not. ismissing(tlat(i,j-1))) then
                        tlat(i,j) = tlat(i,j-1)
                    end if
                    end if
                end if
            end do
        end do
    end if
end if
```

**Why Critical:** Without proper handling, NaN values cause:
- Gaps in spatial plots (white areas)
- Incorrect area calculations
- Plotting function failures

**Algorithm:**
1. Count missing values using `ismissing()`
2. Apply linear interpolation (`linmsg`) as first pass
3. Use nearest-neighbor filling for remaining gaps
4. Iterate through grid to ensure complete coverage

---

#### 2. Pole Hole Treatment

**Purpose:** Arctic sea ice data has a "pole hole" (data gap near North Pole ~84°N+) due to satellite orbit limitations. This must be filled for accurate SIA calculations.

**Code Location:** Lines 127-155

```ncl
; Identify pole hole region
mask_pole = where(tlat .ge. 84.0, 1, 0)
print("  Pole hole points: " + num(mask_pole .eq. 1))

; Fill pole hole with 100% ice concentration
if (num(mask_pole .eq. 1 .and. ismissing(aice_tmp)) .gt. 0) then
    aice_tmp = where(mask_pole .eq. 1 .and. ismissing(aice_tmp), \
                    100.0, aice_tmp)
end if
```

**Scientific Rationale:**
- Satellite coverage limitation above ~84°N
- Region is consistently ice-covered (climatologically >95%)
- Standard practice: assume 100% concentration for SIA calculations

**Impact on Results:** Typically adds 0.4-0.6 × 10¹² m² to Arctic SIA

---

#### 3. Sea Ice Area Calculation Function

**Purpose:** Calculate hemispheric sea ice area using 15% concentration threshold (standard metric).

**Code Location:** Lines 38-54

```ncl
function calculate_sia(aice[*][*]:numeric, tarea[*][*]:numeric, \
                       lat[*][*]:numeric, hemisphere:string, threshold:numeric)
local sia, mask, aice_masked
begin
    ; Create hemispheric mask
    if (hemisphere .eq. "NH") then
        mask = where(lat .gt. 0, 1, 0)  ; Northern Hemisphere
    else
        mask = where(lat .lt. 0, 1, 0)  ; Southern Hemisphere
    end if
    
    ; Apply threshold: cells with ≥15% concentration count as ice-covered
    aice_masked = where(aice .ge. threshold, 1.0, 0.0)
    
    ; Apply hemispheric mask
    aice_masked = aice_masked * mask
    
    ; Sum areas of ice-covered cells
    sia = sum(aice_masked * tarea)
    
    return(sia)
end
```

**Algorithm Details:**
- **Threshold (15%):** NSIDC standard definition
- **Binary mask:** Convert concentration to 0 (no ice) or 1 (ice present)
- **Area weighting:** Multiply by grid cell area (`tarea`)
- **Units:** Result in m² (typically reported as 10¹² m²)

**Key Variables:**
- `aice`: Ice concentration (0-100%)
- `tarea`: Grid cell area (m²)
- `lat`: Latitude coordinate
- `threshold`: Concentration threshold (15.0%)

---

#### 4. Data Quality Control

**Purpose:** Remove invalid or unphysical values from ice concentration data.

**Code Location:** Lines 147-157

```ncl
FillValue = aice_tmp@_FillValue

; Set invalid values to FillValue
aice_tmp = where(aice_tmp .eq. 0, FillValue, aice_tmp)        ; Land points
aice_tmp = where(aice_tmp .gt. 100, FillValue, aice_tmp)      ; Unphysical high
aice_tmp = where(aice_tmp .lt. 0, FillValue, aice_tmp)        ; Unphysical low

; Fill remaining missing values with zero (open ocean)
aice_tmp = where(ismissing(aice_tmp), 0.0, aice_tmp)
```

**Quality Checks:**
1. **Zero concentration:** Often indicates land mask, set to missing
2. **Values > 100%:** Unphysical, likely data corruption
3. **Negative values:** Invalid, set to missing
4. **Final gap fill:** Remaining missing values treated as ice-free ocean

---

#### 5. Observation Time Selection

**Purpose:** Extract correct time period from observational dataset using calendar functions.

**Code Location:** Lines 244-254

```ncl
time_units = "days since 1601-01-01 00:00:00"

; Convert years to time coordinate
time_start_obs = cd_inv_calendar(climo_year_start, 1, 1, 0, 0, 0, time_units, 0)
time_end_obs = cd_inv_calendar(climo_year_end, 12, 31, 23, 59, 59, time_units, 0)

; Find indices matching time range
idx_s = ind(time_obs .ge. time_start_obs)
idx_e = ind(time_obs .le. time_end_obs)

time_idx_start = idx_s(0)
time_idx_end = idx_e(dimsizes(idx_e) - 1)
```

**Important Notes:**
- **Time units:** NOAA CDR uses "days since 1601-01-01"
- **`cd_inv_calendar`:** Converts calendar date to numeric time value
- **Index extraction:** Ensures exact period match with model data

---

#### 6. Spatial Plot Enhancement

**Purpose:** Create high-quality polar projection maps with smooth color transitions.

**Code Location:** Lines 392-438

```ncl
res@cnFillMode = "RasterFill"
res@cnRasterSmoothingOn = True  ; CRITICAL: Smooths raster edges

; Remove small values to avoid white gaps
aice_mean = where(aice_mean .lt. 0.1, aice_mean@_FillValue, aice_mean)

res@mpMinLatF = 40              ; Show from 40°N northward
res@gsnPolar = "NH"             ; Northern Hemisphere polar projection
res@trGridType = "TriangularMesh"  ; Handle irregular grid
```

**Plotting Optimizations:**
- **RasterFill:** Faster than cell fill, better for large datasets
- **RasterSmoothing:** Eliminates blocky appearance
- **Minimum value filter:** Prevents white gaps at ice edges
- **TriangularMesh:** Properly handles curvilinear CICE grid

---

### Statistical Metrics

#### Bias Calculation
```ncl
bias_nh = avg(sia_annual_nh_model - sia_annual_nh_obs)
```
Measures systematic over/underestimation. Positive = model too much ice.

#### RMSE (Root Mean Square Error)
```ncl
rmse_nh = sqrt(avg((sia_annual_nh_model - sia_annual_nh_obs)^2))
```
Quantifies average magnitude of errors. Units: 10¹² m²

#### Temporal Correlation
```ncl
corr_nh = escorc(sia_annual_nh_model, sia_annual_nh_obs)
```
Measures year-to-year variability agreement. Range: -1 to 1.

---

### Performance Considerations

**Memory Usage:**
- Full dataset: ~2GB for 27 years × 12 months × 384 × 320 grid
- Peak memory: ~4GB during spatial averaging

**Processing Time:**
- Typical runtime: 3-5 minutes for 27-year period
- Bottleneck: File I/O (324 monthly files)

**Optimization Tips:**
```ncl
; Read every Nth month for debugging
if (mod(time_counter, 60) .eq. 0) then
    print("    Month " + time_counter)  ; Progress indicator
end if
```

---

## Precipitation Analysis - Detailed

**Script:** `diag_precipitation.ncl`

### Process Flow

```
1. Configuration
   ↓
2. Load Model Data (PRECC + PRECL)
   ↓
3. Unit Conversion (m/s → mm/day)
   ↓
4. Load Observation Data (GPCP)
   ↓
5. Latitude Orientation Check
   ↓
6. Regrid Model to Obs Grid
   ↓
7. Calculate Climatology & Differences
   ↓
8. Global Mean Time Series
   ↓
9. Statistical Analysis
   ↓
10. Visualization & Output
```

### Critical Code Sections

#### 1. Precipitation Component Combination

**Purpose:** CAM outputs precipitation as two components that must be summed.

**Code Location:** Lines 71-98

```ncl
; Read convective precipitation
if (isfilevar(fin_model[0], "PRECC")) then
    precc = fin_model[:]->PRECC
else
    print("ERROR: PRECC variable not found")
    exit
end if

; Read large-scale precipitation
if (isfilevar(fin_model[0], "PRECL")) then
    precl = fin_model[:]->PRECL
else
    print("ERROR: PRECL variable not found")
    exit
end if

; Calculate total precipitation
model_precip_raw = precc + precl
copy_VarAtts(precc, model_precip_raw)
```

**Scientific Background:**
- **PRECC:** Convective precipitation (thunderstorms, cumulus)
- **PRECL:** Large-scale/stratiform precipitation (fronts, light rain)
- **Total:** PRECC + PRECL = complete precipitation field

**Error Handling:** Script exits if either component is missing (both required).

---

#### 2. Unit Conversion

**Purpose:** Convert model output from m/s (SI units) to mm/day (standard climatology units).

**Code Location:** Lines 103-108

```ncl
; Convert m/s to mm/day
model_precip = model_precip_raw * 86400.0 * 1000.0
model_precip@units = "mm/day"
```

**Conversion Factor Breakdown:**
- **86400:** seconds per day (60 × 60 × 24)
- **1000:** meters to millimeters
- **Combined:** m/s × 86400 × 1000 = mm/day

**Example:**
- Model output: 3.0 × 10⁻⁵ m/s
- Converted: 3.0 × 10⁻⁵ × 86400 × 1000 = 2.59 mm/day

---

#### 3. Adaptive Grid Coordinate Handling

**Purpose:** Scripts handle both rectilinear and curvilinear grids automatically.

**Code Location:** Lines 113-133

```ncl
use_2d_coords = False

; Check for 2D curvilinear coordinates
if (isfilevar(fin_model[0], "TLONG") .and. isfilevar(fin_model[0], "TLAT")) then
    print("Found 2D coordinates (TLONG, TLAT)")
    model_lon_2d = fin_model[0]->TLONG
    model_lat_2d = fin_model[0]->TLAT
    use_2d_coords = True
    
; Check for 1D rectilinear coordinates  
else if (isfilevar(fin_model[0], "lon") .and. isfilevar(fin_model[0], "lat")) then
    print("Using 1D coordinates (lon, lat)")
    model_lon_1d = fin_model[0]->lon
    model_lat_1d = fin_model[0]->lat
    use_2d_coords = False
    
else
    print("ERROR: Could not find appropriate coordinate variables")
    exit
end if
end if
```

**Grid Types:**
- **1D Rectilinear:** CAM (lat, lon separate arrays)
- **2D Curvilinear:** POP/CICE ocean models (TLAT, TLONG as 2D arrays)

**Flexibility:** Enables script reuse across different model components.

---

#### 4. Latitude Orientation Fix

**Purpose:** Ensure latitude increases monotonically (required for regridding).

**Code Location:** Lines 190-199

```ncl
; Check if latitude is decreasing (common in some datasets)
if (obs_lat_orig(0) .gt. obs_lat_orig(dimsizes(obs_lat_orig)-1)) then
    print("Reversing latitude dimension to be monotonically increasing...")
    obs_lat = obs_lat_orig(::-1)           ; Reverse latitude array
    obs_precip_raw = obs_precip_raw(:,::-1,:)  ; Reverse data dimension
    obs_precip_raw&lat = obs_lat           ; Reassign coordinate
else
    obs_lat = obs_lat_orig
end if
```

**Why Necessary:**
- NCL regridding functions require monotonically increasing coordinates
- Some datasets store latitude as 90°N → -90°S (decreasing)
- Reversal: `-90°S → 90°N` ensures compatibility

**Syntax Note:** `::-1` reverses array order in NCL.

---

#### 5. Bilinear Regridding

**Purpose:** Interpolate model data to observational grid for direct comparison.

**Code Location:** Lines 219-253 (see diag_precipitation.ncl view_range)

```ncl
; Perform bilinear interpolation
model_precip_regrid = linint2_Wrap(model_lon_1d, model_lat_1d, \
                                    model_precip, \
                                    True, \  ; Use missing value check
                                    obs_lon, obs_lat, 0)
```

**Regridding Method:**
- **linint2_Wrap:** Bilinear interpolation (fast, smooth)
- **Preserves:** Data attributes and metadata
- **Alternative methods:**
  - Conservative remapping: Better for mass conservation
  - Patch (bicubic): Smoother but slower

**Grid Compatibility:**
- Model: ~1° resolution (192×288 or similar)
- GPCP: 2.5° resolution (72×144)
- Direction: High → Low resolution (typical for obs comparison)

---

#### 6. Area-Weighted Global Mean

**Purpose:** Calculate globally representative average accounting for grid cell size variation.

**Code Location:** Lines 401-414

```ncl
; Calculate area weights (cosine of latitude)
rad = 4.0 * atan(1.0) / 180.0  ; Conversion factor to radians
clat = cos(obs_lat * rad)

; Calculate weighted global mean for each time step
do t = 0, ntimes_model-1
    model_global_ts(t) = wgt_areaave(model_precip_regrid(t,:,:), clat, 1.0, 0)
    obs_global_ts(t) = wgt_areaave(obs_precip(t,:,:), clat, 1.0, 0)
end do
```

**Weighting Rationale:**
- Grid cells at equator are larger than at poles
- Weight = cos(latitude) accounts for area variation
- Prevents polar over-weighting in simple average

**Mathematical Formula:**
```
Global Mean = Σ(value × cos(lat)) / Σ(cos(lat))
```

---

#### 7. Statistical Significance Testing

**Purpose:** Determine if observed trends are statistically significant.

**Code Location:** Lines 508-513

```ncl
; Calculate linear regression
rc_model = regline(years, model_annual)
rc_obs = regline(years, obs_annual)

; Get t-statistic and calculate p-value
df = nyears - 2  ; Degrees of freedom
tval_model = rc_model@tval
pval_model = (1 - betainc(df/(df+tval_model^2), df/2.0, 0.5)) * 2
```

**Statistical Test:**
- **Null hypothesis:** No trend (slope = 0)
- **Test statistic:** t-value from linear regression
- **P-value:** Probability of obtaining result if no trend exists
- **Significance level:** Typically p < 0.05 for 95% confidence

**Interpretation:**
- p < 0.05: Statistically significant trend
- p > 0.05: Trend not distinguishable from random variability

---

### Output Format Specifications

#### Statistics Text File Structure
```
======================================================
Precipitation Statistics: TaiESM vs GPCP
======================================================
Analysis Period: 1980-1999
Analysis Date: Tue Jan 14 10:25:30 UTC 2025
NCL Version: 6.6.2

SPATIAL STATISTICS (Time-averaged 1980-1999):
  Model global mean: 2.847 mm/day
  Observation global mean: 2.734 mm/day
  Bias (Model - Obs): +0.113 mm/day
  RMSE: 0.856 mm/day
  Spatial correlation: 0.924

TIME SERIES STATISTICS (Annual means):
  Model trend: +0.0127 mm/day/decade (p=0.234)
  Observation trend: +0.0098 mm/day/decade (p=0.412)

ANNUAL MEAN VALUES:
  Year    Model    Observation    Difference
  ----    -----    -----------    ----------
  1980    2.823       2.718         0.105
  1981    2.841       2.729         0.112
  ...
```

---

## Surface Air Temperature Analysis - Detailed

**Script:** `diag_SAT.ncl`

### Process Flow

```
1. Configuration
   ↓
2. Load Model TREFHT Data
   ↓
3. Load Berkeley Earth Observations
   ↓
4. Time Period Parsing (YYYYMM format)
   ↓
5. Longitude Conversion (−180:180 → 0:360)
   ↓
6. Regridding
   ↓
7. Calculate Climatology Maps
   ↓
8. Monthly Climatology for Anomaly
   ↓
9. Calculate Anomaly Time Series
   ↓
10. Weighted Global Mean
   ↓
11. Visualization
```

### Critical Code Sections

#### 1. Temperature Unit Conversion

**Purpose:** Convert Kelvin (model standard) to Celsius (conventional reporting).

**Code Location:** Lines 45-46

```ncl
; Read temperature and convert K to C
model_sat = fin_model[:]->$model_var$ - 273.15
model_sat@units = "degree C"
```

**Conversion:**
- **Kelvin to Celsius:** T(°C) = T(K) − 273.15
- **Why Celsius:** Standard for surface temperature reporting
- **Example:** 288.15 K = 15.0°C

---

#### 2. YYYYMM Time Format Parsing

**Purpose:** Berkeley Earth uses integer YYYYMM format requiring special handling.

**Code Location:** Lines 62-75

```ncl
; Parse time in YYYYMM format
time_obs = fin_obs->time
years_obs = toint(time_obs / 100)          ; Extract year
months_obs = toint(time_obs - years_obs * 100)  ; Extract month

; Find indices for analysis period
ind_start = ind(years_obs .eq. year_start .and. months_obs .eq. 1)
ind_end = ind(years_obs .eq. year_end .and. months_obs .eq. 12)
```

**Format Example:**
- Time value: 187001
- Year: 187001 / 100 = 1870
- Month: 187001 − (1870 × 100) = 1

**Index Selection:**
- Start: First January of start_year
- End: Last December of end_year

---

#### 3. Longitude Convention Conversion

**Purpose:** Convert longitude from meteorological (−180° to 180°) to standard NCL (0° to 360°).

**Code Location:** Lines 82-88

```ncl
; Convert obs lon from -180:180 to 0:360
obs_lon = where(obs_lon .lt. 0, obs_lon + 360, obs_lon)

; Sort by longitude (required after conversion)
lon_sort = dim_pqsort(obs_lon, 1)
obs_lon := obs_lon(lon_sort)
obs_sat := obs_sat_raw(:,:,lon_sort)
```

**Convention Differences:**
- **Meteorological:** −180° (180°W) to 180° (180°E)
- **NCL Standard:** 0° to 360° (wraps around Prime Meridian)

**Why Necessary:**
- NCL plotting functions expect 0°−360° range
- Regridding requires matching coordinate systems

**Sorting:** After conversion, longitude may be out of order. `dim_pqsort` returns indices for sorting.

---

#### 4. Monthly Climatology Calculation

**Purpose:** Calculate baseline climatology for each calendar month (12 values).

**Code Location:** Lines 179-192

```ncl
; Calculate climatology for each month (12 months)
model_sat_climo = new((/12, dimsizes(obs_lat), dimsizes(obs_lon)/), float)
obs_sat_climo = new((/12, dimsizes(obs_lat), dimsizes(obs_lon)/), float)

do m = 1, 12
    ; Find all indices for this month in climatology period
    ind_month = ind(months_array(ind_climo) .eq. m)
    if (.not. all(ismissing(ind_month))) then
        actual_indices = ind_climo(ind_month)
        model_sat_climo(m-1,:,:) = dim_avg_n(model_sat_regrid(actual_indices,:,:), 0)
        obs_sat_climo(m-1,:,:) = dim_avg_n(obs_sat(actual_indices,:,:), 0)
    end if
    delete(ind_month)
end do
```

**Algorithm:**
1. Create 12 separate climatological maps (one per month)
2. For each month, find all occurrences within baseline period
3. Average all January values, all February values, etc.
4. Result: Seasonal cycle preserved in climatology

**Purpose:** Removes seasonal cycle to highlight year-to-year changes.

---

#### 5. Anomaly Calculation

**Purpose:** Remove climatological seasonal cycle to isolate interannual variability.

**Code Location:** Lines 194-202

```ncl
; Calculate anomaly: subtract monthly climatology from each month
model_sat_anom = model_sat_regrid
obs_sat_anom = obs_sat

do t = 0, ntimes-1
    m = months_array(t)  ; Get month (1-12) for this timestep
    model_sat_anom(t,:,:) = model_sat_regrid(t,:,:) - model_sat_climo(m-1,:,:)
    obs_sat_anom(t,:,:) = obs_sat(t,:,:) - obs_sat_climo(m-1,:,:)
end do
```

**Mathematical Definition:**
```
Anomaly(year, month) = T(year, month) − Climatology(month)
```

**Example:**
- January 1950 temperature: 5.2°C
- January climatology (1951-1980): 4.8°C
- January 1950 anomaly: 5.2 − 4.8 = +0.4°C

**Scientific Importance:** Enables detection of warming/cooling trends independent of seasonal variations.

---

#### 6. Cosine Latitude Weighting

**Purpose:** Account for decreasing grid cell area toward poles in global average.

**Code Location:** Lines 213-227

```ncl
; Calculate area weights (cosine of latitude)
rad = 4.0 * atan(1.0) / 180.0  ; π/180 conversion factor
weights = cos(obs_lat * rad)

; Expand weights to match data dimensions
weights_2d = conform(model_sat_anom(0,:,:), weights, 0)

; Calculate weighted global mean for each timestep
do t = 0, ntimes-1
    model_ts_monthly(t) = wgt_areaave(model_sat_anom(t,:,:), weights, 1.0, 0)
    obs_ts_monthly(t) = wgt_areaave(obs_sat_anom(t,:,:), weights, 1.0, 0)
end do
```

**Weighting Formula:**
```
Weight(lat) = cos(lat × π/180)
```

**Area Calculation:**
- Area of grid cell ∝ cos(latitude)
- Equatorial cells: ~111 km × 111 km
- Polar cells: ~111 km × 0 km (at poles)

**Impact:** Without weighting, polar regions would be over-represented in global mean.

---

### Visualization Features

#### Time Series Customization

**Code Location:** Lines 326-363

```ncl
res_ts@tiMainString = "Global mean SAT (~S~o~N~C)"
res_ts@trYMinF = -1.0
res_ts@trYMaxF = 0.6
res_ts@tmYLTickSpacingF = 0.5
res_ts@tmXBTickSpacingF = 20  ; Tick every 20 years
```

**Plot Elements:**
- **Title:** Uses NCL special characters (~S~o~N~ = superscript degree)
- **Y-axis range:** Fixed for comparability across plots
- **Tick spacing:** Adaptive based on time period length
- **Legend:** Positioned in plot margin

---

## Sea Surface Temperature Analysis - Detailed

**Script:** `diag_SST.ncl`

### Process Flow

```
1. Configuration
   ↓
2. Load HadISST Observations
   ↓
3. Load Model SST (top ocean level)
   ↓
4. Load 3D Temperature Field
   ↓
5. Load Grid Topology (TOPO.nc)
   ↓
6. Regrid Observations to Model Grid
   ↓
7. Calculate SST Climatology
   ↓
8. Calculate Volume-Averaged Temperature
   ↓
9. Time Series Analysis
   ↓
10. Statistical Metrics & Trends
   ↓
11. Visualization
```

### Critical Code Sections

#### 1. Model Data File Naming Convention

**Purpose:** Ocean model uses year offset from arbitrary start date.

**Code Location:** Lines 71-85

```ncl
; Calculate year offset from model start
year_offset = start_year - model_start_year

; Generate list of files to read
nmonths = (end_year - start_year + 1) * 12
file_list = new(nmonths, string)

do iyr = 0, end_year - start_year
    year_code = sprinti("%04i", year_offset + iyr + 1)
    do imon = 1, 12
        month_code = sprinti("%02i", imon)
        idx = iyr * 12 + imon - 1
        file_list(idx) = model_dir + "DATA_" + year_code + month_code + ".nc"
    end do
end do
```

**File Naming Example:**
- Model start year: 1850 (calendar year 1 in model)
- Analysis start: 1900
- Year offset: 1900 − 1850 = 50
- File for Jan 1900: `DATA_005101.nc` (year 51, month 01)

**Important:** Model year ≠ calendar year. Must calculate offset.

---

#### 2. Grid Topology Loading

**Purpose:** Ocean models use separate file for permanent grid information.

**Code Location:** Lines 100-136

```ncl
if (fileexists(topo_file)) then
    f_topo = addfile(topo_file, "r")
    
    ; Read 1D lat/lon coordinates
    lat_model = f_topo->lat
    lon_model = f_topo->lon
    lev_c = f_topo->lev_c  ; Level centers
    lev_f = f_topo->lev_f  ; Level faces (interfaces)
    
    ; Add proper attributes for plotting
    if (.not. isatt(lat_model, "units")) then
        lat_model@units = "degrees_north"
    end if
    lat_model!0 = "latitude"
    lat_model&latitude = lat_model
```

**Grid Variables:**
- **lat, lon:** Horizontal coordinates
- **lev_c:** Depth at layer centers (for temperature)
- **lev_f:** Depth at layer faces (for volume calculation)

**Why Separate File:** Grid is constant, not repeated in every monthly output.

---

#### 3. SST Extraction from 3D Field

**Purpose:** SST is the temperature at the topmost ocean level.

**Code Location:** Lines 142-155

```ncl
do ifile = 0, nmonths - 1
    if (fileexists(file_list(ifile))) then
        f = addfile(file_list(ifile), "r")
        ; Read full 3D temperature field
        temp_3d(ifile,:,:,:) = f->temperature
        ; SST is top level (index 0)
        sst_model(ifile,:,:) = f->temperature(0,:,:)
        delete(f)
    end if
end do
```

**Array Dimensions:**
- `temp_3d`: (time, depth, lat, lon)
- `sst_model`: (time, lat, lon)
- **Level 0:** Surface layer

**Physical Context:**
- Level 0 depth: Typically 5-10m
- Represents bulk skin temperature
- Comparable to satellite SST retrievals

---

#### 4. Data Quality Masking

**Purpose:** Remove land, ice, and erroneous values.

**Code Location:** Lines 157-159

```ncl
; Mask land values and unphysical temperatures
sst_model = where(sst_model .lt. -5.0 .or. \        ; Below freezing (with margin)
                  sst_model .gt. 50.0 .or. \         ; Unphysically hot
                  abs(sst_model) .lt. 0.001, \       ; Zero (often land/ice)
                  sst_model@_FillValue, sst_model)
```

**Quality Criteria:**
- **Lower bound (−5°C):** Below typical seawater freezing point
- **Upper bound (50°C):** Physically impossible for ocean
- **Near-zero values:** Often indicate land mask or ice-covered regions

**Effect:** Ensures statistics computed only over valid ocean points.

---

#### 5. Observation Regridding and Masking

**Purpose:** Interpolate observations to model grid and apply same land mask.

**Code Location:** Lines 167-186

```ncl
; Regrid to model grid using bilinear interpolation
sst_obs = linint2_Wrap(lon_obs, lat_obs, sst_obs_full, \
                       True, lon_model, lat_model, 0)

; Apply model land mask to observations
do itime = 0, nmonths - 1
    sst_obs(itime,:,:) = where(ismissing(sst_model(itime,:,:)), \
                               sst_obs@_FillValue, \
                               sst_obs(itime,:,:))
end do
```

**Two-Step Process:**
1. **Regrid:** Interpolate obs from original to model grid
2. **Mask:** Set obs to missing wherever model has missing values

**Why Mask:** Ensures fair comparison only over valid ocean points.

---

#### 6. Volume-Averaged Temperature Calculation

**Purpose:** Calculate mean temperature of entire ocean volume (not just surface).

**Code Location:** Lines 233-311 (see diag_SST.ncl)

```ncl
; Calculate layer thicknesses from level faces
dz = new(nlev, double)
dz(0) = lev_f(1) - lev_f(0)
do k = 1, nlev-1
    dz(k) = lev_f(k+1) - lev_f(k)
end do

; Calculate volume for each cell
do imon = 0, nmonths - 1
    do k = 0, nlev - 1
        ; Volume = horizontal area × layer thickness
        vol_3d(imon,k,:,:) = area_2d * dz(k)
        
        ; Mask land/ice
        vol_3d(imon,k,:,:) = where(ismissing(temp_3d(imon,k,:,:)), \
                                    vol_3d@_FillValue, \
                                    vol_3d(imon,k,:,:))
    end do
    
    ; Volume-weighted mean temperature
    vol_avg_temp(imon) = sum(temp_3d(imon,:,:,:) * vol_3d(imon,:,:,:)) / \
                         sum(vol_3d(imon,:,:,:))
end do
```

**Algorithm Steps:**
1. Calculate layer thickness (dz) from level faces
2. Compute volume of each grid cell: Area × Thickness
3. Multiply temperature by volume
4. Sum all volumes and temperature×volume products
5. Divide: Σ(T×V) / Σ(V)

**Physical Interpretation:**
- Represents "bulk ocean temperature"
- Dominated by deep ocean (90% of volume below 1000m)
- Slower to change than SST
- Key metric for ocean heat content

---

#### 7. Trend Calculation with Significance

**Purpose:** Quantify and test statistical significance of temperature trends.

**Code Location:** Lines 339-348

```ncl
; Linear trends (using regline function)
x_time = ispan(0, nyears-1, 1) * 1.0

rc_model = regline(x_time, sst_model_annual)
rc_obs   = regline(x_time, sst_obs_annual)
rc_vol   = regline(x_time, vol_avg_annual)

trend_model = rc_model * 10.0  ; Convert to per decade
trend_obs   = rc_obs * 10.0
trend_vol   = rc_vol * 10.0
```

**Trend Units:**
- **Regression slope:** °C/year
- **Reported:** °C/decade (multiply by 10)
- **Example:** 0.013 °C/yr = 0.13 °C/decade

**Significance Testing:**
- `regline` automatically calculates t-statistic
- Access via: `rc_model@tval`
- P-value computed from t-distribution

---

### Advanced Features

#### Dynamic Time Axis Labeling

**Purpose:** Automatically adjust axis labels based on time period length.

**Code Location:** Lines 463-491

```ncl
nyears_plot = end_year - start_year + 1

if (nyears_plot .le. 30) then
    ; Show every year for short periods
    res_ts@tmXBValues = year_array
    res_ts@tmXBLabels = year_array
    res_ts@tmXBLabelAngleF = 45  ; Angled labels
    
else if (nyears_plot .le. 50) then
    ; Show every 5 years for medium periods
    year_stride = 5
    year_labels = ispan(start_year, end_year, year_stride)
    
else
    ; Show every 10 years for long periods
    year_stride = 10
    year_labels = ispan(start_year, end_year, year_stride)
end if
end if
```

**Logic:**
- **≤30 years:** Label every year (e.g., 1990-2020)
- **31-50 years:** Label every 5 years (e.g., 1970-2020)
- **>50 years:** Label every 10 years (e.g., 1870-1970)

**Prevents:** Overcrowded axis labels on long time series.

---

### Performance & Memory

**Memory Requirements:**
- Full 3D field: 12 months × 40 levels × 180 lat × 360 lon × 8 bytes = ~2.5 GB
- Peak usage: ~5 GB with intermediate arrays

**Optimization Strategies:**
1. Read 3D data only when volume-averaged temp needed
2. Delete large arrays after use: `delete(temp_3d)`
3. Use `double` precision for accumulated sums (prevents roundoff)

---

## General Best Practices Across All Scripts

### 1. Error Handling

Always check file existence before opening:
```ncl
if (.not. fileexists(filename)) then
    print("ERROR: File not found: " + filename)
    exit
end if
```

### 2. Memory Management

Delete large arrays when no longer needed:
```ncl
delete([/var1, var2, var3/])  ; Delete multiple variables
```

### 3. Progress Indicators

For long-running loops:
```ncl
if (mod(itime, 60) .eq. 0) then
    print("  Processed " + itime + " of " + ntimes + " timesteps")
end if
```

### 4. Unit Testing

Test with small datasets first:
```ncl
; Debug mode: process only first year
if (debug_mode) then
    end_year = start_year
end if
```

### 5. Coordinate Verification

Always verify coordinates after regridding:
```ncl
print("Output grid: " + dimsizes(data_regrid&lat) + " x " + dimsizes(data_regrid&lon))
print("Lat range: " + min(data_regrid&lat) + " to " + max(data_regrid&lat))
```

---

## Troubleshooting Decision Tree

```
Problem: Script fails
   ↓
   Check: File paths correct?
      ↓ No → Fix paths in configuration
      ↓ Yes
   Check: Files exist?
      ↓ No → Verify data availability
      ↓ Yes
   Check: Variable names correct?
      ↓ No → Use ncdump to inspect file
      ↓ Yes
   Check: Coordinates valid?
      ↓ No → Fix NaN/missing values
      ↓ Yes
   Check: Memory sufficient?
      ↓ No → Reduce time period or resolution
      ↓ Yes
   Check: NCL version compatible?
      ↓ No → Update NCL or modify syntax
      ↓ Yes
   → Consult NCL documentation or forums
```

---

**Document Version:** 1.0  
**Last Updated:** January 2025  
**Maintainer:** [Your Name/Team]
