;========================================================================
; NCL Script: Sea Ice Concentration Analysis (1979-2005)
;========================================================================

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin

;========================================
; CONFIGURATION
;========================================

print("========================================")
print("Sea Ice Analysis - Final Version")
print("========================================")

model_dir = "/work/u5865217/HW1/MOD/B1850_TAI/ice/hist/"
obs_dir   = "/work/u5865217/HW1/OBS/OBS/"
output_dir = "./"
output_type = "png"

climo_year_start = 1979
climo_year_end = 2005
start_year = 129
end_year   = 155

obs_file_nh = obs_dir + "seaice_conc_monthly_nh_NOAA_NSIDC_CDR.v03r01.197811-201702.nc"
obs_file_sh = obs_dir + "seaice_conc_monthly_sh_NOAA_NSIDC_CDR.v03r01.197811-201702.nc"

sic_threshold = 15.0

;========================================
; FUNCTION - CALCULATE SIA
;========================================

undef("calculate_sia")
function calculate_sia(aice[*][*]:numeric, tarea[*][*]:numeric, \
                       lat[*][*]:numeric, hemisphere:string, threshold:numeric)
local sia, mask, aice_masked
begin
    if (hemisphere .eq. "NH") then
        mask = where(lat .gt. 0, 1, 0)
    else
        mask = where(lat .lt. 0, 1, 0)
    end if
    
    aice_masked = where(aice .ge. threshold, 1.0, 0.0)
    aice_masked = aice_masked * mask
    sia = sum(aice_masked * tarea)
    
    return(sia)
end

;========================================
; LOAD MODEL DATA
;========================================

print("")
print("Loading model data...")

nyears = end_year - start_year + 1
nmonths_total = nyears * 12

fname_test = model_dir + "B1850_TAI.cice.h." + sprinti("%04i", start_year) + "-01.nc"

if (.not. fileexists(fname_test)) then
    print("ERROR: File not found")
    exit()
end if

f_test = addfile(fname_test, "r")
tarea = f_test->tarea
tlat  = f_test->TLAT
tlon  = f_test->TLON
tmask = f_test->tmask
dims = dimsizes(tlat)
nj = dims(0)
ni = dims(1)
delete(f_test)

print("  Grid: nj=" + nj + ", ni=" + ni)

; Handle NaN
nan_lat = num(ismissing(tlat))
nan_lon = num(ismissing(tlon))

if (nan_lat .gt. 0) then
    print("  Filling " + nan_lat + " NaN in latitude...")
    tlat = linmsg(tlat, 0)
    if (any(ismissing(tlat))) then
        do i = 0, nj-1
            do j = 0, ni-1
                if (ismissing(tlat(i,j))) then
                    if (i .gt. 0 .and. .not. ismissing(tlat(i-1,j))) then
                        tlat(i,j) = tlat(i-1,j)
                    else if (j .gt. 0 .and. .not. ismissing(tlat(i,j-1))) then
                        tlat(i,j) = tlat(i,j-1)
                    end if
                    end if
                end if
            end do
        end do
    end if
end if

if (nan_lon .gt. 0) then
    print("  Filling " + nan_lon + " NaN in longitude...")
    tlon = linmsg(tlon, 0)
    if (any(ismissing(tlon))) then
        do i = 0, nj-1
            do j = 0, ni-1
                if (ismissing(tlon(i,j))) then
                    if (i .gt. 0 .and. .not. ismissing(tlon(i-1,j))) then
                        tlon(i,j) = tlon(i-1,j)
                    else if (j .gt. 0 .and. .not. ismissing(tlon(i,j-1))) then
                        tlon(i,j) = tlon(i,j-1)
                    end if
                    end if
                end if
            end do
        end do
    end if
end if

mask_pole = where(tlat .ge. 84.0, 1, 0)
print("  Pole hole points: " + num(mask_pole .eq. 1))

