function R = GetConnectMatrix(Timefreq) 
% GETCONNECTMATRIX  Expand and reshape a Brainstorm connectivity matrix.
%   R = GetConnectMatrix(Timefreq) returns [Nrow x Ncol x Ntime x Nfreq].
%   Adapted from the GetConnectMatrix subfunction of bst_memory.m in
%   Brainstorm (https://neuroimage.usc.edu/brainstorm), distributed under
%   the GNU General Public License. Requires Brainstorm's
%   process_compress_sym.m on the MATLAB path.
    % Expand symmetric matrix
    %if isfield(Timefreq.Options, 'isSymmetric') && Timefreq.Options.isSymmetric
    if (length(Timefreq.RowNames) == length(Timefreq.RefRowNames)) && (size(Timefreq.TF,1) < length(Timefreq.RowNames)^2)
        Timefreq.TF = process_compress_sym('Expand', Timefreq.TF, length(Timefreq.RowNames));
    end
    % Reshape TF matrix: [Nrow x Ncol x Ntime x nFreq]
    nTime = size(Timefreq.TF, 2);
    nFreq = size(Timefreq.TF, 3);
    R = reshape(Timefreq.TF, [length(Timefreq.RefRowNames), length(Timefreq.RowNames), nTime, nFreq]);
end