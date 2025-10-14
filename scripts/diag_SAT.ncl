;=======================================================================
; TaiESM vs Berkeley Earth Surface Air Temperature Comparison (1870-1970)
; Following Python script logic for consistency
;=======================================================================

begin

;-----------------------------------------------------------------------
; USER SETTINGS
;-----------------------------------------------------------------------
; Model data settings
model_dir   = "/work/u5865217/HW1/MOD/BTHIST_test08a/atm/hist/"
model_prefix = "BTHIST_test08a.cam.h0."
model_var   = "TREFHT"

; Observational data settings
obs_file    = "/work/u5865217/HW1/OBS/OBS/best.tas.185001-201902.nc"
obs_var     = "tas"

; Time period
year_start  = 1870
year_end    = 1970
climo_year_start = 1951  ; Baseline for anomaly
climo_year_end = 1980

; Output settings
output_dir  = "./"
plot_type   = "png"

;-----------------------------------------------------------------------
; STEP 1: READ MODEL DATA
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 1: Reading TaiESM model data...")
print("=======================================================")

files = systemfunc("ls " + model_dir + model_prefix + "{1870..1970}*.nc")
nfiles = dimsizes(files)
print("Found " + nfiles + " model files")

fin_model = addfiles(files, "r")
ListSetType(fin_model, "cat")

; Read temperature and convert K to C
model_sat = fin_model[:]->$model_var$ - 273.15
model_sat@units = "degree C"

print("Model SAT shape: " + dimsizes(model_sat))
print("Model SAT range: " + min(model_sat) + " to " + max(model_sat) + " C")

;-----------------------------------------------------------------------
; STEP 2: READ OBSERVATION DATA
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 2: Reading Berkeley Earth observation data...")
print("=======================================================")

fin_obs = addfile(obs_file, "r")

; Parse time (YYYYMM format)
time_obs = fin_obs->time
years_obs = toint(time_obs / 100)
months_obs = toint(time_obs - years_obs * 100)

; Find indices for analysis period
ind_start = ind(years_obs .eq. year_start .and. months_obs .eq. 1)
ind_end = ind(years_obs .eq. year_end .and. months_obs .eq. 12)

if (ismissing(ind_start(0)) .or. ismissing(ind_end(0))) then
    print("ERROR: Time period not found in observation data")
    exit
end if

ind_start = ind_start(0)
ind_end = ind_end(0)

; Read observation data for the period
obs_sat_raw = fin_obs->$obs_var$(ind_start:ind_end,:,:)
obs_lat = fin_obs->latitude
obs_lon = fin_obs->longitude

; Convert obs lon from -180:180 to 0:360
obs_lon = where(obs_lon .lt. 0, obs_lon + 360, obs_lon)

; Sort by longitude
lon_sort = dim_pqsort(obs_lon, 1)
obs_lon := obs_lon(lon_sort)
obs_sat := obs_sat_raw(:,:,lon_sort)

; Reverse latitude if needed
if (obs_lat(0) .gt. obs_lat(dimsizes(obs_lat)-1)) then
    obs_lat := obs_lat(::-1)
    obs_sat := obs_sat(:,::-1,:)
end if

print("Obs SAT shape: " + dimsizes(obs_sat))
print("Obs SAT range: " + min(obs_sat) + " to " + max(obs_sat) + " C")
print("Obs lat range: " + min(obs_lat) + " to " + max(obs_lat))
print("Obs lon range: " + min(obs_lon) + " to " + max(obs_lon))

;-----------------------------------------------------------------------
; STEP 3: REGRID MODEL TO OBS GRID
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 3: Regridding model to observation grid...")
print("=======================================================")

model_lat = fin_model[0]->lat
model_lon = fin_model[0]->lon

print("Model grid: " + dimsizes(model_lat) + " x " + dimsizes(model_lon))
print("Obs grid: " + dimsizes(obs_lat) + " x " + dimsizes(obs_lon))

; Regrid using linint2
model_sat_regrid = linint2_Wrap(model_lon, model_lat, model_sat, True, obs_lon, obs_lat, 0)

print("Regridding complete")
print("Regridded model shape: " + dimsizes(model_sat_regrid))

;-----------------------------------------------------------------------
; STEP 4: CALCULATE CLIMATOLOGY MAP (TIME-AVERAGED)
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 4: Calculating climatology maps...")
print("=======================================================")

; Time-averaged maps for the entire period
model_climo_map = dim_avg_n_Wrap(model_sat_regrid, 0)
obs_climo_map = dim_avg_n_Wrap(obs_sat, 0)

; Assign coordinates
model_climo_map!0 = "lat"
model_climo_map!1 = "lon"
model_climo_map&lat = obs_lat
model_climo_map&lon = obs_lon

obs_climo_map!0 = "lat"
obs_climo_map!1 = "lon"
obs_climo_map&lat = obs_lat
obs_climo_map&lon = obs_lon

; Difference
diff_climo_map = model_climo_map - obs_climo_map
diff_climo_map!0 = "lat"
diff_climo_map!1 = "lon"
diff_climo_map&lat = obs_lat
diff_climo_map&lon = obs_lon

