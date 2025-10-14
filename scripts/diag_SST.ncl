;=======================================================================
; NCL Script for Comparing TaiESM TIMCOM with HadISST Observations
; Purpose: Compare model SST and ocean volume-averaged temperature 
;          with observational data for a specified time period
;=======================================================================

begin

;=======================================================================
; USER SETTINGS - Modify these parameters as needed
;=======================================================================

  ; Time period for analysis (flexible)
  start_year = 1870
  end_year   = 1970
  
  ; Data paths
  model_dir = "/work/u5865217/HW1/MOD/BTHIST_test08a/ocn/hist/"
  topo_file = "/work/u5865217/HW1/MOD/BTHIST_test08a/ocn/hist/TOPO.nc"  ; Grid coordinates file
  obs_file  = "/work/u5865217/HW1/OBS/OBS/hadisst.sst.187001-201812.nc"
  
  ; Output settings
  output_dir = "./"
  plot_prefix = "TaiESM_HadISST_comparison_" + start_year + "-" + end_year
  
  ; Plotting options
  plot_model_spatial = True   ; Set to False to skip model spatial plots (if grid issues)
  
  ; Model data naming convention
  model_start_year = 1850  ; First year in model data (DATA_000101.nc)
  ; DATA_YYYYMM.nc where YYYY starts from year 1 (1850)
  model_start_year = 1850  ; First year in model data (DATA_000101.nc)
  
;=======================================================================
; LOAD OBSERVATIONAL DATA (HadISST)
;=======================================================================

  print("Loading HadISST observational data...")
  
  f_obs = addfile(obs_file, "r")
  
  ; Read time, lat, lon
  time_obs = f_obs->time
  lat_obs  = f_obs->lat
  lon_obs  = f_obs->lon
  
  ; Convert time to YYYYMM format and select period
  year_obs  = time_obs / 100
  month_obs = time_obs - year_obs * 100
  
  ; Find indices for desired time period
  time_idx = ind(year_obs.ge.start_year .and. year_obs.le.end_year)
  
  if (ismissing(time_idx(0))) then
    print("ERROR: No observational data found for " + start_year + "-" + end_year)
    exit
  end if
  
  ; Read SST for the selected period
  sst_obs_full = f_obs->sst(time_idx,:,:)
  time_obs_sel = time_obs(time_idx)
  
  print("Loaded " + dimsizes(time_idx) + " months of HadISST data")
  
;=======================================================================
; LOAD MODEL DATA (TaiESM TIMCOM)
;=======================================================================

  print("Loading TaiESM TIMCOM model data...")
  
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
  
  ; Read first file to get grid information
  f_model = addfile(file_list(0), "r")
  
  ; Read a variable to get dimension sizes
  temp_test = f_model->temperature
  dim_sizes = dimsizes(temp_test)
  nlev = dim_sizes(0)
  nlat = dim_sizes(1)
  nlon = dim_sizes(2)
  delete(temp_test)
  
  print("Model grid dimensions: nlev=" + nlev + ", nlat=" + nlat + ", nlon=" + nlon)
  
  ; Read grid coordinates from TOPO.nc
  print("Reading grid coordinates from TOPO.nc...")
  if (fileexists(topo_file)) then
    f_topo = addfile(topo_file, "r")
    
    ; Read 1D lat/lon coordinates
    lat_model = f_topo->lat
    lon_model = f_topo->lon
    lev_c = f_topo->lev_c  ; level centers
    lev_f = f_topo->lev_f  ; level faces (interfaces) for depth calculation
    
    print("Successfully read coordinates from TOPO.nc")
    print("  Latitude range: " + min(lat_model) + " to " + max(lat_model))
    print("  Longitude range: " + min(lon_model) + " to " + max(lon_model))
    print("  Levels (centers): " + dimsizes(lev_c))
    print("  Levels (faces): " + dimsizes(lev_f))
    
    ; Add proper attributes for plotting
    if (.not. isatt(lat_model, "units")) then
      lat_model@units = "degrees_north"
    end if
    lat_model!0 = "latitude"
    lat_model&latitude = lat_model
    
    if (.not. isatt(lon_model, "units")) then
      lon_model@units = "degrees_east"
    end if
    lon_model!0 = "longitude"
    lon_model&longitude = lon_model
    
    lev_model = lev_c
    
  else
    print("ERROR: TOPO.nc not found at " + topo_file)
    print("Cannot proceed without proper grid coordinates.")
    exit
  end if
  
  ; Initialize arrays for model data (use double to match model output)
  sst_model = new((/nmonths, nlat, nlon/), double)
  temp_3d   = new((/nmonths, nlev, nlat, nlon/), double)
  
  ; Read model data for all months
  do ifile = 0, nmonths - 1
    if (fileexists(file_list(ifile))) then
      f = addfile(file_list(ifile), "r")
      ; SST is the top level (index 0) of temperature
      temp_3d(ifile,:,:,:) = f->temperature
      sst_model(ifile,:,:) = f->temperature(0,:,:)
      delete(f)
    else
      print("WARNING: File not found: " + file_list(ifile))
      sst_model(ifile,:,:) = sst_model@_FillValue
      temp_3d(ifile,:,:,:) = temp_3d@_FillValue
    end if
  end do
  
  ; Mask land values (typically very large negative or specific fill values)
  ; Check for unrealistic SST values and zeros (often indicate land/ice)
  sst_model = where(sst_model .lt. -5.0 .or. sst_model .gt. 50.0 .or. abs(sst_model) .lt. 0.001, sst_model@_FillValue, sst_model)
  
  print("Loaded " + nmonths + " months of model data")
  print("SST range: " + min(sst_model) + " to " + max(sst_model) + " °C")
  
