%% Init
clc; close all; clear;

%% File mangagement
addpath(fullfile(matlabroot, 'toolbox', 'matlab', 'm_map')); % m_maps
addpath(genpath(fullfile(pwd,'scripts')));                   % used scripts
altikaFiles = 'E:\Altika';                                   % data

%% Cycle specific
cryoSatFile = 'cryoSat/cs2awi_nh_201610.nc';
velocityFile = 'velocity\20161917.n.S1Adrift.vector';
cycles = 103;

%% Fram Strait
LON = [-10, 10];
% LAT = [76, 82];
LAT = [79, 82];

% Settings for map projection
m_proj('albers equal-area', 'long', LON, 'lat', LAT, 'rectbox', 'off');

% Define fluxgate
fluxgate = initFluxgate([-8.2, 8.9], [81.4, 80], 1000);

% Init. data arrays
lon = [];
lat = [];
wave = [];
agc = [];
tracker = [];
alt = [];

modeled_instr_corr = [];
doppler_corr = [];

model_dry_tropo_corr = [];
rad_wet_tropo_corr = [];
iono_corr_gim = [];
sea_state_bias = [];

range = [];

mss = [];
ssha = [];

solidEarthTideHeight = [];
oceanTide = [];
poleTide = [];
invBarCorr = [];
HF = [];