print("Model climo mean: " + sprintf("%6.2f", avg(model_climo_map)) + " C")
print("Obs climo mean: " + sprintf("%6.2f", avg(obs_climo_map)) + " C")

;-----------------------------------------------------------------------
; STEP 5: CALCULATE ANOMALY TIME SERIES
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 5: Calculating anomaly time series...")
print("=======================================================")

; Find baseline period indices in MONTHLY data
ntimes = dimsizes(model_sat_regrid(:,0,0))
years_array = new(ntimes, integer)
months_array = new(ntimes, integer)

; Assign year and month to each timestep
do t = 0, ntimes-1
    years_array(t) = year_start + toint(t/12)
    months_array(t) = mod(t, 12) + 1
end do

; Calculate monthly climatology (baseline period)
; Find indices for climatology period
ind_climo = ind(years_array .ge. climo_year_start .and. years_array .le. climo_year_end)

if (all(ismissing(ind_climo))) then
    print("WARNING: Climatology period outside data range, using full period")
    ind_climo = ispan(0, ntimes-1, 1)
end if

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

; Calculate anomaly: subtract monthly climatology from each month
model_sat_anom = model_sat_regrid
obs_sat_anom = obs_sat

do t = 0, ntimes-1
    m = months_array(t)
    model_sat_anom(t,:,:) = model_sat_regrid(t,:,:) - model_sat_climo(m-1,:,:)
    obs_sat_anom(t,:,:) = obs_sat(t,:,:) - obs_sat_climo(m-1,:,:)
end do

print("Anomaly calculated")

;-----------------------------------------------------------------------
; STEP 6: CALCULATE WEIGHTED GLOBAL MEAN TIME SERIES
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 6: Calculating global mean time series...")
print("=======================================================")

; Calculate area weights (cosine of latitude)
rad = 4.0 * atan(1.0) / 180.0
weights = cos(obs_lat * rad)

; Expand weights to match data dimensions
weights_2d = conform(model_sat_anom(0,:,:), weights, 0)

; Calculate weighted global mean for each timestep
model_ts_monthly = new(ntimes, float)
obs_ts_monthly = new(ntimes, float)

do t = 0, ntimes-1
    model_ts_monthly(t) = wgt_areaave(model_sat_anom(t,:,:), weights, 1.0, 0)
    obs_ts_monthly(t) = wgt_areaave(obs_sat_anom(t,:,:), weights, 1.0, 0)
end do

print("Monthly time series calculated")

; Calculate annual mean
nyears = year_end - year_start + 1
model_ts_annual = new(nyears, float)
obs_ts_annual = new(nyears, float)
years = ispan(year_start, year_end, 1)

do yr = 0, nyears-1
    ind_year = ind(years_array .eq. years(yr))
    if (.not. all(ismissing(ind_year))) then
        model_ts_annual(yr) = avg(model_ts_monthly(ind_year))
        obs_ts_annual(yr) = avg(obs_ts_monthly(ind_year))
    end if
    delete(ind_year)
end do

print("Annual time series calculated")
print("Model anomaly range: " + min(model_ts_annual) + " to " + max(model_ts_annual))
print("Obs anomaly range: " + min(obs_ts_annual) + " to " + max(obs_ts_annual))

;-----------------------------------------------------------------------
; STEP 7: PLOT CLIMATOLOGY MAP
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 7: Plotting climatology maps...")
print("=======================================================")

wks = gsn_open_wks(plot_type, output_dir + "temperature_spatial_1870-1970")

res = True
res@gsnMaximize = True
res@gsnDraw = False
res@gsnFrame = False
res@cnFillOn = True
res@cnLinesOn = False
res@cnLineLabelsOn = False
res@lbLabelBarOn = True
res@mpFillOn = False
res@mpOutlineOn = True
res@gsnAddCyclic = True
res@mpMinLatF = -90
res@mpMaxLatF = 90
res@mpMinLonF = 0
res@mpMaxLonF = 360
res@mpCenterLonF = 180

res@tmXBMode = "Explicit"
res@tmXBValues = (/0, 90, 180, 270, 360/)
res@tmXBLabels = (/"0~S~o~N~", "90~S~o~N~E", "180~S~o~N~", "90~S~o~N~W", "0~S~o~N~"/)
res@tmYLMode = "Explicit"
res@tmYLValues = (/-90, -45, 0, 45, 90/)
res@tmYLLabels = (/"90~S~o~N~S", "45~S~o~N~S", "0~S~o~N~", "45~S~o~N~N", "90~S~o~N~N"/)

; Model
res@cnLevelSelectionMode = "ManualLevels"
res@cnMinLevelValF = -10.0
res@cnMaxLevelValF = 30.0
res@cnLevelSpacingF = 2.0
res@tiMainString = "SAT - TaiESM-TIMCOM (~S~o~N~C)"
res@gsnLeftString = ""
res@gsnRightString = ""
cmap = read_colormap_file("BlueYellowRed")
res@cnFillPalette = cmap
plot1 = gsn_csm_contour_map(wks, model_climo_map, res)

