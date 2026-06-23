clc; clear; close all;

%% Cargar codebooks pre-entrenados
if ~exist('codebooks.mat', 'file')
    error('No se encuentra codebooks.mat. Ejecute main.m primero para entrenar.');
end
load('codebooks.mat');
fprintf('Codebooks cargados: %d palabras\n', length(palabras));
for i = 1:length(palabras)
    fprintf('  %d. %s\n', i, palabras{i});
end

%% Parametros de grabacion
fs = 16000;
dur = 2;

fprintf('\n========================================\n');
fprintf('   PRUEBA EN VIVO\n');
fprintf('========================================\n');
fprintf('Diga una palabra y espere %d segundos.\n', dur);
fprintf('Presione Ctrl+C para salir.\n\n');

while true
    input('Presione ENTER para grabar...', 's');

    palabra = live_test(codebooks, palabras, fs, dur);
    fprintf('  >>> RECONOCIDO: %s <<<\n\n', palabra);
end
