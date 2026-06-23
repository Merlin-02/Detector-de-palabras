function c = mfcc(s, fs)

N = 256;
M = 100;
len = length(s);
numberOfFrames = 1 + floor((len - N)/double(M));
mat = zeros(N, numberOfFrames);

for i=1:numberOfFrames
    index = 100*(i-1) + 1;
    for j=1:N
        mat(j,i) = s(index);
        index = index + 1;
    end
end

hamW = hamming(N);
afterWinMat = diag(hamW)*mat;
freqDomMat = fft(afterWinMat);

numFilters = 26;
filterBankMat = melFilterBank(numFilters, N, fs);
nby2 = 1 + floor(N/2);
ms = filterBankMat*abs(freqDomMat(1:nby2,:)).^2;
ms(ms == 0) = eps;
c = dct(log(ms));
c(1,:) = [];
c = c(1:12,:);

% Log energy per frame + delta + delta-delta
energy = log(sum(abs(freqDomMat(1:nby2,:)).^2, 1) + eps);

% Delta coefficients
deltaWin = 2;
[numCoeffs, numFrames] = size(c);
delta = zeros(numCoeffs, numFrames);
dEnergy = zeros(1, numFrames);
for t = 1:numFrames
    num = 0;
    den = 0;
    for n = 1:deltaWin
        if t+n <= numFrames && t-n >= 1
            num = num + n * (c(:, t+n) - c(:, t-n));
            den = den + n^2;
        end
    end
    if den > 0
        delta(:, t) = num / (2 * den);
    end
    % Delta energy
    numE = 0;
    for n = 1:deltaWin
        if t+n <= numFrames && t-n >= 1
            numE = numE + n * (energy(t+n) - energy(t-n));
        end
    end
    if den > 0
        dEnergy(t) = numE / (2 * den);
    end
end

% Delta-delta coefficients
ddelta = zeros(numCoeffs, numFrames);
ddEnergy = zeros(1, numFrames);
for t = 1:numFrames
    num = 0;
    den = 0;
    for n = 1:deltaWin
        if t+n <= numFrames && t-n >= 1
            num = num + n * (delta(:, t+n) - delta(:, t-n));
            den = den + n^2;
        end
    end
    if den > 0
        ddelta(:, t) = num / (2 * den);
    end
    % Delta-delta energy
    numE = 0;
    for n = 1:deltaWin
        if t+n <= numFrames && t-n >= 1
            numE = numE + n * (dEnergy(t+n) - dEnergy(t-n));
        end
    end
    if den > 0
        ddEnergy(t) = numE / (2 * den);
    end
end

energy = energy - mean(energy);
delta = delta - mean(delta, 2);
ddelta = ddelta - mean(ddelta, 2);

c = [c; delta; ddelta; energy; dEnergy; ddEnergy];
end
