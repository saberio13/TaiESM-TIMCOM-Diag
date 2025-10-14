;=======================================================================
; TaiESM TIMCOM vs GPCP Precipitation Comparison Script
;=======================================================================

begin

;-----------------------------------------------------------------------
; USER SETTINGS - EDIT THESE PARAMETERS
;-----------------------------------------------------------------------
; Model data settings
model_dir   = "/work/u5865217/HW1/MOD/BTHIST_test08a/atm/hist/"
model_prefix = "BTHIST_test08a.cam.h0."
model_var   = "PRECC"  ; Will also add PRECL for total precipitation

; Observational data settings
obs_file    = "/work/u5865217/HW1/OBS/OBS/gpcp.mon.mean.197901-201904.nc"
obs_var     = "precip"

; *** CHANGE THESE DATES FOR DIFFERENT ANALYSIS PERIOD ***
; Time period for analysis
; Note: GPCP available from 1979-2019, TaiESM model from 1850-1999
year_start  = 1980
year_end    = 1999

; Output settings
output_dir  = "./"
plot_type   = "png"

; Plotting options
color_levels_precip = (/1.0, 12.0, 1.0/)  ; min, max, spacing for precipitation
color_levels_diff = (/-3.0, 3.0, 0.2/)    ; min, max, spacing for difference

;-----------------------------------------------------------------------
; DERIVED SETTINGS (DO NOT EDIT)
;-----------------------------------------------------------------------
period_str  = year_start + "-" + year_end
stat_file   = output_dir + "precipitation_statistics_" + period_str + ".txt"
plot_spatial = output_dir + "precipitation_spatial_" + period_str
plot_ts = output_dir + "precipitation_timeseries_" + period_str

;-----------------------------------------------------------------------
; STEP 1: LOAD MODEL DATA WITH ADAPTIVE GRID HANDLING
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 1: Loading TaiESM model data...")
print("=======================================================")

; Build file list for the time period
files = systemfunc("ls " + model_dir + model_prefix + "{"+year_start+".."+year_end+"}*.nc")

; Check if files exist
if (all(ismissing(files))) then
    print("ERROR: No model files found for period " + period_str)
    print("Check directory: " + model_dir)
    exit
end if

nfiles = dimsizes(files)
print("Found " + nfiles + " model files for " + period_str)

; Read model data
fin_model = addfiles(files, "r")
ListSetType(fin_model, "cat")

; Read precipitation components with error checking
if (isfilevar(fin_model[0], "PRECC")) then
    precc = fin_model[:]->PRECC
    print("Successfully loaded PRECC")
else
    print("ERROR: PRECC variable not found in model files")
    exit
end if

if (isfilevar(fin_model[0], "PRECL")) then
    precl = fin_model[:]->PRECL
    print("Successfully loaded PRECL")
else
    print("ERROR: PRECL variable not found in model files")
    exit
end if

; Calculate total precipitation (PRECC + PRECL)
model_precip_raw = precc + precl
copy_VarAtts(precc, model_precip_raw)
model_precip_raw!0 = "time"
model_precip_raw!1 = "lat"
model_precip_raw!2 = "lon"
model_precip_raw&time = precc&time
model_precip_raw&lat = precc&lat
model_precip_raw&lon = precc&lon
model_precip_raw@long_name = "Total precipitation rate"
model_precip_raw@units = "m/s"

; Free memory
delete(precc)
delete(precl)

; Convert units from m/s to mm/day (multiply by 86400 * 1000)
model_precip = model_precip_raw * 86400.0 * 1000.0
copy_VarCoords(model_precip_raw, model_precip)
model_precip@units = "mm/day"
model_precip@long_name = "Total precipitation"
print("Converted precipitation units to mm/day")

; Free memory
delete(model_precip_raw)

; Check for grid coordinate variables (adaptive handling)
print("Checking for grid coordinate variables...")
use_2d_coords = False

