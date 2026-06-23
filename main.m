clc; clear; close all;

%% Configuracion
locutoresDir = './locutores';
palabras = {'arriba', 'abajo', 'encender', 'apagar', 'abrir', 'cerrar', ...
            'subir', 'bajar', 'silencio', 'alto', 'seguir', 'parar'};
numReps = 5;
k = 32;

%% Obtener lista de locutores
d = dir(locutoresDir);
locutores = {};
for i = 1:length(d)
    if d(i).isdir && d(i).name(1) ~= '.'
        locutores{end+1} = d(i).name;
    end
end

numLocutores = length(locutores);
fprintf('Locutores encontrados: %d\n', numLocutores);
for i = 1:numLocutores
    fprintf('  %d. %s\n', i, locutores{i});
end

if numLocutores < 2
    error('Se necesitan al menos 2 locutores (se encontraron %d)', numLocutores);
end

%% Seleccion manual del locutor de prueba
fprintf('\nSeleccione el numero del locutor para PRUEBA (los demas entrenan):\n');
sel = input('  Opcion: ');
while sel < 1 || sel > numLocutores
    sel = input('  Invalido. Seleccione un numero valido: ');
end

locutoresTest = locutores(sel);
locutoresTrain = locutores;
locutoresTrain(sel) = [];

fprintf('\nLocutores ENTRENAMIENTO (%d):\n', length(locutoresTrain));
for i = 1:length(locutoresTrain)
    fprintf('  %s\n', locutoresTrain{i});
end
fprintf('\nLocutor PRUEBA:\n');
fprintf('  %s\n', locutoresTest{1});

%% Entrenamiento
fprintf('\n========================================\n');
fprintf('   ENTRENAMIENTO (k=%d)\n', k);
fprintf('========================================\n');
codebooks = train_word(locutoresDir, palabras, locutoresTrain, numReps);

%% Guardar codebooks para pruebas en vivo
save('codebooks.mat', 'codebooks', 'palabras');
fprintf('\nCodebooks guardados en codebooks.mat\n');

%% Prueba
fprintf('\n========================================\n');
fprintf('   PRUEBA\n');
fprintf('========================================\n');

numPalabras = length(palabras);
matrizConf = zeros(numPalabras, numPalabras);

for l = 1:length(locutoresTest)
    locutor = locutoresTest{l};
    for p = 1:numPalabras
        palabra = palabras{p};
        for r = 1:numReps
            filename = sprintf('%s/%s/Audios/%s_%02d.wav', ...
                locutoresDir, locutor, palabra, r);
            if ~exist(filename, 'file')
                continue;
            end
            pred = test_word(filename, codebooks, palabras);
            idxReal = p;
            idxPred = find(strcmp(palabras, pred), 1);
            matrizConf(idxReal, idxPred) = matrizConf(idxReal, idxPred) + 1;

            if strcmp(palabra, pred)
                marca = 'OK';
            else
                marca = 'ERROR';
            end
            fprintf('  %s/%s_%02d -> %s [%s]\n', locutor, palabra, r, pred, marca);
        end
    end
end

%% Resultados
fprintf('\n========================================\n');
fprintf('   RESULTADOS\n');
fprintf('========================================\n');

aciertos = sum(diag(matrizConf));
total = sum(matrizConf(:));
precision = aciertos / total * 100;
fprintf('Precision: %.2f%% (%d/%d aciertos)\n', precision, aciertos, total);

fprintf('\nMatriz de confusion (filas=real, columnas=predicho):\n');
fprintf('%12s', '');
for p = 1:numPalabras
    fprintf('%12s', palabras{p});
end
fprintf('\n');
for i = 1:numPalabras
    fprintf('%12s', palabras{i});
    for j = 1:numPalabras
        fprintf('%12d', matrizConf(i, j));
    end
    fprintf('\n');
end
