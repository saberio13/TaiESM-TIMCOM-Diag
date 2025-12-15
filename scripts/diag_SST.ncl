;========================================================================
;
; Purpose: Compare TaiESM TIMCOM model output with HadISST observational data
;
; Creates:
;   - Spatial distribution contour plots (model, obs, difference)
;   - Time series plots (annual global mean SST, VAT)
;   - Statistical analysis and text output
;
; Date: December 2025
;========================================================================

begin

;========================================================================
; USER SETTINGS
;========================================================================
start_year = 1850
end_year   = 1999
climo_start_year = 1980
climo_end_year   = 1999

model_dir = "/work/u5865217/HW1/MOD/BTHIST_test08a/ocn/hist/"
topo_file = model_dir + "TOPO.nc"
obs_file  = "/work/u5865217/HW1/OBS/OBS/hadisst.sst.187001-201812.nc"
output_dir = "./"
system("mkdir -p " + output_dir)

plot_format = "png"
stats_file = output_dir + "statistics_climo" + climo_start_year + "-" + climo_end_year + ".txt"

print("TaiESM TIMCOM vs HadISST | Data: " + start_year + "-" + end_year + " | Climo: " + climo_start_year + "-" + climo_end_year)

;========================================================================
; LOAD GRID AND CALCULATE METRICS
;========================================================================
topo = addfile(topo_file, "r")
lon_1d = topo->lon
lat_1d = topo->lat
lev_c  = topo->lev_c
lev_f  = topo->lev_f

nlon = dimsizes(lon_1d)
nlat = dimsizes(lat_1d)
nlev = dimsizes(lev_c)

lon_2d = conform_dims((/nlat, nlon/), lon_1d, 1)
lat_2d = conform_dims((/nlat, nlon/), lat_1d, 0)

; Grid cell area (m^2)
deg2m = 111200.0d
dlon_1d = new(nlon, double)
dlat_1d = new(nlat, double)
dlon_1d(:nlon-2) = lon_1d(1:nlon-1) - lon_1d(0:nlon-2)
dlon_1d(nlon-1) = dlon_1d(nlon-2)
dlat_1d(:nlat-2) = lat_1d(1:nlat-1) - lat_1d(0:nlat-2)
dlat_1d(nlat-1) = dlat_1d(nlat-2)

dlon = conform_dims((/nlat, nlon/), dlon_1d, 1)
dlat = conform_dims((/nlat, nlon/), dlat_1d, 0)
area = dlon * deg2m * dlat * deg2m * cos(lat_2d * 0.017453293d)

; Layer thickness and 3D volume
dz = new(nlev, double)
dz = (lev_f(1:nlev) - lev_f(0:nlev-1)) * 0.01d
volume = new((/nlev, nlat, nlon/), double)
do k = 0, nlev-1
    volume(k,:,:) = area * dz(k)
end do

print("Grid loaded: " + nlat + " lat x " + nlon + " lon x " + nlev + " lev")

;========================================================================
; LOAD MODEL DATA (MEMORY EFFICIENT)
;========================================================================
nyears = end_year - start_year + 1
sst_global_ts_model = new(nyears, double)
vat_global_ts_model = new(nyears, double)
sst_model_annual = new((/nyears, nlat, nlon/), double)
base_year = 1850

do year = start_year, end_year
    year_idx = year - start_year
    sst_monthly_year = new((/12, nlat, nlon/), double)
    vat_monthly_year = new(12, double)

    do month = 1, 12
        file_year_str = sprinti("%04i", year - base_year + 1)
        month_str = sprinti("%02i", month)
        filename = model_dir + "DATA_" + file_year_str + month_str + ".nc"

        if (.not. fileexists(filename)) then
            print("WARNING: Missing " + filename)
            continue
        end if

        f = addfile(filename, "r")
        temp_3d = f->temperature
        if (.not. isatt(temp_3d, "_FillValue")) then
            temp_3d@_FillValue = -999.0d
        end if
        temp_3d = where(temp_3d .eq. 0.0d, temp_3d@_FillValue, temp_3d)

        sst_monthly_year(month-1,:,:) = (/temp_3d(0,:,:)/)

        valid_mask_3d = .not.ismissing(temp_3d)
        ocean_volume = sum(where(valid_mask_3d, volume, 0.0d))
        vat_monthly_year(month-1) = sum(where(valid_mask_3d, temp_3d * volume, 0.0d)) / ocean_volume

        delete([/f, temp_3d, valid_mask_3d, ocean_volume/])
    end do

    sst_model_annual(year_idx,:,:) = dim_avg_n(sst_monthly_year, 0)
    valid_mask_2d = .not.ismissing(sst_model_annual(year_idx,:,:))
    ocean_area = sum(where(valid_mask_2d, area, 0.0d))
    sst_global_ts_model(year_idx) = sum(where(valid_mask_2d, sst_model_annual(year_idx,:,:) * area, 0.0d)) / ocean_area
    vat_global_ts_model(year_idx) = avg(vat_monthly_year)

    delete([/sst_monthly_year, vat_monthly_year, valid_mask_2d, ocean_area/])