;=======================================================================
; REGRID OBSERVATIONAL DATA TO MODEL GRID
;=======================================================================

  print("Regridding observational data to model grid...")
  
  ; Add coordinate variables
  sst_obs_full!0 = "time"
  sst_obs_full!1 = "lat"
  sst_obs_full!2 = "lon"
  sst_obs_full&lat = lat_obs
  sst_obs_full&lon = lon_obs
  
  ; Regrid to model grid using bilinear interpolation
  sst_obs = linint2_Wrap(lon_obs, lat_obs, sst_obs_full, True, lon_model, lat_model, 0)
  
  ; Also mask observation data where model has missing values (to ensure fair comparison)
  ; Use the first time step as a mask template
  do itime = 0, nmonths - 1
    sst_obs(itime,:,:) = where(ismissing(sst_model(itime,:,:)), sst_obs@_FillValue, sst_obs(itime,:,:))
  end do
  
  print("Observation data regridded and masked")
  
;=======================================================================
; CALCULATE TEMPORAL MEANS
;=======================================================================

  print("Calculating temporal means...")
  
  ; Mean SST over the period
  sst_model_mean = dim_avg_n_Wrap(sst_model, 0)
  sst_obs_mean   = dim_avg_n_Wrap(sst_obs, 0)
  
  ; Add coordinate information for plotting
  sst_model_mean!0 = "lat"
  sst_model_mean!1 = "lon"
  sst_model_mean&lat = lat_model
  sst_model_mean&lon = lon_model
  
  sst_obs_mean!0 = "lat"
  sst_obs_mean!1 = "lon"
  sst_obs_mean&lat = lat_model
  sst_obs_mean&lon = lon_model
  
  ; Calculate difference (bias)
  sst_diff = sst_model_mean - sst_obs_mean
  sst_diff!0 = "lat"
  sst_diff!1 = "lon"
  sst_diff&lat = lat_model
  sst_diff&lon = lon_model
  
;=======================================================================
; CALCULATE GLOBAL MEAN TIME SERIES
;=======================================================================

  print("Calculating global mean time series...")
  
  ; Calculate area weights (cosine of latitude)
  lat_rad = lat_model * 0.017453293  ; Convert to radians
  wgt = cos(lat_rad)
  wgt!0 = "latitude"
  wgt&latitude = lat_model
  
  ; Global mean SST time series
  sst_model_global = new(nmonths, double)
  sst_obs_global   = new(nmonths, double)
  
  do imon = 0, nmonths - 1
    sst_model_global(imon) = wgt_areaave(sst_model(imon,:,:), wgt, 1.0, 0)
    sst_obs_global(imon)   = wgt_areaave(sst_obs(imon,:,:), wgt, 1.0, 0)
  end do
  
  ; Calculate annual means
  nyears = end_year - start_year + 1
  sst_model_annual = new(nyears, double)
  sst_obs_annual   = new(nyears, double)
  year_array       = ispan(start_year, end_year, 1)
  
  do iyr = 0, nyears - 1
    idx_start = iyr * 12
    idx_end   = idx_start + 11
    sst_model_annual(iyr) = avg(sst_model_global(idx_start:idx_end))
    sst_obs_annual(iyr)   = avg(sst_obs_global(idx_start:idx_end))
  end do
  
