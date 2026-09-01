% =========================================================================
% Mapping_Sentinel-1.m
%
% Description
% -------------------------------------------------------------------------
% Convert preprocessed Sentinel-1 SAR data from the original irregular
% satellite geometry to a regular longitude-latitude grid for DeepLabV3
% training and inference.
%
% The input Sentinel-1 scene is assumed to have been preprocessed in
% ESA SNAP using:
%
%   1. Subset Extraction
%   2. Thermal Noise Removal
%   3. Border Noise Removal
%   4. Radiometric Calibration
%   5. Refined Lee Speckle Filtering
%   6. Sigma0 VV Conversion (dB)
%   7. Land Masking
%
% Input NetCDF variables
% -------------------------------------------------------------------------
% lon            : longitude grid
% lat            : latitude grid
% Sigma0_VV_db   : Sigma0 VV backscatter (dB)
%
% Processing Steps
% -------------------------------------------------------------------------
% 1. Load Sentinel-1 longitude, latitude, and Sigma0 VV data.
% 2. Automatically determine the scene extent.
% 3. Generate a regular geographic grid.
% 4. Map irregular Sentinel-1 pixels onto the regular grid using
%    nearest-neighbor search (knnsearch).
% 5. Remove pixels located beyond the maximum mapping distance.
% 6. Export xx, yy, and sigma_naught for DeepLabV3 processing.
%
% Output Variables
% -------------------------------------------------------------------------
% xx            : longitude grid
% yy            : latitude grid
% sigma_naught  : mapped Sigma0 VV image (dB)
%
% Output MAT File
% -------------------------------------------------------------------------
% *.mat containing:
%
%   xx
%   yy
%   sigma_naught
%
% The generated MAT file is directly compatible with:
%
%   inference_sentinel1.py
%   visualize_georeferenced_result.py
%
% Author
% -------------------------------------------------------------------------
% Jinho Lee
% Seoul National University
% Satellite Oceanography Laboratory
% =========================================================================

clc;clear all;
% Area 
addpath(genpath('C:\Users\jinho\Documents\MATLAB\Sentinel'))
addpath(genpath('C:\Users\jinho\Documents\satellite imagery'))

%fl = ls('*.nc');

%for k = 1  % 1:size(fl,1)

    % file_name
    %fn = fl(k,:);
    fn = 'Incheon_small1_subset_5_of_S1A_IW_GRDH_1SDV_20250501T093222_20250501T093247_058999_075136_7928_tnr_Bdr_Cal.nc';
    
    % load variables (lon,lat) --> (lat,lon)
    lon_r = ncread(fn,'xx'); lon_r = lon_r'; % longitude (deg)
                             % lon_rr = lon_r' setting!!!!!!!!!
    lat_r = ncread(fn,'yy'); lat_r = lat_r'; % latitude (deg) 
    %incident_angle_r=ncread(fn,'incident_angle'); incident_angle_r=incident_angle_r';
    sigma_naught_r=ncread(fn,'sigma_naught'); sigma_naught_r=sigma_naught_r';

    %% automatically determine lat/lon range
    lon_min = min(lon_r(:));
    lon_max = max(lon_r(:));
    
    lat_min = min(lat_r(:));
    lat_max = max(lat_r(:));

    lat_mid = (lat_min + lat_max)/2;
    
    %% grid interval
    interv = 10/(2*pi*6400*1000*cos(lat_mid*pi/180)/360);

    %% margin
    lon_str = lon_min - 5*interv;
    lon_end = lon_max + 5*interv;
    
    lat_str = lat_min - 5*interv;
    lat_end = lat_max + 5*interv;


    % data cropping
    [loc_lat,loc_lon] = find(lon_r >= lon_str & lon_r <= lon_end & lat_r >= lat_str & lat_r <= lat_end); % find the location 
    loc_lon_1 = min(loc_lon(:)); loc_lon_2 = max(loc_lon(:));
    loc_lat_1 = min(loc_lat(:)); loc_lat_2 = max(loc_lat(:));

    lon_crop = lon_r(loc_lat_1:loc_lat_2, loc_lon_1:loc_lon_2);
    lat_crop = lat_r(loc_lat_1:loc_lat_2, loc_lon_1:loc_lon_2); 

    [xx,yy] = meshgrid(lon_min:interv:lon_max,lat_min:interv:lat_max);

    %% find nearest location with distance
    [idx_loc, D] = knnsearch([lon_crop(:) lat_crop(:)], [xx(:) yy(:)]);
    
    % 허용 최대 거리 설정
    % interv는 격자 간격이므로, 대각선 거리 정도까지만 허용
    maxDist = sqrt(2) * interv * 1.5;
    
    valid_map = D <= maxDist;
    
    %% band data mapping - incident angle
    %incident_crop = incident_angle_r(loc_lat_1:loc_lat_2, loc_lon_1:loc_lon_2);
    %incident_tmp = incident_crop(idx_loc);
    
    %incident_tmp(~valid_map) = NaN;
    
    %incident_angle = reshape(incident_tmp, size(xx));
    
    %% band data mapping - sigma naught
    sigma_crop = sigma_naught_r(loc_lat_1:loc_lat_2, loc_lon_1:loc_lon_2);
    sigma_tmp = sigma_crop(idx_loc);
    
    sigma_tmp(~valid_map) = NaN;
    
    sigma_naught = reshape(sigma_tmp, size(xx));

    % change of variable name
    lon_ref = xx;
    lat_ref = yy;

    %xw = lon_ref(1,:); yw = lat_ref(:,1); yw = yw';

    fn_save = fn(1:end-3);
    save(fn_save,'xx', 'yy','sigma_naught') 
%end