end do

print("Model data loaded: " + nyears + " years")

;========================================================================
; LOAD OBSERVATIONAL DATA (CLIMATOLOGY ONLY)
;========================================================================
f_obs = addfile(obs_file, "r")
lon_obs_1d = f_obs->lon
lat_obs_1d = f_obs->lat
time_obs_all = f_obs->time
sst_obs_all = f_obs->sst

time_climo_start_obs = climo_start_year * 100 + 1
time_climo_end_obs   = climo_end_year * 100 + 12

time_idx_start = ind(time_obs_all .eq. time_climo_start_obs)
time_idx_end = ind(time_obs_all .eq. time_climo_end_obs)

sst_obs_climo_months = sst_obs_all(time_idx_start:time_idx_end, :, :)
nlat_obs = dimsizes(lat_obs_1d)
nlon_obs = dimsizes(lon_obs_1d)

nclimo_years = climo_end_year - climo_start_year + 1
sst_obs_annual_climo = new((/nclimo_years, nlat_obs, nlon_obs/), double)
do iy = 0, nclimo_years - 1
    sst_obs_annual_climo(iy,:,:) = dim_avg_n(sst_obs_climo_months(iy*12:(iy*12+11),:,:), 0)
end do
sst_obs_clim = dim_avg_n(sst_obs_annual_climo, 0)

lon_obs_2d = conform_dims((/nlat_obs, nlon_obs/), lon_obs_1d, 1)
lat_obs_2d = conform_dims((/nlat_obs, nlon_obs/), lat_obs_1d, 0)

print("HadISST climatology loaded: " + climo_start_year + "-" + climo_end_year)

;========================================================================
; CALCULATE CLIMATOLOGY AND REGRID
;========================================================================
climo_start_idx = climo_start_year - start_year
climo_end_idx = climo_end_year - start_year
sst_model_clim = dim_avg_n(sst_model_annual(climo_start_idx:climo_end_idx,:,:), 0)
sst_obs_clim_regrid = linint2(lon_obs_1d, lat_obs_1d, sst_obs_clim, False, lon_1d, lat_1d, 0)

;========================================================================
; CALCULATE STATISTICS
;========================================================================
years = ispan(start_year, end_year, 1)

valid_mask_model = .not.ismissing(sst_model_clim)
ocean_area_model = sum(where(valid_mask_model, area, 0.0d))
sst_model_mean = sum(where(valid_mask_model, sst_model_clim * area, 0.0d)) / ocean_area_model

valid_mask_obs = .not.ismissing(sst_obs_clim_regrid)
ocean_area_obs = sum(where(valid_mask_obs, area, 0.0d))
sst_obs_mean = sum(where(valid_mask_obs, sst_obs_clim_regrid * area, 0.0d)) / ocean_area_obs

sst_bias_map = sst_model_clim - sst_obs_clim_regrid
sst_bias_global = sst_model_mean - sst_obs_mean

sst_diff_sq = (sst_model_clim - sst_obs_clim_regrid)^2
valid_mask_diff = .not.ismissing(sst_diff_sq)
ocean_area_diff = sum(where(valid_mask_diff, area, 0.0d))
sst_rmse = sqrt(sum(where(valid_mask_diff, sst_diff_sq * area, 0.0d)) / ocean_area_diff)

rc_model = regline(years, sst_global_ts_model)
trend_model_sst = rc_model * 10.0
trend_model_sst@units = "°C/decade"

rc_vat = regline(years, vat_global_ts_model)
trend_vat = rc_vat * 10.0
trend_vat@units = "°C/decade"