if (isfilevar(fin_model[0], "TLONG") .and. isfilevar(fin_model[0], "TLAT")) then
    print("Found 2D coordinates (TLONG, TLAT)")
    model_lon_2d = fin_model[0]->TLONG
    model_lat_2d = fin_model[0]->TLAT
    use_2d_coords = True
else if (isfilevar(fin_model[0], "lon") .and. isfilevar(fin_model[0], "lat")) then
    print("Using 1D coordinates (lon, lat)")
    model_lon_1d = fin_model[0]->lon
    model_lat_1d = fin_model[0]->lat
    use_2d_coords = False
    print("Model grid: " + dimsizes(model_lat_1d) + " x " + dimsizes(model_lon_1d))
else
    print("ERROR: Could not find appropriate coordinate variables")
    exit
end if
end if

;-----------------------------------------------------------------------
; STEP 2: LOAD OBSERVATIONAL DATA
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 2: Loading GPCP observational data...")
print("=======================================================")

; Check if observation file exists
if (.not. fileexists(obs_file)) then
    print("ERROR: Observation file not found: " + obs_file)
    exit
end if

fin_obs = addfile(obs_file, "r")

; Read time and find indices for analysis period
time_obs = fin_obs->time
time_units = time_obs@units

; Convert time to dates
date_obs = cd_calendar(time_obs, 0)
years_obs = toint(date_obs(:,0))

print("Observation data covers: " + min(years_obs) + " to " + max(years_obs))

; Find time indices for the analysis period
ind_start = ind(years_obs .eq. year_start .and. toint(date_obs(:,1)) .eq. 1)
ind_end = ind(years_obs .eq. year_end .and. toint(date_obs(:,1)) .eq. 12)

; Check if indices are valid
if (ismissing(ind_start(0))) then
    print("ERROR: Start year " + year_start + " not found in observation data")
    print("Available years: " + min(years_obs) + " to " + max(years_obs))
    exit
end if

if (ismissing(ind_end(0))) then
    print("ERROR: End year " + year_end + " not found in observation data")
    print("Available years: " + min(years_obs) + " to " + max(years_obs))
    exit
end if

; Use scalar indices
ind_start = ind_start(0)
ind_end = ind_end(0)

print("Using observation time range: " + years_obs(ind_start) + " to " + years_obs(ind_end))
print("Total months: " + (ind_end - ind_start + 1))

; Read observational precipitation for the period
obs_precip_raw = fin_obs->$obs_var$(ind_start:ind_end,:,:)
obs_lat_orig = fin_obs->lat
obs_lon = fin_obs->lon

print("Observation grid: " + dimsizes(obs_lat_orig) + " x " + dimsizes(obs_lon))

; Check if latitude is decreasing and reverse if necessary
if (obs_lat_orig(0) .gt. obs_lat_orig(dimsizes(obs_lat_orig)-1)) then
    print("Reversing latitude dimension to be monotonically increasing...")
    obs_lat = obs_lat_orig(::-1)
    obs_precip_raw = obs_precip_raw(:,::-1,:)
    obs_precip_raw!1 = "lat"
    obs_precip_raw&lat = obs_lat
else
    obs_lat = obs_lat_orig
end if

print("Latitude range: " + sprintf("%6.2f", min(obs_lat)) + " to " + sprintf("%6.2f", max(obs_lat)))
print("Longitude range: " + sprintf("%6.2f", min(obs_lon)) + " to " + sprintf("%6.2f", max(obs_lon)))

; GPCP data is already in mm/day, no conversion needed
obs_precip = obs_precip_raw
obs_precip@units = "mm/day"
print("GPCP data already in mm/day units")

; Free memory
delete(obs_precip_raw)

;-----------------------------------------------------------------------
; STEP 3: REGRIDDING TO COMMON GRID
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 3: Regridding model data to observational grid...")
print("=======================================================")