aice_all = new((/nmonths_total, nj, ni/), float)
sia_nh_monthly = new(nmonths_total, float)
sia_sh_monthly = new(nmonths_total, float)

time_counter = 0

print("  Reading files...")

do year = start_year, end_year
    do month = 1, 12
        fname = model_dir + "B1850_TAI.cice.h." + sprinti("%04i", year) + \
                "-" + sprinti("%02i", month) + ".nc"
        
        if (fileexists(fname)) then
            f = addfile(fname, "r")
            aice_tmp = f->aice(0, :, :)
            
            FillValue = aice_tmp@_FillValue
            aice_tmp = where(aice_tmp .eq. 0, FillValue, aice_tmp)
            aice_tmp = where(aice_tmp .gt. 100, FillValue, aice_tmp)
            aice_tmp = where(aice_tmp .lt. 0, FillValue, aice_tmp)
            
            if (num(mask_pole .eq. 1 .and. ismissing(aice_tmp)) .gt. 0) then
                aice_tmp = where(mask_pole .eq. 1 .and. ismissing(aice_tmp), \
                                100.0, aice_tmp)
            end if
            
            aice_tmp = where(ismissing(aice_tmp), 0.0, aice_tmp)
            
            aice_all(time_counter, :, :) = aice_tmp
            
            sia_nh_monthly(time_counter) = calculate_sia(aice_tmp, tarea, tlat, "NH", sic_threshold)
            sia_sh_monthly(time_counter) = calculate_sia(aice_tmp, tarea, tlat, "SH", sic_threshold)
            
            if (mod(time_counter, 60) .eq. 0) then
                print("    Month " + time_counter)
            end if
            
            delete([/f, aice_tmp/])
            time_counter = time_counter + 1
        end if
    end do
end do

print("  Processed " + time_counter + " files")

;========================================
; CLIMATOLOGY
;========================================

print("")
print("Calculating climatology...")

aice_mean = dim_avg_n(aice_all, 0)

; Set coordinates
aice_mean@lat2d = tlat
aice_mean@lon2d = tlon
aice_mean@units = "%"
aice_mean@long_name = "Sea Ice Concentration"

; CRITICAL FIX: Handle data at boundaries
; Replace very small values with missing to avoid white gaps
aice_mean = where(aice_mean .lt. 0.1, aice_mean@_FillValue, aice_mean)

;========================================
; ANNUAL MEAN SIA
;========================================

print("")
print("Calculating annual SIA...")

sia_annual_nh_model = new(nyears, float)
sia_annual_sh_model = new(nyears, float)

do iyear = 0, nyears - 1
    istart = iyear * 12
    iend = istart + 11
    sia_annual_nh_model(iyear) = avg(sia_nh_monthly(istart:iend))
    sia_annual_sh_model(iyear) = avg(sia_sh_monthly(istart:iend))
end do

years = ispan(climo_year_start, climo_year_end, 1)

print("  Model SIA (10^12 m^2):")
print("    NH: " + sprintf("%6.2f", avg(sia_annual_nh_model)/1e12))
print("    SH: " + sprintf("%6.2f", avg(sia_annual_sh_model)/1e12))

;========================================
; OBSERVATIONS
;========================================

print("")
print("Loading observations...")

sia_annual_nh_obs = new(nyears, float)
sia_annual_sh_obs = new(nyears, float)
sia_annual_nh_obs = sia_annual_nh_obs@_FillValue
sia_annual_sh_obs = sia_annual_sh_obs@_FillValue

time_idx_start = 0
time_idx_end = 0
nmonths_obs = 0