;=======================================================================
; CALCULATE VOLUME-AVERAGED OCEAN TEMPERATURE
;=======================================================================

  print("Calculating volume-averaged ocean temperature...")
  
  ; Read ocean mask from TOPO.nc if available
  if (isfilevar(f_topo, "mask")) then
    ocean_mask = f_topo->mask  ; 3D mask (level, lat, lon)
    print("Read ocean mask from TOPO.nc")
  else
    ; Create mask from data (non-missing values are ocean)
    ocean_mask = new((/nlev, nlat, nlon/), integer)
    ocean_mask = where(.not.ismissing(temp_3d(0,:,:,:)), 1, 0)
    print("Created ocean mask from data")
  end if
  
  ; Calculate layer thickness from level faces
  dz = new(nlev, double)
  do k = 0, nlev-1
    dz(k) = abs(lev_f(k+1) - lev_f(k))
  end do
  
  print("Layer thickness (dz) range: " + min(dz) + " to " + max(dz))
  print("Total depth: " + sum(dz))
  
  ; Calculate area weights (cos of latitude)
  lat_rad = lat_model * 0.017453293
  area_wgt = cos(lat_rad)
  
  ; Create 3D volume weight array (optimize by pre-computing)
  vol_weight = new((/nlev, nlat, nlon/), double)
  do k = 0, nlev-1
    do j = 0, nlat-1
      vol_weight(k,j,:) = dz(k) * area_wgt(j)
    end do
  end do
  
  ; Apply ocean mask to volume weights
  vol_weight = where(ocean_mask .eq. 1, vol_weight, 0.0d)
  total_volume = sum(vol_weight)
  
  print("Total ocean volume (weighted): " + total_volume)
  print("Computing VAT for " + nmonths + " months using vectorized operations...")
  
  ; Calculate volume-averaged temperature for each month (VECTORIZED)
  vol_avg_temp = new(nmonths, double)
  
  do imon = 0, nmonths - 1
    ; Create temporary weight array (zero where data is missing)
    wgt_valid = where(.not.ismissing(temp_3d(imon,:,:,:)), vol_weight, 0.0d)
    
    ; Vectorized calculation
    vol_avg_temp(imon) = sum(temp_3d(imon,:,:,:) * wgt_valid) / sum(wgt_valid)
    
    ; Progress every 120 months (~10 years)
    if (imon .eq. 0 .or. (imon+1) % 120 .eq. 0 .or. imon .eq. nmonths-1) then
      print("  Processed month " + (imon+1) + "/" + nmonths + ", VAT = " + sprintf("%6.3f", vol_avg_temp(imon)) + " °C")
    end if
  end do
  
  print("Volume-averaged temperature range: " + min(vol_avg_temp) + " to " + max(vol_avg_temp) + " °C")
  print("Mean VAT: " + avg(vol_avg_temp) + " °C")
  
  ; Annual volume-averaged temperature
  vol_avg_annual = new(nyears, double)
  do iyr = 0, nyears - 1
    idx_start = iyr * 12
    idx_end   = idx_start + 11
    vol_avg_annual(iyr) = avg(vol_avg_temp(idx_start:idx_end))
  end do
  
;=======================================================================
; CALCULATE STATISTICS
;=======================================================================

  print("Calculating statistics...")
  
  ; Global mean values
  sst_model_clim = avg(sst_model_annual)
  sst_obs_clim   = avg(sst_obs_annual)
  vol_avg_clim   = avg(vol_avg_annual)
  
  ; Bias
  bias_global = sst_model_clim - sst_obs_clim
  
  ; RMSE
  rmse = sqrt(avg((sst_model - sst_obs)^2))
  
  ; Linear trends (using regline function)
  x_time = ispan(0, nyears-1, 1) * 1.0
  
  rc_model = regline(x_time, sst_model_annual)
  rc_obs   = regline(x_time, sst_obs_annual)
  rc_vol   = regline(x_time, vol_avg_annual)
  
  trend_model = rc_model * 10.0  ; Per decade
  trend_obs   = rc_obs * 10.0
  trend_vol   = rc_vol * 10.0
  
