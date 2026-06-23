function palabra = live_test(codebooks, palabras, fs, dur)
    if nargin < 3
        fs = 16000;
    end
    if nargin < 4
        dur = 2;
    end

    fprintf('Grabando (%d Hz, %d seg)... ', fs, dur);
    recObj = audiorecorder(fs, 16, 1);
    recordblocking(recObj, dur);
    fprintf('Listo.\n');

    s = getaudiodata(recObj, 'double');
    s = preprocess(s, fs);
    v = mfcc(s, fs);

    distmin = inf;
    idx = 0;
    for i = 1:length(codebooks)
        d = distance(v, codebooks{i});
        dist = sum(min(d, [], 2)) / size(d, 1);
        if dist < distmin
            distmin = dist;
            idx = i;
        end
    end

    palabra = palabras{idx};
end