if (use_2d_coords) then
    ; For 2D coordinates, use ESMF regridding
    print("Regridding from 2D curvilinear to rectilinear grid...")
    Opt = True
    Opt@SrcFileName = "source_grid.nc"
    Opt@DstFileName = "dest_grid.nc"
    Opt@WgtFileName = "weights.nc"
    Opt@ForceOverwrite = True
    Opt@InterpMethod = "bilinear"
    Opt@SrcRegional = False
    Opt@DstRegional = False
    Opt@SrcGridLat = model_lat_2d
    Opt@SrcGridLon = model_lon_2d
    Opt@DstGridLat = obs_lat
    Opt@DstGridLon = obs_lon
    
    ; Regrid each time step
    ntimes = dimsizes(model_precip&time)
    nlat_out = dimsizes(obs_lat)
    nlon_out = dimsizes(obs_lon)
    model_precip_regrid = new((/ntimes, nlat_out, nlon_out/), typeof(model_precip))
    
    print("Regridding " + ntimes + " time steps...")
    do t = 0, ntimes-1
        if (t % 12 .eq. 0) then
            print("  Processing time step " + t + "/" + ntimes)
        end if
        model_precip_regrid(t,:,:) = ESMF_regrid(model_precip(t,:,:), Opt)
    end do
    
else
    ; For 1D coordinates, use linint2 for simpler regridding
    print("Regridding from rectilinear to rectilinear grid...")
    print("Model longitude range: " + sprintf("%6.2f", min(model_lon_1d)) + " to " + sprintf("%6.2f", max(model_lon_1d)))
    
    ; Check if model latitude is monotonically increasing
    if (model_lat_1d(0) .gt. model_lat_1d(dimsizes(model_lat_1d)-1)) then
        print("Reversing model latitude to be monotonically increasing...")
        model_lat_1d_sorted = model_lat_1d(::-1)
        model_precip_sorted = model_precip(:,::-1,:)
        model_precip_regrid = linint2_Wrap(model_lon_1d, model_lat_1d_sorted, model_precip_sorted, \
                                            True, obs_lon, obs_lat, 0)
        delete(model_lat_1d_sorted)
        delete(model_precip_sorted)
    else
        model_precip_regrid = linint2_Wrap(model_lon_1d, model_lat_1d, model_precip, \
                                            True, obs_lon, obs_lat, 0)
    end if
end if

; Assign coordinates explicitly
model_precip_regrid!0 = "time"
model_precip_regrid!1 = "lat"
model_precip_regrid!2 = "lon"
model_precip_regrid&time = model_precip&time
model_precip_regrid&lat = obs_lat
model_precip_regrid&lon = obs_lon
model_precip_regrid@units = "mm/day"
model_precip_regrid@long_name = "Regridded model precipitation"

print("Regridding complete")

; Free memory
delete(model_precip)

;-----------------------------------------------------------------------
; STEP 4: CALCULATE TIME-AVERAGED FIELDS
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 4: Calculating time-averaged fields...")
print("=======================================================")

; Calculate annual mean for model and observations
model_ann_mean = dim_avg_n_Wrap(model_precip_regrid, 0)
obs_ann_mean = dim_avg_n_Wrap(obs_precip, 0)

; Calculate difference
diff_ann_mean = model_ann_mean - obs_ann_mean
copy_VarCoords(model_ann_mean, diff_ann_mean)
diff_ann_mean@long_name = "Model - Observation difference"
diff_ann_mean@units = "mm/day"

print("Time averaging complete")
print("Model annual mean range: " + sprintf("%6.2f", min(model_ann_mean)) + " to " + sprintf("%6.2f", max(model_ann_mean)) + " mm/day")
print("Obs annual mean range: " + sprintf("%6.2f", min(obs_ann_mean)) + " to " + sprintf("%6.2f", max(obs_ann_mean)) + " mm/day")

;-----------------------------------------------------------------------
; STEP 5: CREATE SPATIAL DISTRIBUTION PLOTS
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 5: Creating spatial distribution plots...")
print("=======================================================")