;=======================================================================
; WRITE STATISTICS TO TEXT FILE
;=======================================================================

  print("Writing statistics to file...")
  
  stat_file = output_dir + plot_prefix + "_statistics.txt"
  system("rm -f " + stat_file)
  
  asciiwrite(stat_file, "==========================================================")
  asciiwrite(stat_file, "TaiESM TIMCOM vs HadISST Comparison Statistics")
  asciiwrite(stat_file, "Period: " + start_year + "-" + end_year)
  asciiwrite(stat_file, "==========================================================")
  asciiwrite(stat_file, "")
  asciiwrite(stat_file, "GLOBAL MEAN SST:")
  asciiwrite(stat_file, "  Model:       " + sprintf("%6.3f", sst_model_clim) + " °C")
  asciiwrite(stat_file, "  Observation: " + sprintf("%6.3f", sst_obs_clim) + " °C")
  asciiwrite(stat_file, "  Bias:        " + sprintf("%6.3f", bias_global) + " °C")
  asciiwrite(stat_file, "  RMSE:        " + sprintf("%6.3f", rmse) + " °C")
  asciiwrite(stat_file, "")
  asciiwrite(stat_file, "TRENDS (per decade):")
  asciiwrite(stat_file, "  Model SST:   " + sprintf("%7.4f", trend_model) + " °C/decade")
  asciiwrite(stat_file, "  Obs SST:     " + sprintf("%7.4f", trend_obs) + " °C/decade")
  asciiwrite(stat_file, "  Volume Avg:  " + sprintf("%7.4f", trend_vol) + " °C/decade")
  asciiwrite(stat_file, "")
  asciiwrite(stat_file, "VOLUME-AVERAGED OCEAN TEMPERATURE:")
  asciiwrite(stat_file, "  Mean:        " + sprintf("%6.3f", vol_avg_clim) + " °C")
  asciiwrite(stat_file, "==========================================================")
  
  print("Statistics written to: " + stat_file)
  
;=======================================================================
; CREATE SPATIAL DISTRIBUTION PLOTS
;=======================================================================

  print("Creating spatial distribution plots...")
  
  wks = gsn_open_wks("png", output_dir + plot_prefix + "_spatial")
  
  ; Set resources for all plots
  res = True
  res@gsnDraw  = False
  res@gsnFrame = False
  res@gsnAddCyclic = True
  
  res@cnFillOn = True
  res@cnLinesOn = False
  res@cnLineLabelsOn = False
  res@cnFillPalette = "BlueWhiteOrangeRed"
  res@cnLevelSelectionMode = "ManualLevels"
  res@cnFillMode = "RasterFill"
  res@cnRasterSmoothingOn = False
  
  res@mpProjection = "Robinson"
  res@mpCenterLonF = 180.0
  res@mpPerimOn = False
  res@mpGridLineColor = "transparent"
  res@mpFillOn = True
  res@mpLandFillColor = "gray75"
  res@mpOceanFillColor = "transparent"
  
  res@lbOrientation = "horizontal"
  res@lbLabelFontHeightF = 0.012
  res@pmLabelBarWidthF = 0.6
  
  res@gsnLeftString = ""
  res@gsnRightString = ""
  res@tiMainFontHeightF = 0.018
  
  ; Model SST plot
  res@cnMinLevelValF = -2.0
  res@cnMaxLevelValF = 30.0
  res@cnLevelSpacingF = 2.0
  res@tiMainString = "TaiESM TIMCOM Mean SST (" + start_year + "-" + end_year + ")"
  plot1 = gsn_csm_contour_map(wks, sst_model_mean, res)
  
  ; Observational SST plot
  res@tiMainString = "HadISST Mean SST (" + start_year + "-" + end_year + ")"
  plot2 = gsn_csm_contour_map(wks, sst_obs_mean, res)
  
  ; Difference plot
  res@cnFillPalette = "BlueRed"
  res@cnMinLevelValF = -5.0
  res@cnMaxLevelValF = 5.0
  res@cnLevelSpacingF = 0.5
  res@tiMainString = "SST Difference (Model - Obs)"
  plot3 = gsn_csm_contour_map(wks, sst_diff, res)
  
  ; Panel plots
  pres = True
  pres@gsnMaximize = True
  pres@gsnPanelLabelBar = False
  gsn_panel(wks, (/plot1, plot2, plot3/), (/3,1/), pres)
  
  print("Spatial plots created: " + output_dir + plot_prefix + "_spatial.png")
  
