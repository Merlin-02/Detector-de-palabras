function codebooks = train_word(locutoresDir, palabras, locutoresTrain, numReps)
    k = 32;

    for p = 1:length(palabras)
        palabra = palabras{p};
        allFeatures = [];

        for l = 1:length(locutoresTrain)
            locutor = locutoresTrain{l};
            for r = 1:numReps
                filename = sprintf('%s/%s/Audios/%s_%02d.wav', ...
                    locutoresDir, locutor, palabra, r);
                if exist(filename, 'file')
                    [s, fs] = audioread(filename);
                    s = preprocess(s, fs);
                    v = mfcc(s, fs);
                    allFeatures = [allFeatures, v];
                end
            end
        end

        if isempty(allFeatures)
            error('No se encontraron archivos para la palabra: %s', palabra);
        end

        codebooks{p} = vqCodeBook(allFeatures, k);
        fprintf('  Codebook entrenado: %s (%d vectores, %d locutores)\n', ...
            palabra, size(allFeatures, 2), length(locutoresTrain));
    end
end
