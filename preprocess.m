function s_out = preprocess(s, fs)
    s = filter([1 -0.97], 1, s);

    frameLen = round(0.025 * fs);
    frameShift = round(0.010 * fs);
    energy = [];
    idx = 1;
    while idx + frameLen <= length(s)
        frame = s(idx:idx+frameLen-1);
        energy(end+1) = sum(frame.^2);
        idx = idx + frameShift;
    end

    if isempty(energy)
        s_out = s / max(abs(s) + eps);
        return;
    end

    energy = energy / max(energy);
    threshold = 0.1;
    voiced = find(energy > threshold);

    if isempty(voiced)
        s_out = s / max(abs(s) + eps);
        return;
    end

    firstSample = (voiced(1) - 1) * frameShift + 1;
    lastSample = min((voiced(end) - 1) * frameShift + frameLen, length(s));
    s = s(firstSample:lastSample);

    s_out = s / max(abs(s) + eps);
end