;=======================================================================
; CREATE TIME SERIES PLOTS
;=======================================================================

  print("Creating time series plots...")
  
  wks_ts = gsn_open_wks("png", output_dir + plot_prefix + "_timeseries")
  
  ; Resources for time series
  res_ts = True
  res_ts@gsnDraw  = False
  res_ts@gsnFrame = False
  
  res_ts@xyLineThicknessF = 2.5
  res_ts@xyLineColors = (/"red", "blue"/)
  res_ts@xyDashPatterns = (/0, 0/)
  
  ; Set X-axis labels intelligently based on time range
  nyears_plot = end_year - start_year + 1
  
  if (nyears_plot .le. 30) then
    ; Show every year for short periods
    res_ts@tmXBMode = "Explicit"
    res_ts@tmXBValues = year_array
    res_ts@tmXBLabels = year_array
    res_ts@tmXBLabelAngleF = 45
  else if (nyears_plot .le. 50) then
    ; Show every 5 years for medium periods
    year_stride = 5
    n_labels = (nyears_plot / year_stride) + 1
    year_labels = ispan(start_year, end_year, year_stride)
    res_ts@tmXBMode = "Explicit"
    res_ts@tmXBValues = year_labels
    res_ts@tmXBLabels = year_labels
    res_ts@tmXBLabelAngleF = 0
  else
    ; Show every 10 years for long periods (>50 years)
    year_stride = 10
    n_labels = (nyears_plot / year_stride) + 1
    year_labels = ispan(start_year, end_year, year_stride)
    res_ts@tmXBMode = "Explicit"
    res_ts@tmXBValues = year_labels
    res_ts@tmXBLabels = year_labels
    res_ts@tmXBLabelAngleF = 0
  end if
  end if
  
  res_ts@tmXBLabelFontHeightF = 0.012
  res_ts@tmYLLabelFontHeightF = 0.012
  
  res_ts@tiYAxisString = "Temperature (°C)"
  res_ts@tiXAxisString = "Year"
  res_ts@tiMainFontHeightF = 0.020
  
  res_ts@pmLegendDisplayMode = "Always"
  res_ts@pmLegendSide = "Top"
  res_ts@pmLegendParallelPosF = 0.75
  res_ts@pmLegendOrthogonalPosF = -0.4
  res_ts@pmLegendWidthF = 0.15
  res_ts@pmLegendHeightF = 0.10
  res_ts@lgLabelFontHeightF = 0.015
  res_ts@lgPerimOn = False
  res_ts@xyExplicitLegendLabels = (/"TaiESM", "HadISST"/)
  
  ; Annual mean SST time series
  res_ts@tiMainString = "Annual Global Mean SST"
  data_ts = new((/2, nyears/), double)
  data_ts(0,:) = (/sst_model_annual/)
  data_ts(1,:) = (/sst_obs_annual/)
  plot_ts1 = gsn_csm_xy(wks_ts, year_array, data_ts, res_ts)
  
  ; Volume-averaged temperature
  delete(res_ts@xyLineColors)
  delete(res_ts@xyExplicitLegendLabels)
  res_ts@xyLineColors = "darkgreen"
  res_ts@tiMainString = "Annual Volume-Averaged Ocean Temperature"
  res_ts@pmLegendDisplayMode = "Never"
  plot_ts2 = gsn_csm_xy(wks_ts, year_array, vol_avg_annual, res_ts)
  
  ; Panel time series plots
  pres_ts = True
  pres_ts@gsnMaximize = True
  gsn_panel(wks_ts, (/plot_ts1, plot_ts2/), (/2,1/), pres_ts)
  
  print("Time series plots created: " + output_dir + plot_prefix + "_timeseries.png")
  
;=======================================================================
; CLEANUP AND FINISH
;=======================================================================

  print("Analysis complete!")
  print("Output files:")
  print("  - " + output_dir + plot_prefix + "_spatial.png")
  print("  - " + output_dir + plot_prefix + "_timeseries.png")
  print("  - " + stat_file)

end