wks = gsn_open_wks(plot_type, plot_spatial)

; Set common resources for all plots
res = True
res@gsnMaximize = False
res@gsnDraw = False
res@gsnFrame = False
res@cnFillOn = True
res@cnLinesOn = False
res@cnLineLabelsOn = False
res@lbLabelBarOn = True
res@lbOrientation = "Horizontal"
res@lbLabelFontHeightF = 0.012
res@mpFillOn = False
res@mpOutlineOn = True
res@mpGeophysicalLineThicknessF = 0.5
res@gsnAddCyclic = True
res@cnLevelSelectionMode = "ManualLevels"
res@gsnLeftString = ""
res@gsnRightString = ""
res@tiMainFontHeightF = 0.018
res@mpCenterLonF = 180.0  ; Center map on Pacific

; Calculate mean values for titles
model_mean_title = avg(model_ann_mean)
obs_mean_title = avg(obs_ann_mean)
diff_mean_title = avg(diff_ann_mean)

; Calculate RMSD
diff_squared = (model_ann_mean - obs_ann_mean)^2
rmsd_title = sqrt(avg(diff_squared))

print("Global statistics:")
print("  Model mean: " + sprintf("%6.2f", model_mean_title) + " mm/day")
print("  Obs mean: " + sprintf("%6.2f", obs_mean_title) + " mm/day")
print("  Bias: " + sprintf("%6.2f", diff_mean_title) + " mm/day")
print("  RMSD: " + sprintf("%6.2f", rmsd_title) + " mm/day")

; Model plot
res@cnMinLevelValF = color_levels_precip(0)
res@cnMaxLevelValF = color_levels_precip(1)
res@cnLevelSpacingF = color_levels_precip(2)
res@tiMainString = "Precipitation, TaiESM (mm d~S~-1~N~)          Mean = " + sprintf("%4.2f", model_mean_title)
res@lbTitleString = "mm d~S~-1~N~"
res@lbTitleFontHeightF = 0.012
res@lbTitlePosition = "Right"
res@cnFillPalette = "WhiteBlueGreenYellowRed"
plot1 = gsn_csm_contour_map(wks, model_ann_mean, res)

; Observation plot
res@tiMainString = "Precipitation, GPCP (mm d~S~-1~N~)          Mean = " + sprintf("%4.2f", obs_mean_title)
plot2 = gsn_csm_contour_map(wks, obs_ann_mean, res)

; Difference plot
delete(res@cnMinLevelValF)
delete(res@cnMaxLevelValF)
delete(res@cnLevelSpacingF)
delete(res@cnFillPalette)
res@cnLevelSelectionMode = "ManualLevels"
res@cnMinLevelValF = color_levels_diff(0)
res@cnMaxLevelValF = color_levels_diff(1)
res@cnLevelSpacingF = color_levels_diff(2)
res@tiMainString = "Precipitation, TaiESM - GPCP (mm d~S~-1~N~)          Mean = " + \
                   sprintf("%4.2f", diff_mean_title) + " , RMSD = " + sprintf("%4.2f", rmsd_title)

; Use brown-white-blue color scheme for differences
res@cnFillPalette = "CBR_drywet"
plot3 = gsn_csm_contour_map(wks, diff_ann_mean, res)

; Panel plots with automatic labels
pres = True
pres@gsnMaximize = True
pres@gsnPanelLabelBar = False
pres@gsnPanelYWhiteSpacePercent = 5
pres@gsnPanelXWhiteSpacePercent = 5
pres@gsnPanelFigureStrings = (/"(a)","(b)","(c)"/)
pres@gsnPanelFigureStringsFontHeightF = 0.014
pres@amJust = "TopLeft"
gsn_panel(wks, (/plot1, plot2, plot3/), (/3,1/), pres)

print("Spatial plots created: " + plot_spatial + "." + plot_type)