;========================================================================
; WRITE STATISTICS
;========================================================================
stat_list = [/ \
    "TaiESM TIMCOM Analysis", \
    "Data: " + start_year + "-" + end_year + " | Climo: " + climo_start_year + "-" + climo_end_year, \
    "", \
    "SPATIAL CLIMATOLOGY:", \
    "  Model SST:    " + sprintf("%6.3f", sst_model_mean) + " °C", \
    "  Obs SST:      " + sprintf("%6.3f", sst_obs_mean) + " °C", \
    "  Bias:         " + sprintf("%6.3f", sst_bias_global) + " °C", \
    "  RMSE:         " + sprintf("%6.3f", sst_rmse) + " °C", \
    "", \
    "TIME SERIES (" + start_year + "-" + end_year + "):", \
    "  SST Mean:     " + sprintf("%6.3f", avg(sst_global_ts_model)) + " °C", \
    "  SST Std:      " + sprintf("%6.3f", stddev(sst_global_ts_model)) + " °C", \
    "  SST Trend:    " + sprintf("%7.4f", trend_model_sst) + " °C/decade", \
    "", \
    "  VAT Mean:     " + sprintf("%6.3f", avg(vat_global_ts_model)) + " °C", \
    "  VAT Std:      " + sprintf("%6.3f", stddev(vat_global_ts_model)) + " °C", \
    "  VAT Trend:    " + sprintf("%7.4f", trend_vat) + " °C/decade" \
/]

asciiwrite(stats_file, stat_list)
do i = 0, dimsizes(stat_list) - 1
    print(stat_list(i))
end do

;========================================================================
; SPATIAL DISTRIBUTION PLOTS
;========================================================================
wks = gsn_open_wks(plot_format, output_dir + "sst_spatial_comparison")

res = True
res@gsnDraw = False
res@gsnFrame = False
res@gsnAddCyclic = False
res@mpFillOn = True
res@mpLandFillColor = "gray80"
res@mpOceanFillColor = -1
res@mpInlandWaterFillColor = "gray80"
res@mpOutlineOn = True
res@mpGeophysicalLineThicknessF = 1.0
res@mpGridAndLimbOn = True
res@mpGridLatSpacingF = 45
res@mpGridLonSpacingF = 90
res@mpCenterLonF = 180
res@cnFillOn = True
res@cnLinesOn = False
res@cnLineLabelsOn = False
res@cnLevelSelectionMode = "ManualLevels"
res@lbLabelBarOn = True
res@lbOrientation = "Vertical"
res@lbLabelFontHeightF = 0.010

pres = True
pres@gsnMaximize = True
pres@gsnPanelBottom = 0.05
pres@gsnPanelTop = 0.95
pres@gsnPanelYWhiteSpacePercent = 2

plots = new(3, graphic)

; Panel 1: Model
res@cnFillPalette = "WhBlGrYeRe"
res@cnMinLevelValF = -3.0
res@cnMaxLevelValF = 33.0
res@cnLevelSpacingF = 3.0
res@gsnLeftString = ""
res@gsnRightString = ""
res@tiMainString = "SST - TaiESM-TIMCOM (~F34~0~F~C) [" + climo_start_year + "-" + climo_end_year + "]"
res@tiMainFontHeightF = 0.016
res@sfXArray = lon_2d
res@sfYArray = lat_2d
plots(0) = gsn_csm_contour_map(wks, sst_model_clim, res)

; Panel 2: Observation
delete([/res@sfXArray, res@sfYArray/])
res@tiMainString = "SST - Observation (~F34~0~F~C) [" + climo_start_year + "-" + climo_end_year + "]"
res@sfXArray = lon_obs_2d
res@sfYArray = lat_obs_2d
plots(1) = gsn_csm_contour_map(wks, sst_obs_clim, res)

; Panel 3: Difference
delete([/res@sfXArray, res@sfYArray/])
res@cnFillPalette = "BlueRed"
res@cnMinLevelValF = -3.0
res@cnMaxLevelValF = 3.0
res@cnLevelSpacingF = 0.5
res@tiMainString = "SST - Difference (~F34~0~F~C) [" + climo_start_year + "-" + climo_end_year + "]"
res@sfXArray = lon_2d
res@sfYArray = lat_2d
plots(2) = gsn_csm_contour_map(wks, sst_bias_map, res)

