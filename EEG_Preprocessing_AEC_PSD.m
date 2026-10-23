%% EEG PREPROCESSING
% A 180-second artifact-free EEG segment was manually selected from the
% original raw recordings using Brainstorm.
% Visual inspection was performed to exclude relevant artifacts and
% interictal or ictal epileptiform discharges.
%
% EEG preprocessing included DC offset removal, a 50-Hz notch filter,
% and a 1-70 Hz band-pass FIR filter with parameters shown in the following.
% Independent Component Analysis (ICA) was performed on the band-pass
% filtered EEG signal to identify and remove ocular and cardiac artifacts.
% All preprocessing steps were performed in Brainstorm.
%
% The following preprocessing commands are provided for illustrative purposes.
% These steps were already performed on the raw recordings in Brainstorm
% and should not be repeated on the preprocessed EEG data.

% Remove DC offset
sFiles = bst_process('CallProcess', 'process_baseline', sFiles, [], ...
    'baseline', [], 'sensortypes', 'EEG');

% Apply a second-order IIR notch filter at 50 Hz
% Sampling frequency: 250 Hz    
% Filter order: 4 poles
% Maximum pole magnitude: 0.98751
% Frequency response shows attenuation at 50 Hz and its harmonic (100 Hz)
% Full transient duration: 3.152 s
% Transient duration (99% energy): 0.156 s
sFiles = bst_process('CallProcess', 'process_notch', sFiles, [], ...
    'freqlist', 50, 'sensortypes', 'EEG');


% Apply a linear-phase FIR band-pass filter (Kaiser window)
% Passband: 1-70 Hz
% Sampling frequency: 250 Hz
% Filter order: 1118
% Low-frequency transition: 0.5-1 Hz
% High-frequency transition: 70-70.5 Hz
% Stopband attenuation: 40 dB
% Passband ripple: 1%
% Full transient duration: 2.236 s
% Transient duration (99% energy): 0.084 s
sFiles = bst_process('CallProcess', 'process_bandpass', sFiles, [], ...
    'highpass', 1, 'lowpass', 70, 'sensortypes', 'EEG', 'ver', '2019');

% Apply average EEG reference.
bst_process('CallProcess', 'process_eegref', sFiles, [], ...
    'eegref', 'AVERAGE', 'sensortypes', 'EEG');

% Compute ICA components for artifact correction.
% ICA components must be visually inspected and artifact-related
% components manually selected for rejection.
% This procedure was performed on the original raw EEG in Brainstorm.
bst_process('CallProcess', 'process_ica', sFiles, [], ...
    'sensortypes', 'EEG', 'method', 'picard');

% Import the corrected recordings.
sFiles = bst_process('CallProcess', 'process_import_data_time', sFiles, [], ...
    'subjectname', subjectname, 'condition', 'clean', 'usessp', 1);

%% AEC COMPUTATION
% Functional connectivity was estimated using Amplitude Envelope Correlation (AEC)
% in Brainstorm. EEG signals were filtered into five frequency bands:
% delta (2-4 Hz), theta (5-7 Hz), alpha (8-12 Hz), beta (15-29 Hz),
% and gamma (30-59 Hz).
% The Hilbert transform was applied to extract the amplitude envelopes.
% AEC was computed as the Pearson correlation between the amplitude
% envelopes of each pair of EEG channels.
% Conventional AEC without orthogonalization was used.

% Define the frequency bands.
freqbands = {'delta', '2, 4', 'mean';
             'theta', '5, 7', 'mean';
             'alpha', '8, 12', 'mean';
             'beta', '15, 29', 'mean';
             'gamma', '30, 59', 'mean'};

% Compute non-orthogonalized amplitude envelope correlation.
sAEC = bst_process('CallProcess', 'process_henv1n', sFiles, [], ...
    'cohmeasure', 'penv', ...
    'tfmeasure', 'hilbert', ...
    'tfedit', struct('Freqs', {freqbands}), ...
    'timeres', 'none', ...
    'outputmode', 'input');

%% PSD COMPUTATION AND NORMALIZATION
% Power Spectral Density (PSD) was computed in Brainstorm using Welch's method
% with 4-second windows and 50% overlap.
% PSD was estimated for each EEG channel across the frequency spectrum.
% A 1/f compensation was applied by multiplying the PSD by frequency
% using the Brainstorm normalization option 'multiply2020'.
% The resulting frequency-weighted PSD was used for spectral feature extraction.
% Compute PSD using Welch's method.

sPSD = bst_process('CallProcess', 'process_psd', sFiles, [], ...
    'sensortypes', 'EEG', ...
    'win_length', 4, ...
    'win_overlap', 50, ...
    'edit', struct('Comment', 'Power', 'TimeBands', [], ...
    'Freqs', [], 'ClusterFuncTime', 'none', ...
    'Measure', 'power', 'Output', 'all', 'SaveKernel', 0));

% Apply 1/f compensation.
sPSD_norm = bst_process('CallProcess', 'process_tf_norm', sPSD, [], ...
    'normalize', 'multiply2020', 'overwrite', 0);
