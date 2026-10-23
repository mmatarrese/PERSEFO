% Run feature extraction for a single subject using Brainstorm output files.
% Set patient_folder to the Brainstorm results folder containing the AEC
% connectivity matrix (*henv*.mat) and the 1/f-compensated PSD (*multiply*.mat).
% MATLAB will change its current working directory to patient_folder.
% Required MATLAB products: MATLAB R2016a or later (graph, minspantree,
% distances, centrality) and Statistics and Machine Learning Toolbox
% (dataset, nanmean, nanmedian, and nanmax).
% Required external code: Brainstorm (process_compress_sym.m, used by
% functions/GetConnectMatrix.m) and the Brain Connectivity Toolbox functions
% included in the functions folder.
% Brainstorm must be on the MATLAB path before running this script.
% Change sub_name below to the ID of the subject being analyzed.
% Run the whole script (Run/F5 or run(...)), not section by section: the
% functions folder is located from the script's own path.

addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cd(patient_folder)
%%
sub_name = 'C1_001';
EC = dir('*henv*');
for i = 1:length(EC)
    tmp = load(EC(i).name, 'DisplayUnits');
    if strcmp(tmp.DisplayUnits, 'Envelope correlation')
        AEC = load(EC(i).name);
    end
end
assert(exist('AEC', 'var') == 1, 'No *henv* file with DisplayUnits ''Envelope correlation'' found.');
assert(isequal(AEC.RowNames(:), AEC.RefRowNames(:)), 'AEC: RowNames and RefRowNames differ.');

ID_rep = repmat(sub_name, 19, 1);
channel_labels = AEC.RowNames';
DB = dataset; DB.ID = ID_rep; DB.channel=channel_labels;
DB_norm = dataset; DB_norm.ID = ID_rep; DB_norm.channel=channel_labels;
FC = dataset; FC.ID = sub_name;

AEC_matrix = GetConnectMatrix(AEC);
AEC_matrix = reshape(AEC_matrix,[length(AEC.RefRowNames), length(AEC.RowNames), size(AEC.TF, 3)]);
freqband = AEC.Freqs(:,1);