;-----------------------------------------------------------------------
; STEP 6: CALCULATE GLOBAL MEAN TIME SERIES
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 6: Calculating global mean time series...")
print("=======================================================")

; Calculate area weights (cosine of latitude)
rad = 4.0 * atan(1.0) / 180.0
clat = cos(obs_lat * rad)

; Calculate global means for each time step
ntimes_model = dimsizes(model_precip_regrid&time)
model_global_ts = new(ntimes_model, float)
obs_global_ts = new(ntimes_model, float)

do t = 0, ntimes_model-1
    ; Weight by latitude for area-averaging
    model_global_ts(t) = wgt_areaave(model_precip_regrid(t,:,:), clat, 1.0, 0)
    obs_global_ts(t) = wgt_areaave(obs_precip(t,:,:), clat, 1.0, 0)
end do

print("Monthly time series calculated")

; Calculate annual means from monthly data
nyears = year_end - year_start + 1
model_annual = new(nyears, float)
obs_annual = new(nyears, float)
years = ispan(year_start, year_end, 1)

; Get month and year arrays for the time period
months_in_period = toint(date_obs(ind_start:ind_end,1))
years_in_period = toint(date_obs(ind_start:ind_end,0))

do yr = 0, nyears-1
    ind_year = ind(years_in_period .eq. years(yr))
    if (.not. all(ismissing(ind_year))) then
        model_annual(yr) = avg(model_global_ts(ind_year))
        obs_annual(yr) = avg(obs_global_ts(ind_year))
    end if
    delete(ind_year)
end do

print("Annual means calculated")

;-----------------------------------------------------------------------
; STEP 7: CREATE TIME SERIES PLOT
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 7: Creating time series plot...")
print("=======================================================")

wks_ts = gsn_open_wks(plot_type, plot_ts)

; Time series resources
res_ts = True
res_ts@gsnMaximize = True
res_ts@gsnDraw = False
res_ts@gsnFrame = False
res_ts@xyLineThicknessF = 3.0
res_ts@xyDashPattern = 0
res_ts@tiMainString = "Global Mean Precipitation (" + period_str + ")"
res_ts@tiYAxisString = "Precipitation (mm/day)"
res_ts@tiXAxisString = "Year"
res_ts@trYMinF = min((/min(model_annual), min(obs_annual)/)) - 0.2
res_ts@trYMaxF = max((/max(model_annual), max(obs_annual)/)) + 0.2
res_ts@trXMinF = year_start
res_ts@trXMaxF = year_end
res_ts@tmXBMode = "Explicit"
res_ts@tmXBValues = ispan(year_start, year_end, 2)
res_ts@tmXBLabels = ispan(year_start, year_end, 2)

; Plot model
res_ts@xyLineColor = "blue"
res_ts@gsnLeftString = "TaiESM (blue), GPCP (red)"
plot_ts1 = gsn_csm_xy(wks_ts, years, model_annual, res_ts)

; Overlay observation
res_ts@xyLineColor = "red"
res_ts@gsnLeftString = ""
plot_ts2 = gsn_csm_xy(wks_ts, years, obs_annual, res_ts)

overlay(plot_ts1, plot_ts2)
draw(plot_ts1)
frame(wks_ts)

print("Time series plot created: " + plot_ts + "." + plot_type)

;-----------------------------------------------------------------------
; STEP 8: CALCULATE STATISTICAL METRICS
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 8: Calculating statistical metrics...")
print("=======================================================")

; Global mean values
model_mean = avg(model_ann_mean)
obs_mean = avg(obs_ann_mean)
bias = model_mean - obs_mean

; Calculate RMSE
rmse = sqrt(avg(diff_squared))

; Calculate correlation
r = escorc(ndtooned(model_ann_mean), ndtooned(obs_ann_mean))

; Linear trend calculation
rc_model = regline(years, model_annual)
rc_obs = regline(years, obs_annual)