gsn_panel(wks, plots, (/3,1/), pres)
print("Created: sst_spatial_comparison." + plot_format)

;========================================================================
; PUBLICATION-QUALITY TIME SERIES PLOTS
;========================================================================

; --- SST Time Series ---
wks = gsn_open_wks(plot_format, output_dir + "sst_timeseries")

res_ts = True
res_ts@gsnDraw = False
res_ts@gsnFrame = False
res_ts@gsnMaximize = True

; Enhanced axis settings
res_ts@trXMinF = start_year
res_ts@trXMaxF = end_year
res_ts@tmXBMode = "Explicit"
tick_years = ispan(start_year, end_year, 20)  ; Every 20 years for clarity
res_ts@tmXBValues = tick_years
res_ts@tmXBLabels = sprinti("%04i", tick_years)
res_ts@tmXBLabelFontHeightF = 0.014
res_ts@tmXBLabelAngleF = 0
res_ts@tmXBMinorOn = True
res_ts@tmXBMinorPerMajor = 3  ; Minor ticks between major ticks

; Y-axis improvements
res_ts@tiYAxisString = "Global mean SST (~F34~0~F~C)"
res_ts@tiYAxisFontHeightF = 0.020
res_ts@tmYLLabelFontHeightF = 0.014
res_ts@tmYLMode = "Automatic"
res_ts@tmYLMinorOn = True

; Professional grid
res_ts@tmXMajorGrid = True
res_ts@tmYMajorGrid = True
res_ts@tmXMajorGridLineColor = "gray75"
res_ts@tmYMajorGridLineColor = "gray75"
res_ts@tmXMajorGridLineDashPattern = 1
res_ts@tmYMajorGridLineDashPattern = 1
res_ts@tmXMajorGridThicknessF = 0.8
res_ts@tmYMajorGridThicknessF = 0.8

; Enhanced line
res_ts@xyLineThicknessF = 3.0
res_ts@xyLineColor = "red3"

; Title
res_ts@tiMainString = "TaiESM Global Mean SST (" + start_year + "-" + end_year + ")"
res_ts@tiMainFontHeightF = 0.024
res_ts@tiMainOffsetYF = -0.01

; Add trend annotation
trend_text = sprintf("Trend: %.4f", trend_model_sst) + " ~F34~0~F~C/decade"
res_ts@gsnLeftString = trend_text
res_ts@gsnLeftStringFontHeightF = 0.016
res_ts@gsnRightString = ""

plot = gsn_csm_xy(wks, years, sst_global_ts_model, res_ts)

; Add trend line
rc_sst = regline(years, sst_global_ts_model)
trend_line = rc_sst * (years - rc_sst@xave) + rc_sst@yave

res_trend = True
res_trend@gsLineColor = "blue"
res_trend@gsLineThicknessF = 2.0
res_trend@gsLineDashPattern = 2
trend_plot = gsn_add_polyline(wks, plot, years, trend_line, res_trend)

draw(plot)
frame(wks)
delete(wks)
print("Created: sst_timeseries." + plot_format)

; --- VAT Time Series ---
wks = gsn_open_wks(plot_format, output_dir + "vat_timeseries")

res_ts@tiYAxisString = "Global mean VAT (~F34~0~F~C)"
res_ts@tiMainString = "TaiESM Global Mean VAT (" + start_year + "-" + end_year + ")"
trend_text_vat = sprintf("Trend: %.4f", trend_vat) + " ~F34~0~F~C/decade"
res_ts@gsnLeftString = trend_text_vat

plot = gsn_csm_xy(wks, years, vat_global_ts_model, res_ts)

; Add trend line
rc_vat_line = regline(years, vat_global_ts_model)
trend_line_vat = rc_vat_line * (years - rc_vat_line@xave) + rc_vat_line@yave
trend_plot_vat = gsn_add_polyline(wks, plot, years, trend_line_vat, res_trend)

draw(plot)
frame(wks)
delete(wks)
print("Created: vat_timeseries." + plot_format)

;========================================================================
; COMPLETION
;========================================================================
print("Analysis complete! Files: sst_spatial_comparison." + plot_format + ", sst_timeseries." + plot_format + ", vat_timeseries." + plot_format + ", " + stats_file)

end
