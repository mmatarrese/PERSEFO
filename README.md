# PERSEFO: single-subject EEG feature extraction

MATLAB script that extracts per-channel and network-level features for one subject from Brainstorm outputs: amplitude envelope correlation (AEC) connectivity matrices and a 1/f-normalized power spectral density (PSD).

This code accompanies the paper:

> TODO: authors, title, journal, year, DOI.

## Repository contents

```text
.
├── MAIN_Features_Extraction.m   # Feature-extraction script (one subject)
├── functions/
│   ├── GetConnectMatrix.m       # Adapted from Brainstorm (bst_memory.m)
│   ├── charpath.m               # Brain Connectivity Toolbox (BCT)
│   ├── clustering_coef_wu.m     # BCT
│   ├── efficiency_wei.m         # BCT
│   ├── flow_coef_bd.m           # BCT (called, output currently not stored)
│   ├── modularity_und.m         # BCT
│   ├── participation_coef.m     # BCT
│   ├── strengths_und.m          # BCT
│   ├── transitivity_bu.m        # BCT
│   └── BCT_LICENSE              # MIT license of brainlife/BCT
├── LICENSE                      # GPL-3.0
├── .gitignore                   # excludes data files (*.mat, *.edf, ...)
├── .gitattributes
└── README.md
```

## Requirements

- MATLAB R2016a or later (`graph`, `minspantree`, `distances`, `centrality`). Tested with: TODO.
- Statistics and Machine Learning Toolbox (`dataset`, `nanmean`, `nanmedian`, `nanmax`).
- Brainstorm, initialized in the MATLAB session, so that `process_compress_sym.m` is on the path. It is used by `functions/GetConnectMatrix.m` to expand compressed symmetric connectivity matrices. Tested with: TODO.
- The BCT functions used by the script are included in `functions/`. No separate BCT installation is needed.

PSD and AEC are computed beforehand in Brainstorm. This repository does not compute them.

## Expected inputs

Set the workspace variable `patient_folder` to the Brainstorm folder of one subject. The folder must contain:

- the AEC file: name matching `*henv*`, `DisplayUnits` equal to `Envelope correlation`;
- the orthogonalized AEC file: name matching `*henv*`, `DisplayUnits` equal to `Orthogonalized envelope correlation`. Only its channel labels are used;
- exactly one PSD file with name matching `*multiply*` (1/f-normalized PSD).

Constraints:

- 19 channels (fixed in the script).
- The three files must have the same channel order. The script checks this with `assert`.
- Every `*henv*` file in the folder must contain the `DisplayUnits` field. If more than one file has the same `DisplayUnits`, the last one found is used.
- `sub_name` is set inside the script and must be edited for each subject.

## Example run in MATLAB

```matlab
% Add Brainstorm to MATLAB and initialize it.
addpath('C:\path\to\brainstorm3');
brainstorm('server');

% Folder containing the Brainstorm connectivity and PSD files of one subject.
patient_folder = 'C:\path\to\brainstorm_results\C1_001';

% Edit sub_name in MAIN_Features_Extraction.m, then run the whole script.
run('C:\path\to\repository\MAIN_Features_Extraction.m');
```

The script first adds its own `functions/` folder to the MATLAB path, then changes the current folder to `patient_folder`. Run the whole script (Run/F5 or `run`), not section by section, because the `functions/` folder is located from the script's own path.

## Processing

### Connectivity (one iteration per band stored in the AEC file, `AEC.Freqs`)

1. NaN values are set to 0, the diagonal is set to 0, and the matrix is divided by its maximum value (`temp_norm`).
2. Minimum spanning tree (MST): `minspantree` on `graph(temp_norm)`, with normalized AEC values as edge weights.
3. Node measures on the MST (MATLAB `centrality`): betweenness and closeness with edge weights as `Cost`, degree and eigenvector with edge weights as `Importance`. If the weighted call fails, the unweighted version is used.
4. Node measures on `temp_norm` (BCT): community assignment (`modularity_und`), participation coefficient, weighted clustering coefficient, strength.
5. Network measures on `temp_norm` (BCT): modularity Q (`modularity_und`), transitivity (`transitivity_bu`), global efficiency (`efficiency_wei`), characteristic path length (`charpath` on shortest-path distances, with connection length 1/w for w > 0).
6. Mean and median of each row of `temp_norm`, and mean of each row of the MST adjacency matrix.