; Observation
res@tiMainString = "SAT - Observation (~S~o~N~C)"
plot2 = gsn_csm_contour_map(wks, obs_climo_map, res)

; Difference
delete(res@cnFillPalette)
res@cnMinLevelValF = -4.0
res@cnMaxLevelValF = 4.0
res@cnLevelSpacingF = 0.5
res@tiMainString = "SAT - Difference (~S~o~N~C)"
cmap_diff = read_colormap_file("cmp_b2r")
res@cnFillPalette = cmap_diff
plot3 = gsn_csm_contour_map(wks, diff_climo_map, res)

pres = True
pres@gsnMaximize = True
pres@gsnPanelLabelBar = False
gsn_panel(wks, (/plot1, plot2, plot3/), (/3,1/), pres)

print("Spatial plots created")

;-----------------------------------------------------------------------
; STEP 8: PLOT TIME SERIES
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 8: Plotting time series...")
print("=======================================================")

wks_ts = gsn_open_wks(plot_type, output_dir + "temperature_timeseries_1870-1970")
gsn_define_colormap(wks_ts, "default")

res_ts = True
res_ts@gsnMaximize = True
res_ts@gsnDraw = False
res_ts@gsnFrame = False
res_ts@xyLineThicknesses = (/2.5, 2.5/)
res_ts@xyLineColors = (/"black", "red"/)
res_ts@xyDashPatterns = (/0, 0/)
res_ts@tiMainString = "Global mean SAT (~S~o~N~C)"
res_ts@tiMainFontHeightF = 0.025
res_ts@tiYAxisString = ""
res_ts@tiXAxisString = ""
res_ts@trYMinF = -1.0
res_ts@trYMaxF = 0.6
res_ts@trXMinF = 1850
res_ts@trXMaxF = 2010
res_ts@tmYLMode = "Manual"
res_ts@tmYLTickStartF = -1.0
res_ts@tmYLTickEndF = 0.6
res_ts@tmYLTickSpacingF = 0.5
res_ts@tmYLMinorPerMajor = 4
res_ts@tmXBMode = "Manual"
res_ts@tmXBTickStartF = 1860
res_ts@tmXBTickEndF = 2010
res_ts@tmXBTickSpacingF = 20
res_ts@tmYROn = False
res_ts@tmXTOn = False
res_ts@vpWidthF = 0.7
res_ts@vpHeightF = 0.35
res_ts@pmLegendDisplayMode = "Always"
res_ts@pmLegendSide = "Top"
res_ts@pmLegendParallelPosF = 0.25
res_ts@pmLegendOrthogonalPosF = -0.35
res_ts@pmLegendWidthF = 0.15
res_ts@pmLegendHeightF = 0.08
res_ts@lgLabelFontHeightF = 0.018
res_ts@lgPerimOn = True
res_ts@lgItemType = "Lines"
res_ts@xyExplicitLegendLabels = (/"Observation", "TaiESM-TIMCOM"/)

data = new((/2, nyears/), float)
data(0,:) = obs_ts_annual
data(1,:) = model_ts_annual

plot_ts = gsn_csm_xy(wks_ts, years, data, res_ts)
draw(plot_ts)
frame(wks_ts)

print("Time series plot created")

;-----------------------------------------------------------------------
; STEP 9: STATISTICS
;-----------------------------------------------------------------------
print("=======================================================")
print("Step 9: Writing statistics...")
print("=======================================================")

stat_file = output_dir + "temperature_statistics_1870-1970.txt"
system("rm -f " + stat_file)

asciiwrite(stat_file, "Temperature Statistics: TaiESM vs Berkeley Earth (1870-1970)")
asciiwrite(stat_file, "==============================================================")
asciiwrite(stat_file, " ")
asciiwrite(stat_file, "SPATIAL STATISTICS:")
asciiwrite(stat_file, "  Model mean: " + sprintf("%6.2f", avg(model_climo_map)) + " C")
asciiwrite(stat_file, "  Obs mean: " + sprintf("%6.2f", avg(obs_climo_map)) + " C")
asciiwrite(stat_file, "  Bias: " + sprintf("%6.2f", avg(diff_climo_map)) + " C")
asciiwrite(stat_file, " ")
asciiwrite(stat_file, "ANOMALY TIME SERIES (relative to " + climo_year_start + "-" + climo_year_end + "):")
do yr = 0, nyears-1
    if (.not.ismissing(model_ts_annual(yr))) then
        line = sprintf("%4i", years(yr)) + sprintf("%8.3f", model_ts_annual(yr)) + \
               sprintf("%8.3f", obs_ts_annual(yr))
        asciiwrite(stat_file, line)
    end if
end do

print("Analysis complete!")
print("Output files:")
print("  - " + output_dir + "temperature_spatial_1870-1970." + plot_type)
print("  - " + output_dir + "temperature_timeseries_1870-1970." + plot_type)
print("  - " + stat_file)

end