; Convert trends to mm/day/decade
trend_model = rc_model * 10.0
trend_obs = rc_obs * 10.0

; Calculate significance
df = nyears - 2
tval_model = rc_model@tval
tval_obs = rc_obs@tval
pval_model = (1 - betainc(df/(df+tval_model^2), df/2.0, 0.5)) * 2
pval_obs = (1 - betainc(df/(df+tval_obs^2), df/2.0, 0.5)) * 2

print("Statistical analysis complete")

;-----------------------------------------------------------------------
; STEP 9: WRITE STATISTICS TO FILE
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 9: Writing statistics to file...")
print("=======================================================")

system("rm -f " + stat_file)

; Write header and metadata
asciiwrite(stat_file, "======================================================")
asciiwrite(stat_file, "Precipitation Statistics: TaiESM vs GPCP")
asciiwrite(stat_file, "======================================================")
asciiwrite(stat_file, "Analysis Period: " + period_str)
asciiwrite(stat_file, "Analysis Date: " + systemfunc("date"))
asciiwrite(stat_file, "NCL Version: " + get_ncl_version())
asciiwrite(stat_file, " ")
asciiwrite(stat_file, "Model Data: " + model_dir)
asciiwrite(stat_file, "Observation Data: " + obs_file)
asciiwrite(stat_file, " ")
asciiwrite(stat_file, "======================================================")
asciiwrite(stat_file, " ")

; Write spatial statistics
asciiwrite(stat_file, "SPATIAL STATISTICS (Time-averaged " + period_str + "):")
asciiwrite(stat_file, "  Model global mean: " + sprintf("%6.3f", model_mean) + " mm/day")
asciiwrite(stat_file, "  Observation global mean: " + sprintf("%6.3f", obs_mean) + " mm/day")
asciiwrite(stat_file, "  Bias (Model - Obs): " + sprintf("%+6.3f", bias) + " mm/day")
asciiwrite(stat_file, "  RMSE: " + sprintf("%6.3f", rmse) + " mm/day")
asciiwrite(stat_file, "  Spatial correlation: " + sprintf("%6.3f", r))
asciiwrite(stat_file, " ")

; Write time series statistics
asciiwrite(stat_file, "TIME SERIES STATISTICS (Annual means):")
asciiwrite(stat_file, "  Model trend: " + sprintf("%+7.4f", trend_model) + " mm/day/decade (p=" + sprintf("%5.3f", pval_model) + ")")
asciiwrite(stat_file, "  Observation trend: " + sprintf("%+7.4f", trend_obs) + " mm/day/decade (p=" + sprintf("%5.3f", pval_obs) + ")")
asciiwrite(stat_file, " ")

; Write annual mean table
asciiwrite(stat_file, "ANNUAL MEAN VALUES:")
asciiwrite(stat_file, "  Year    Model    Observation    Difference")
asciiwrite(stat_file, "  ----    -----    -----------    ----------")

do yr = 0, nyears-1
    line = sprintf("%6i", years(yr)) + sprintf("%9.3f", model_annual(yr)) + \
           sprintf("%12.3f", obs_annual(yr)) + sprintf("%14.3f", model_annual(yr)-obs_annual(yr))
    asciiwrite(stat_file, line)
end do

print("Statistics written to: " + stat_file)

;-----------------------------------------------------------------------
; FINAL SUMMARY
;-----------------------------------------------------------------------
print(" ")
print("=======================================================")
print("Analysis Complete!")
print("=======================================================")
print("Period analyzed: " + period_str)
print("Key Results:")
print("  Global mean bias: " + sprintf("%+6.2f", bias) + " mm/day")
print("  RMSE: " + sprintf("%6.2f", rmse) + " mm/day")
print("  Correlation: " + sprintf("%6.3f", r))
print(" ")
print("Output files created:")
print("  - " + plot_spatial + "." + plot_type)
print("  - " + plot_ts + "." + plot_type)
print("  - " + stat_file)
print("=======================================================")

end
