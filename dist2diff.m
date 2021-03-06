function [evectors, evalues, h, Ahat, S] = dist2diff(varargin)
% DIST2DIFF Compute diffusion eigenfunctions from a distance matrix.
%
% [evectors, evalues, h, Ahat, S] = dist2diff(D)
%
% Inputs:
% D - squared-distance matrix
%
% Optional named parameters:
% Nvec - number of vectors computed (default: size D / 2)
% t - exponent (default: 1)
% h - diffusion bandwidth (default: heuristic estimate)
%
% Outputs:
% evectors - eigenvectors of the diffusion (without the trivial
%            eigenvector)
% evalues  - eigenvalues of the diffusion (without the trivial one)
% h        - bandwidth used
% Ahat     - diffusion Markov transition matrix
% S        - symmetrized diffusion Markov transition matrix

import DiffusionMaps.*

parser = inputParser;
parser.addRequired('D', @(x)validateattributes(x, {'numeric'},{'2d','square','nonnan','nonnegative'}) );
parser.addParameter('Nvec', NaN, @(x)validateattributes(x,{'numeric'},{'scalar'} ) );
parser.addParameter('h', NaN, @(x)validateattributes(x,{'numeric'},{'scalar'} ) );
parser.addParameter('t', 1, @(x)validateattributes(x,{'numeric'},{'scalar'} ) );

parser.parse(varargin{:});
D = parser.Results.D;
t = parser.Results.t;

% number of points
N = size(D,1)

if isnan(parser.Results.Nvec)
    Nvec = ceil(N*0.5);
else
    Nvec = parser.Results.Nvec;
end

if isnan(parser.Results.h) || parser.Results.h < 0
    Nsize = min( fix(N*5e-2), N-1) % neighborhood size - this is heuristic, sets to 5% of dataset
    h = nss(D, Nsize); % estimate using neighborhood size stability
    fprintf(1,'Estimated bandwidth h = %.2e\n',h);
else
    h = parser.Results.h;
end

assert( h > 0, 'Bandwidth has to be positive')

%% unbiased heat kernel
A = exp( -t*D/(4*h)); % heat kernel evaluation
disp('Heat kernel evaluated')
p = sum(A,1);    % estimated sampling density
Ahat = A ./ (p.' * p); % remove sampling density bias from heat kernel
disp('Heat kernel de-biased')

%% convert unbiased heat kernel to a symmetrized Markov chain matrix
symmass_col = sqrt(sum(Ahat,1));
symmass_row = sqrt(sum(Ahat,2));

scaling = (symmass_row * symmass_col);

disp('Scaling computed')

assert( size(scaling,1) == size(Ahat,1) );
assert( size(scaling,2) == size(Ahat,2) );

S = Ahat ./ scaling;

assert( norm(S - S.') < 1e-16, 'Symmetrized matrix not symmetric! Normof antisymmetric component: %e', norm(S - S.'))

disp('Eigenvector computation')

%% compute eigenvectors of the heat Markov chain
opts.issym = true;
opts.isreal = true;
opts.disp = 0;
opts.v0 = [1; zeros(N-1,1)]; % remove randomness by fixing initial vector
[V, Sigma] = eigs(S, Nvec+1, 'LA',opts); % add +1 to account for 1st trivial evector


%% make sure vectors are sorted by descending eigenvalue order
evalues = diag(Sigma);
[evalues, eind] = sort(evalues,'descend');
evectors = V(:, eind);

%% rescale with dominant eigenvector to account for symmetrization
evectors = evectors ./ repmat(evectors(:,1), [1, size(evectors,2)]);

% skip trivial eigenvalue and eigenvector
evectors = evectors(:,2:end);
evalues = evalues(2:end);

function h = nss(D, Nsize)
% h = nss(D, Nneigh)
%
% Estimate bandwidth using Neighborhood Size Stability.
%
% D - square of distances
% Nsize - size of the neighborhood

N = size(D,1);

validateattributes(Nsize,{'numeric'},{'integer','positive','finite', '<=',N});

ds = zeros(1,N);

Nsize = max(Nsize,1); % Nsize cannot be less than 1

% find Nsize-smallest distance
for k = 1:N
    y = sort(D(:,k));
    ds(k) = y(Nsize+1); % +1 accounts for diagonal which is always 0
end

% bandwidth h such that each point has Nsize neighbors within sqrt(2h)
h = max(ds)/2;