; NH obs
if (fileexists(obs_file_nh)) then
    print("  NH obs...")
    f_obs_nh = addfile(obs_file_nh, "r")
    
    sic_obs_nh = f_obs_nh->SIC
    area_obs_nh = f_obs_nh->AREA
    time_obs = f_obs_nh->time
    lat_obs_nh = f_obs_nh->latitude
    
    time_units = "days since 1601-01-01 00:00:00"
    time_start_obs = cd_inv_calendar(climo_year_start, 1, 1, 0, 0, 0, time_units, 0)
    time_end_obs = cd_inv_calendar(climo_year_end, 12, 31, 23, 59, 59, time_units, 0)
    
    idx_s = ind(time_obs .ge. time_start_obs)
    idx_e = ind(time_obs .le. time_end_obs)
    
    if (.not. all(ismissing(idx_s)) .and. .not. all(ismissing(idx_e))) then
        time_idx_start = idx_s(0)
        time_idx_end = idx_e(dimsizes(idx_e) - 1)
        
        sic_obs_nh_period = sic_obs_nh(time_idx_start:time_idx_end, :, :)
        sic_obs_nh_period = sic_obs_nh_period * 100.0
        area_obs_nh = area_obs_nh * 1.0e6
        
        mask_pole_obs = where(lat_obs_nh .ge. 84.0, 1, 0)
        nmonths_obs = dimsizes(sic_obs_nh_period(:, 0, 0))
        
        do itime = 0, nmonths_obs - 1
            sic_obs_nh_period(itime, :, :) = where(mask_pole_obs .eq. 1 .and. \
                                                    ismissing(sic_obs_nh_period(itime, :, :)), \
                                                    100.0, sic_obs_nh_period(itime, :, :))
        end do
        
        sic_obs_nh_period = where(ismissing(sic_obs_nh_period), 0.0, sic_obs_nh_period)
        
        sia_monthly_nh_obs = new(nmonths_obs, float)
        
        do itime = 0, nmonths_obs - 1
            sic_tmp = sic_obs_nh_period(itime, :, :)
            sic_tmp = where(sic_tmp .ge. sic_threshold, 1.0, 0.0)
            sia_monthly_nh_obs(itime) = sum(sic_tmp * area_obs_nh)
            delete(sic_tmp)
        end do
        
        nyears_obs = nmonths_obs / 12
        sia_annual_nh_obs_tmp = new(nyears_obs, float)
        
        do iyear = 0, nyears_obs - 1
            istart = iyear * 12
            iend = istart + 11
            sia_annual_nh_obs_tmp(iyear) = avg(sia_monthly_nh_obs(istart:iend))
        end do
        
        sia_annual_nh_obs = sia_annual_nh_obs_tmp
        
        print("    NH Obs: " + sprintf("%6.2f", avg(sia_annual_nh_obs)/1e12) + " x 10^12 m^2")
        
        delete([/f_obs_nh, sic_obs_nh, sic_obs_nh_period, sia_annual_nh_obs_tmp/])
    end if
    
    delete([/idx_s, idx_e/])
end if

; SH obs
if (fileexists(obs_file_sh)) then
    print("  SH obs...")
    f_obs_sh = addfile(obs_file_sh, "r")
    
    sic_obs_sh = f_obs_sh->SIC
    area_obs_sh = f_obs_sh->AREA
    
    sic_obs_sh_period = sic_obs_sh(time_idx_start:time_idx_end, :, :)
    sic_obs_sh_period = sic_obs_sh_period * 100.0
    area_obs_sh = area_obs_sh * 1.0e6
    
    sic_obs_sh_period = where(ismissing(sic_obs_sh_period), 0.0, sic_obs_sh_period)
    
    sia_monthly_sh_obs = new(nmonths_obs, float)
    
    do itime = 0, nmonths_obs - 1
        sic_tmp = sic_obs_sh_period(itime, :, :)
        sic_tmp = where(sic_tmp .ge. sic_threshold, 1.0, 0.0)
        sia_monthly_sh_obs(itime) = sum(sic_tmp * area_obs_sh)
        delete(sic_tmp)
    end do
    
    sia_monthly_sh_obs = where(sia_monthly_sh_obs .lt. 2.0e12, \
                                sia_monthly_sh_obs@_FillValue, \
                                sia_monthly_sh_obs)
    
    sia_annual_sh_obs_tmp = new(nyears_obs, float)
    
    do iyear = 0, nyears_obs - 1
        istart = iyear * 12
        iend = istart + 11
        sia_annual_sh_obs_tmp(iyear) = avg(sia_monthly_sh_obs(istart:iend))
    end do
    
    sia_annual_sh_obs = sia_annual_sh_obs_tmp
    
    print("    SH Obs: " + sprintf("%6.2f", avg(sia_annual_sh_obs)/1e12) + " x 10^12 m^2")
    
    delete([/f_obs_sh, sic_obs_sh, sic_obs_sh_period, sia_annual_sh_obs_tmp/])