### Spectrum

The PSD (`TF` field) is used in three forms: `spectrum` (PSD), `spectrum_log` (10·log10 of the PSD) and `spectrum_mag` (square root of the PSD). For each form and each channel, the script computes mean, median, maximum and frequency of the maximum within these bands:

| Name in output | Range (Hz) |
|---|---|
| `delta` | 2–4 |
| `theta` | 5–7 |
| `alpha` | 8–12 |
| `beta` | 15–29 |
| `gamma` | 30–59 |
| `spike` | 1–60 |

The PSD frequency vector is rounded to integers. Both band edges must be present in the rounded vector.

## Outputs

The script leaves three variables in the MATLAB workspace and clears everything else, including `patient_folder`. Nothing is saved to disk.

Naming: `<band>` is a band name from the AEC file, `<psdband>` is a name from the table above, `<spec>` is one of `spectrum`, `spectrum_log`, `spectrum_mag`.

**`DB`** (`dataset`, 19 rows, sorted by `ID` and `channel`)

| Columns | Content |
|---|---|
| `ID`, `channel` | subject ID and channel label |
| `AEC_betweenness_<band>`, `AEC_closeness_<band>`, `AEC_degree_<band>`, `AEC_eigenvector_<band>` | MST centrality |
| `AEC_partcoeff_<band>`, `AEC_clustcoeff_<band>`, `AEC_strengths_<band>`, `AEC_module_<band>` | BCT node measures on `temp_norm` |
| `AEC_meanFC_<band>`, `AEC_medianFC_<band>` | row mean and median of `temp_norm` |
| `AEC_meanMST_<band>` | row mean of the MST adjacency matrix |
| `<spec>_mean_<psdband>`, `<spec>_median_<psdband>`, `<spec>_max_<psdband>`, `<spec>_maxfreq_<psdband>` | spectral features |

**`DB_norm`** has the same columns as `DB`, normalized as follows:

- MST centrality, `partcoeff`, `clustcoeff`, `strengths`: divided by the maximum across channels;
- `module`, `meanFC`, `medianFC`, `meanMST`: not normalized;
- `<spec>_mean_*`, `<spec>_median_*`: divided by the maximum across channels;
- `<spec>_max_*`: divided by the maximum of that spectrum over all channels and frequencies;
- `<spec>_maxfreq_*`: divided by the upper edge of the band.

**`FC`** (`dataset`, one row)

| Columns | Content |
|---|---|
| `ID` | subject ID |
| `AEC` | AEC matrix as read from Brainstorm [19 × 19 × bands], before normalization |
| `AEC_MST` | weighted MST adjacency matrices [19 × 19 × bands] |
| `AEC_transitivity_<band>`, `AEC_globalefficiency_<band>`, `AEC_charpath_<band>`, `AEC_modularity_<band>` | network measures |
| `<spec>` | spectrum [19 × frequencies] |
| `<spec>_max` | maximum of the spectrum over all channels and frequencies |
| `<spec>_max_<psdband>` | maximum of the spectrum within the band |

## Data

Patient EEG data are not included in this repository.

## Third-party code and licenses

- The BCT functions in `functions/` are from the 2019-03-03 BCT release as hosted by [brainlife/BCT](https://github.com/brainlife/BCT/tree/main/BCT/2019_03_03_BCT). Their MIT license is in `functions/BCT_LICENSE`. If you use them, please cite: Rubinov M, Sporns O (2010) Complex network measures of brain connectivity: Uses and interpretations. NeuroImage 52:1059–69.
- `functions/GetConnectMatrix.m` is adapted from the `GetConnectMatrix` subfunction of `bst_memory.m` in [Brainstorm](https://neuroimage.usc.edu/brainstorm), distributed under the GNU General Public License.

## License

This repository is distributed under the GNU General Public License v3.0 (see `LICENSE`). The BCT functions in `functions/` keep their MIT license (see `functions/BCT_LICENSE`).