for f=1:length(freqband)
    temp=AEC_matrix(:,:,f);
    % temp(1:1+size(temp,1):end) = 0;
    temp(isnan(temp))=0;
    temp(logical(eye(size(temp)))) = 0; % remove self-connections
    temp_norm = temp/max(max(temp));
    G = graph(temp_norm, 'omitselfloops');
    T = minspantree(G);
    A = full(adjacency(T, 'weighted'));
    % https://www.mathworks.com/matlabcentral/fileexchange/41963-kruskal-s-algorithm
    
    % Ground Average
    mean_FC = nanmean(temp_norm, 2);
    median_FC = nanmedian(temp_norm, 2);
    mean_MST = nanmean(A, 2);
    median_MST = nanmedian(A, 2);
    
    % Centrality Measures per node
    try
        betweenness = centrality(T,'betweenness','Cost',T.Edges.Weight);
        closeness = centrality(T,'closeness','Cost',T.Edges.Weight);
        degree = centrality(T,'degree','Importance',T.Edges.Weight);
        eigenvector = centrality(T,'eigenvector','Importance',T.Edges.Weight);
    catch
        betweenness = centrality(T,'betweenness');
        closeness = centrality(T,'closeness');
        degree = centrality(T,'degree');
        eigenvector = centrality(T,'eigenvector');
    end
    [modularity_vec, modularity] = modularity_und(temp_norm);
    part_coeff = participation_coef(temp_norm, modularity_vec);
    clust_coeff = clustering_coef_wu(temp_norm);
    flow_coeff = flow_coef_bd(temp_norm); flow_coeff = flow_coeff';
    strengths = strengths_und(temp_norm); strengths = strengths';
    
    % Centrality Measures per network
    transitivity = transitivity_bu(temp_norm);
    global_efficiency = efficiency_wei(temp_norm);
    % Characteristic path length on shortest-path distances, with
    % connection lengths 1/w for w > 0 (same convention as efficiency_wei)
    L = zeros(size(temp_norm));
    L(temp_norm > 0) = 1 ./ temp_norm(temp_norm > 0);
    D = distances(graph(L, 'omitselfloops'));
    char_path_length = charpath(D);
    
    MST(:,:,f)=A;
    FC.AEC{1,1}=AEC_matrix;
    if f==length(freqband)
        eval(['FC.AEC_MST{1,1}=MST;'])
    end
    eval(['FC.AEC_transitivity_' freqband{f,1} '(1,1) = transitivity;'])
    eval(['FC.AEC_globalefficiency_' freqband{f,1} '(1,1) = global_efficiency;'])
    eval(['FC.AEC_charpath_' freqband{f,1} '(1,1) = char_path_length;'])
    eval(['FC.AEC_modularity_' freqband{f,1} '(1,1) = modularity;'])
    
    eval(['DB.AEC_betweenness_' freqband{f,1} '= betweenness;'])
    eval(['DB.AEC_closeness_' freqband{f,1} '= closeness;'])
    eval(['DB.AEC_degree_' freqband{f,1} '= degree;'])
    eval(['DB.AEC_eigenvector_' freqband{f,1} '= eigenvector;'])
    eval(['DB.AEC_partcoeff_' freqband{f,1} '= part_coeff;'])
    eval(['DB.AEC_clustcoeff_' freqband{f,1} '= clust_coeff;'])
    eval(['DB.AEC_strengths_' freqband{f,1} '= strengths;'])
    eval(['DB.AEC_module_' freqband{f,1} '= modularity_vec;'])
    eval(['DB.AEC_meanFC_' freqband{f,1} '= mean_FC;'])
    eval(['DB.AEC_medianFC_' freqband{f,1} '= median_FC;'])
    eval(['DB.AEC_meanMST_' freqband{f,1} '= mean_MST;'])
    
    eval(['DB_norm.AEC_betweenness_' freqband{f,1} '= betweenness/nanmax(betweenness);'])
    eval(['DB_norm.AEC_closeness_' freqband{f,1} '= closeness/nanmax(closeness);'])
    eval(['DB_norm.AEC_degree_' freqband{f,1} '= degree/nanmax(degree);'])
    eval(['DB_norm.AEC_eigenvector_' freqband{f,1} '= eigenvector/nanmax(eigenvector);'])
    eval(['DB_norm.AEC_partcoeff_' freqband{f,1} '= part_coeff/nanmax(part_coeff);'])
    eval(['DB_norm.AEC_clustcoeff_' freqband{f,1} '= clust_coeff/nanmax(clust_coeff);'])
    eval(['DB_norm.AEC_strengths_' freqband{f,1} '= strengths/nanmax(strengths);'])
    eval(['DB_norm.AEC_module_' freqband{f,1} '= modularity_vec;'])
    eval(['DB_norm.AEC_meanFC_' freqband{f,1} '= mean_FC;']) % Normalization not performed otherwise mean of this vector won't be the FC gound average anymore
    eval(['DB_norm.AEC_medianFC_' freqband{f,1} '= median_FC;'])
    eval(['DB_norm.AEC_meanMST_' freqband{f,1} '= mean_MST;'])
    
    % Spectral Analysis
    psdensity=dir('*multiply*'); psdensity=load(psdensity.name);
    assert(isequal(psdensity.RowNames(:), AEC.RowNames(:)), 'Channel order differs between PSD and AEC files.');
    freq_vec = round(psdensity.Freqs);
    
    spectrum = squeeze(psdensity.TF);
    spectrum_log = 10*log10(spectrum);
    spectrum_mag = sqrt(spectrum);
    %names = {'spectrum'; 'logspectrum'; 'magspectrum'};
    names = {'spectrum'; 'spectrum_log'; 'spectrum_mag'};
    freq_vec = round(psdensity.Freqs);
    delta = [2, 4];     theta = [5, 7];     alpha = [8, 12];
    beta = [15, 29];    gamma = [30, 59];   spike = [1, 60];
    Freqs = {'delta';'theta';'alpha';'beta';'gamma';'spike'};
    
    for c=1:length(names)
        eval(['temp =' names{c,1} ';'])
        for f=1:length(Freqs)
            
            eval(['[~,first] = ismember(' Freqs{f} '(1), freq_vec);'])
            eval(['[~,last] = ismember(' Freqs{f} '(2), freq_vec);'])
            max_total = max(max(temp));
            max_freqband = max(max(temp(:,first:last)));
            mean_temp = nanmean(temp(:,first:last),2);
            median_temp = nanmedian(temp(:,first:last),2);
            [max_temp, b] = nanmax(temp(:,first:last)');
            max_temp = max_temp';
            temp_freq = freq_vec(first:last);
            max_freq = temp_freq(b)';
            
            eval(['FC.' names{c,1} '{1,1} = temp;'])
            eval(['FC.' names{c,1} '_max' '(1,1) = max_total;'])
            eval(['FC.' names{c,1} '_max_' Freqs{f,1} '(1,1) = max_freqband;'])
            
            eval(['DB.' names{c,1} '_mean_' Freqs{f,1} '= mean_temp;'])
            eval(['DB.' names{c,1} '_median_' Freqs{f,1} '= median_temp;'])
            eval(['DB.' names{c,1} '_max_' Freqs{f,1} '= max_temp;'])
            eval(['DB.' names{c,1} '_maxfreq_' Freqs{f,1} '= max_freq;'])
            
            eval(['DB_norm.' names{c,1} '_mean_' Freqs{f,1} '= mean_temp/max(mean_temp);']) % Normalized based on the maximum value per freq band
            eval(['DB_norm.' names{c,1} '_median_' Freqs{f,1} '= median_temp/max(median_temp);'])
            eval(['DB_norm.' names{c,1} '_max_' Freqs{f,1} '= max_temp/max_total;']) % Normalized on the Global Max PSD value
            eval(['DB_norm.' names{c,1} '_maxfreq_' Freqs{f,1} '= max_freq/(' Freqs{f} '(2));'])
        end
    end
end
DB = sortrows(DB,{'ID','channel'},'ascend');
DB_norm = sortrows(DB_norm,{'ID','channel'},'ascend');

clearvars -except DB DB_norm FC