end if

;========================================
; STATISTICS
;========================================

print("")
print("========================================")
print("STATISTICS")
print("========================================")

print("Northern Hemisphere:")
print("  Model: " + sprintf("%6.2f", avg(sia_annual_nh_model)/1e12) + " x 10^12 m^2")

if (.not. all(ismissing(sia_annual_nh_obs))) then
    bias_nh = avg(sia_annual_nh_model - sia_annual_nh_obs)
    rmse_nh = sqrt(avg((sia_annual_nh_model - sia_annual_nh_obs)^2))
    corr_nh = escorc(sia_annual_nh_model, sia_annual_nh_obs)
    
    print("  Obs:   " + sprintf("%6.2f", avg(sia_annual_nh_obs)/1e12) + " x 10^12 m^2")
    print("  Bias:  " + sprintf("%6.2f", bias_nh/1e12) + " x 10^12 m^2")
    print("  RMSE:  " + sprintf("%6.2f", rmse_nh/1e12) + " x 10^12 m^2")
    print("  Corr:  " + sprintf("%6.3f", corr_nh))
else
    print("  Obs:   N/A")
end if

print("")
print("Southern Hemisphere:")
print("  Model: " + sprintf("%6.2f", avg(sia_annual_sh_model)/1e12) + " x 10^12 m^2")

if (.not. all(ismissing(sia_annual_sh_obs))) then
    bias_sh = avg(sia_annual_sh_model - sia_annual_sh_obs)
    rmse_sh = sqrt(avg((sia_annual_sh_model - sia_annual_sh_obs)^2))
    corr_sh = escorc(sia_annual_sh_model, sia_annual_sh_obs)
    
    print("  Obs:   " + sprintf("%6.2f", avg(sia_annual_sh_obs)/1e12) + " x 10^12 m^2")
    print("  Bias:  " + sprintf("%6.2f", bias_sh/1e12) + " x 10^12 m^2")
    print("  RMSE:  " + sprintf("%6.2f", rmse_sh/1e12) + " x 10^12 m^2")
    print("  Corr:  " + sprintf("%6.3f", corr_sh))
else
    print("  Obs:   N/A")
end if

;========================================
; IMPROVED SPATIAL PLOTS
;========================================

print("")
print("Creating spatial plots...")

wks = gsn_open_wks(output_type, output_dir + "Figure10_Mean_SIC_1979-2005")

; Resources
res = True
res@gsnDraw = False
res@gsnFrame = False
res@gsnAddCyclic = False

; Contour
res@cnFillOn = True
res@cnLinesOn = False
res@cnLineLabelsOn = False
res@cnFillMode = "RasterFill"
res@cnRasterSmoothingOn = True  ; SMOOTH!
res@cnLevelSelectionMode = "ExplicitLevels"
res@cnLevels = (/10, 20, 30, 40, 50, 60, 70, 80, 90, 100/)
res@cnFillColors = (/2, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200/)  ; Rainbow colors
res@cnMissingValFillColor = -1  ; Transparent

; Colorbar
res@lbLabelBarOn = True
res@lbOrientation = "Vertical"
res@pmLabelBarWidthF = 0.05
res@pmLabelBarHeightF = 0.5
res@lbLabelFontHeightF = 0.010
res@lbPerimOn = False