%% Load data
for cycle = cycles
    cycleName = sprintf('cycle_%03d', cycle);
    cycleFile = fullfile(pwd,'data', strcat(cycleName, '.mat'));
    
    if exist(cycleFile, 'file') == 0
        disp('No file found, creating new.');
        % All data files
        cycleFilePath = fullfile(altikaFiles, cycleName);
        lis = dir(cycleFilePath);
        lis(1:2) = [];
        %         for j = 1:length(lis)
        for j = 1:length(lis)
            % Extraction of the filepath
            filePath = fullfile(cycleFilePath, lis(j).name);
            
            % Tmp import of Lon and Lat
            tmpLon = ncread(filePath, 'lon_40hz');
            tmpLon = rem((tmpLon + 180), 360) - 180;
            filLon = (LON(1) - 1) < tmpLon & tmpLon < (LON(2) + 1);
            tmpLat = ncread(filePath,'lat_40hz');
            filLat = (LAT(1) - 1) < tmpLat & tmpLat < (LAT(2) + 1);
            
            % Filter for earth
            filter = filLat & filLon;
            
            % Skips iteration if no useful data is detected
            if ~(any(filter(:))) || sum(filter(:)) < 5 || sum(filter(1,:)) == 1
                % fprintf('%d skipped\n', j);
                continue;
            end
            
            % Tmp import of data variables
            tmpWave = ncread(filePath, 'waveforms_40hz');
            tmpAGC = ncread(filePath, 'agc_40hz');
            tmpTracker = ncread(filePath, 'tracker_40hz');
            tmpAlt = ncread(filePath, 'alt_40hz');
            
            tmpModeled_intr_corr = ncread(filePath, 'modeled_instr_corr_range');
            tmpDoppler_corr = ncread(filePath, 'doppler_corr');
            
            tmpModel_dry_tropo_corr = ncread(filePath, 'model_dry_tropo_corr');
            tmpRad_wet_tropo_corr = ncread(filePath, 'rad_wet_tropo_corr');
            tmpIono_corr_gim = ncread(filePath, 'iono_corr_gim');
            tmpSea_state_bias = ncread(filePath, 'sea_state_bias');
            
            tmpRange = ncread(filePath, 'range_40hz');
            
            tmpMss = ncread(filePath, 'mean_sea_surface');
            tmpSsha = ncread(filePath, 'ssha');
            
            tmpSolidEarthTideHeight = ncread(filePath, 'solid_earth_tide');
            tmpOceanTide = ncread(filePath, 'ocean_tide_sol2');
            tmpPoleTide = ncread(filePath, 'pole_tide');
            tmpInvBarCorr = ncread(filePath, 'inv_bar_corr');
            tmpHF = ncread(filePath, 'hf_fluctuations_corr');
            
            tmpN = length(tmpLon(filter));
            x = linspace(1,length(tmpHF(filter(1,:))), tmpN);
            
            % Filtration of found data, saving for later use
            lon = vertcat(lon, tmpLon(filter));
            lat = vertcat(lat, tmpLat(filter));
            wave = horzcat(wave, tmpWave(:,filter));
            agc = vertcat(agc, tmpAGC(filter));
            tracker = vertcat(tracker, tmpTracker(filter));
            alt = vertcat(alt, tmpAlt(filter));
            
            modeled_instr_corr = vertcat(modeled_instr_corr, interp1(tmpModeled_intr_corr(filter(1, :)), x)');
            doppler_corr = vertcat(doppler_corr, interp1(tmpDoppler_corr(filter(1, :)), x)');
            
            model_dry_tropo_corr = vertcat(model_dry_tropo_corr, interp1(tmpModel_dry_tropo_corr(filter(1, :)), x)');
            rad_wet_tropo_corr = vertcat(rad_wet_tropo_corr, interp1(tmpRad_wet_tropo_corr(filter(1, :)), x)');
            iono_corr_gim = vertcat(iono_corr_gim, interp1(tmpIono_corr_gim(filter(1, :)), x)');
            sea_state_bias = vertcat(sea_state_bias, interp1(tmpSea_state_bias(filter(1, :)), x)');
            
            range = vertcat(range, interp1(tmpRange(filter), x)');
            
            mss = vertcat(mss, interp1(tmpMss(filter(1,:)), x)');
            ssha = vertcat(ssha, interp1(tmpSsha(filter(1,:)), x)');
            
            solidEarthTideHeight = vertcat(solidEarthTideHeight, interp1(tmpSolidEarthTideHeight(filter(1,:)), x)');
            oceanTide = vertcat(oceanTide, interp1(tmpOceanTide(filter(1,:)), x)');
            poleTide = vertcat(poleTide, interp1(tmpPoleTide(filter(1,:)), x)');
            invBarCorr = vertcat(invBarCorr, interp1(tmpInvBarCorr(filter(1,:)), x)');
            HF = vertcat(HF, interp1(tmpHF(filter(1,:)), x)');
            
            % Remove tmp variables from workspace
            clear -regexp ^tmp
                        
            % disp(j)
        end
        
        % Save variables
        save(cycleFile, 'lon', 'lat', 'wave', 'agc', ...
            'tracker', 'alt', 'modeled_instr_corr', 'doppler_corr', ...
            'model_dry_tropo_corr', 'rad_wet_tropo_corr', ...
            'iono_corr_gim', 'sea_state_bias', 'range', 'mss', 'ssha',...
            'solidEarthTideHeight', 'oceanTide', 'poleTide', ...
            'invBarCorr', 'HF');
    else
        % Load variables
        fprintf('Existing file %s has been loaded\n', cycleFile);
        load(cycleFile);
    end
    
    % Load velocities
    velocities = velocity(velocityFile, LON, LAT);
end

%% Calculate height
% Hardware variables
C_ntp = 51;
B_spc = 0.31;

% Number of data points
N = length(wave(1,:));

% Init calculated variables
C_rtrk_ocog = zeros(N, 1);
C_rtrk_pp_cog = zeros(N, 1);
mp = zeros(N,1);
pP = zeros(N,1);
W = zeros(N,1);

for i = 1:N
    C_rtrk_ocog(i) = waveformAnalysis(wave(:,i), 'OCOG');
    [C_rtrk_pp_cog(i), ~, ~, ~, W(i)] = waveformAnalysis(wave(:,i), 'PP_COG');
    mp(i) = maxPower(wave(:,i), agc(i));
    pP(i) = pulsePeakiness(wave(:,i), 128);
end

%% Correction application
% Retracked height calculated, both OCOG and PPCOG
epoch_ocog = (C_ntp - C_rtrk_ocog) * B_spc;
epoch_pp_cog = (C_ntp - C_rtrk_pp_cog) * B_spc;

% Tracker corrections
% Missing system bias
tracker_corr = modeled_instr_corr + doppler_corr;

% Corrected Altimerter Range
sea_state_bias(isnan(sea_state_bias)) = 0; % Sets NAN values to 0
alt_corr = model_dry_tropo_corr + rad_wet_tropo_corr + iono_corr_gim + ...
    sea_state_bias + tracker_corr;
correctedRange = tracker + alt_corr;

% Sea Surface Hegiht
ssh_ocog = alt - correctedRange + epoch_ocog;
ssh_pp_cog = alt - correctedRange + epoch_pp_cog;

% Sea height anomaly
sla_corr = mss + solidEarthTideHeight + oceanTide + poleTide + invBarCorr + HF;
sla_ocog = ssh_ocog - sla_corr;
sla_pp_cog = ssh_pp_cog - sla_corr;

%% Grid iterpolation
[Xq, Yq] = meshgrid(LON(1):0.01:LON(2), LAT(1):0.001:LAT(2));
sla_pp_cog_q = griddata(lon, lat, sla_pp_cog, Xq, Yq);
ssha_q = griddata(lon, lat, ssha, Xq, Yq);
pPq = griddata(lon, lat, pP, Xq, Yq);
mPq = griddata(lon, lat, mp, Xq, Yq);
Wq = griddata(lon, lat, W, Xq, Yq);
gridVelocity = gridVelocities(Xq, Yq, velocities);

% Classification
pP_class = zeros(size(Xq));
pP_class(pPq >= 30 & Wq < 2) = 4;

mP_class = zeros(size(Xq));
mP_class(mPq >= 70) = 4;

%% Mask
mask = ~isnan(ssha_q);

%% Track grid vs interp
freeboard_cryo = cryoSat(cryoSatFile, 'sea_ice_freeboard', fluxgate, LON, LAT, Xq, Yq);
thickness_cryo = cryoSat(cryoSatFile, 'sea_ice_thickness', fluxgate, LON, LAT, Xq, Yq);

fluxgate = interpProfile(fluxgate, Xq, Yq, sla_pp_cog_q, ssha_q, pPq, Wq, gridVelocity);

iceSheet = freeboardAnalysis(fluxgate);
iceSheet = thickness(iceSheet, 'radar');
normVelocities = projVelocity(fluxgate);

h_f = flattenIcesheet(fluxgate, iceSheet, 'freeboard');
h_i = flattenIcesheet(fluxgate, iceSheet, 'iceThickness');

[volFlow, flow] = calcVolFlow(fluxgate, h_i, normVelocities);
cryoFlow = calcVolFlow(fluxgate, thickness_cryo, normVelocities);
fprintf('SARAL/AltiKa: \t%3.3f cubic kilometers per day (positive is northen flow)\n', volFlow*1e-9);
fprintf('CryoSat 2: \t\t%3.3f cubic kilometers per day (positive is northen flow)\n', cryoFlow*1e-9);

%% Plot
% Primary Peak COG Map
plotSLA(Xq, Yq, sla_pp_cog_q, 'Retracked SLA');

%% Pulse Peakniss
plotLeads(Xq, Yq, pP_class);

%% Product given SLA
plotSLA(Xq, Yq, ssha_q, 'Product SLA');

%% Ice drift
plotIceDrift(Xq, Yq, sla_pp_cog_q, velocities);

%% Flow
plotFlow(fluxgate, flow);

%% Fluxgate
plotFluxgate(fluxgate,  iceSheet);

%% Fluxgate Profile
plotFluxgateProfile(Xq, Yq, sla_pp_cog_q, fluxgate);

%% Area
plotArea(LON,LAT, fluxgate);

%% CryoSat
plotCryoSat(fluxgate, h_f, freeboard_cryo, 'Freeboard');
plotCryoSat(fluxgate, h_f, thickness_cryo, 'Thickness');