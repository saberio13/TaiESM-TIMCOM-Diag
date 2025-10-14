# Quick Start Guide

Get started with the Climate Model Diagnostics scripts in 5 minutes!

## Prerequisites

- NCL 6.6.2 or higher installed
- Climate model output files
- Observational datasets

## Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/climate-model-diagnostics.git
cd climate-model-diagnostics
```

## Step 2: Organize Your Data

Expected directory structure:
```
/your/data/path/
├── MOD/                    # Model output
│   └── YourModel/
│       ├── ice/hist/       # Sea ice files
│       ├── atm/hist/       # Atmosphere files
│       └── ocn/hist/       # Ocean files
└── OBS/                    # Observations
    └── OBS/
        ├── seaice_conc_*.nc
        ├── gpcp.*.nc
        ├── best.tas.*.nc
        └── hadisst.sst.*.nc
```

## Step 3: Configure a Script

Edit `scripts/diag_precipitation.ncl`:

```ncl
;-----------------------------------------------------------------------
; USER SETTINGS - EDIT THESE PARAMETERS
;-----------------------------------------------------------------------
model_dir   = "/path/to/your/MOD/model_name/atm/hist/"
model_prefix = "model_name.cam.h0."

obs_file    = "/path/to/your/OBS/OBS/gpcp.mon.mean.197901-201904.nc"

year_start  = 1980
year_end    = 1999

output_dir  = "./output/"
```

## Step 4: Run the Script

```bash
# Create output directory
mkdir -p output

# Run the diagnostic
ncl scripts/diag_precipitation.ncl
```

## Step 5: Check Results

Your output will be in the `output/` directory:

```bash
ls output/
# precipitation_spatial_1980-1999.png
# precipitation_timeseries_1980-1999.png
# precipitation_statistics_1980-1999.txt
```

View the statistics:
```bash
cat output/precipitation_statistics_1980-1999.txt
```

## Example Output

### Statistics File
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
```

### Visualization
![Example Plot](examples/figures/precipitation_spatial_example.png)

## Run All Diagnostics

Create a batch script:

```bash
#!/bin/bash
# run_all.sh

echo "Running all diagnostics..."

# Sea ice
ncl scripts/diag_ice.ncl

# Precipitation
ncl scripts/diag_precipitation.ncl

# Surface air temperature
ncl scripts/diag_SAT.ncl

# Sea surface temperature
ncl scripts/diag_SST.ncl

echo "Complete! Check ./output/ for results"
```

Make it executable and run:
```bash
chmod +x run_all.sh
./run_all.sh
```

## Common First-Time Issues

### Issue: "File not found"
**Fix:** Double-check paths in configuration section

### Issue: "Variable not in file"
**Fix:** Use `ncdump -h yourfile.nc` to see available variables

### Issue: Script runs but no output
**Fix:** Check `output_dir` exists and has write permissions

## Next Steps

1. **Customize plots:** Modify color schemes and labels
2. **Change time period:** Adjust `year_start` and `year_end`
3. **Compare multiple models:** Run scripts for different model outputs
4. **Read detailed docs:** See `docs/SCRIPT_DETAILS.md` for in-depth explanations

## Getting Help

- **Documentation:** See `README.md` and `docs/` folder
- **Troubleshooting:** Check `docs/troubleshooting.md`
- **NCL Help:** https://www.ncl.ucar.edu/support.shtml

---

**Ready to dive deeper?** Read the full [README.md](../README.md) for comprehensive documentation.