; Map
res@mpFillOn = True
res@mpLandFillColor = "gray50"
res@mpOceanFillColor = -1  ; Transparent
res@mpOutlineOn = True
res@mpGeophysicalLineColor = "black"
res@mpGeophysicalLineThicknessF = 0.5
res@mpGridAndLimbOn = False  ; Remove grid to avoid confusion

; Coordinates
res@sfXArray = tlon
res@sfYArray = tlat
res@trGridType = "TriangularMesh"

; Get colormap
gsn_define_colormap(wks, "rainbow")

; NH
res@gsnPolar = "NH"
res@mpMinLatF = 40
res@tiMainString = "Mean SIC (1979-2005) - NH"
res@tiMainFontHeightF = 0.016
plot_nh = gsn_csm_contour_map_polar(wks, aice_mean, res)

; SH
res@gsnPolar = "SH"
delete(res@mpMinLatF)
res@mpMaxLatF = -40
res@tiMainString = "Mean SIC (1979-2005) - SH"
plot_sh = gsn_csm_contour_map_polar(wks, aice_mean, res)

; Panel
pres = True
pres@gsnMaximize = True
pres@gsnPanelFigureStrings = (/"(a) Northern Hemisphere", "(b) Southern Hemisphere"/)
pres@gsnPanelFigureStringsFontHeightF = 0.012
pres@txString = "Figure 10: Mean SIC (1979-2005)"
pres@txFontHeightF = 0.018

gsn_panel(wks, (/plot_nh, plot_sh/), (/2, 1/), pres)

print("  Saved")

;========================================
; TIME SERIES
;========================================

print("Creating time series...")

wks_ts = gsn_open_wks(output_type, output_dir + "Figure11_Annual_SIA_1979-2005")

res_ts = True
res_ts@gsnDraw = False
res_ts@gsnFrame = False
res_ts@gsnMaximize = True

res_ts@tiMainString = "Annual Mean SIA (1979-2005)"
res_ts@tiXAxisString = "Year"
res_ts@tiYAxisString = "Sea Ice Area (10~S~12~N~ m~S~2~N~)"

res_ts@xyLineThicknesses = (/3, 3, 3, 3/)
res_ts@xyLineColors = (/"blue", "red", "blue", "red"/)
res_ts@xyDashPatterns = (/0, 0, 2, 2/)

res_ts@pmLegendDisplayMode = "Always"
res_ts@pmLegendSide = "Top"
res_ts@pmLegendParallelPosF = 0.75
res_ts@pmLegendOrthogonalPosF = -0.4
res_ts@pmLegendWidthF = 0.15
res_ts@pmLegendHeightF = 0.10
res_ts@lgLabelFontHeightF = 0.014
res_ts@lgPerimOn = True
res_ts@xyExplicitLegendLabels = (/"NH Model", "SH Model", "NH Obs", "SH Obs"/)

res_ts@trXMinF = climo_year_start
res_ts@trXMaxF = climo_year_end
res_ts@tmXBMode = "Explicit"
res_ts@tmXBValues = ispan(1980, 2005, 5)
res_ts@tmXBLabels = ispan(1980, 2005, 5)

res_ts@tmXMajorGrid = True
res_ts@tmYMajorGrid = True
res_ts@tmXMajorGridLineColor = "gray70"
res_ts@tmYMajorGridLineColor = "gray70"

data_plot = new((/4, nyears/), float)
data_plot(0, :) = sia_annual_nh_model / 1.0e12
data_plot(1, :) = sia_annual_sh_model / 1.0e12
data_plot(2, :) = sia_annual_nh_obs / 1.0e12
data_plot(3, :) = sia_annual_sh_obs / 1.0e12

plot_ts = gsn_csm_xy(wks_ts, years, data_plot, res_ts)

draw(plot_ts)
frame(wks_ts)

print("  Saved")

print("")
print("========================================")
print("COMPLETE!")
print("========================================")

end
