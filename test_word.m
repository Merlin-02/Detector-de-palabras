function palabra = test_word(audioFile, codebooks, palabras)
    [s, fs] = audioread(audioFile);
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
