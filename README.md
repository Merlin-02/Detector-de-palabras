# Detector de Palabras

Sistema de reconocimiento de palabras aisladas en español usando **MFCC** + **Cuantizacion Vectorial (VQ-LBG)** implementado en **MATLAB**.

## Descripcion General

El sistema entrena un codebook por palabra usando grabaciones de multiples locutores, y luego clasifica audios desconocidos midiendo la distancia euclidiana minima de sus caracteristicas acusticas a cada codebook.

**Palabras reconocidas (12):**
`arriba`, `abajo`, `encender`, `apagar`, `abrir`, `cerrar`, `subir`, `bajar`, `silencio`, `alto`, `seguir`, `parar`

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────┐
│                    ENTRENAMIENTO                         │
│                                                         │
│  Audio (*.wav)                                          │
│      │                                                  │
│      ▼                                                  │
│  preprocess.m                                           │
│      │  - Pre-enfasis                                   │
│      │  - VAD (Voice Activity Detection)                │
│      │  - Normalizacion                                 │
│      ▼                                                  │
│  mfcc.m                                                 │
│      │  - Framing + Ventana Hamming                     │
│      │  - FFT + Banco Mel (26 filtros)                  │
│      │  - Log + DCT → 12 MFCC                           │
│      │  - Delta + Delta-Delta                           │
│      │  - Energia + Delta + Delta-Delta                 │
│      │  - Normalizacion por media                       │
│      ▼                                                  │
│  vqCodeBook.m                                           │
│      │  - Algoritmo LBG                                 │
│      ▼                                                  │
│  codebook.mat  ←  k centroides por palabra              │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                      PRUEBA                              │
│                                                         │
│  Audio (*.wav)                                          │
│      │                                                  │
│      ▼                                                  │
│  preprocess.m ──► mfcc.m ──► distance.m                 │
│                                  │                      │
│                                  ▼                      │
│                    Palabra con menor distancia           │
└─────────────────────────────────────────────────────────┘
```

---

## Archivos del Proyecto

### Scripts Principales

#### `main.m`

**Script principal.** Orquesta todo el flujo de entrenamiento y evaluacion.

**Flujo:**
1. Escanea `locutores/` y lista los locutores disponibles
2. Pide al usuario seleccionar manualmente que locutor usar para PRUEBA
3. Entrena un codebook por palabra con los locutores restantes
4. Guarda los codebooks en `codebooks.mat`
5. Prueba cada audio del locutor seleccionado contra todos los codebooks
6. Muestra matriz de confusion y precision final

**Parametros configurables:**

| Linea | Variable | Tipo | Valor por defecto | Descripcion |
|-------|----------|------|-------------------|-------------|
| 4 | `locutoresDir` | string | `'./locutores'` | Ruta a la carpeta raiz de los locutores |
| 5-6 | `palabras` | cell array | `{'arriba','abajo',...}` | Lista de palabras del diccionario |
| 7 | `numReps` | integer | `5` | Repeticiones esperadas por palabra por locutor |
| 8 | `k` | integer | `32` | Tamaño del codebook (numero de centroides) |

**Ejemplo de configuracion reducida (6 palabras):**
```matlab
palabras = {'arriba', 'abajo', 'encender', 'apagar', 'abrir', 'cerrar'};
```

**Ejemplo con codebook mas grande (mas precision, mas lento):**
```matlab
k = 128;
```

**Salida:**
```
========================================
   RESULTADOS
========================================
Precision: 78.18% (43/55 aciertos)

Matriz de confusion (filas=real, columnas=predicho):
                  arriba       abajo    encender ...
      arriba           5           0           0 ...
       abajo           0           4           0 ...
```

---

#### `live_demo.m`

**Demo en vivo.** Reconoce palabras en tiempo real usando el microfono.

**Flujo:**
1. Carga `codebooks.mat` (generado por `main.m`)
2. Muestra la lista de palabras que puede reconocer
3. Espera que el usuario presione ENTER
4. Llama a `live_test.m` para grabar 2 segundos
5. Muestra la palabra reconocida en pantalla
6. Repite en ciclo infinito hasta presionar Ctrl+C

**Parametros internos:**
- `fs = 16000` — Frecuencia de muestreo de grabacion (Hz)
- `dur = 2` — Duracion de la grabacion (segundos)

**Limitacion:** Solo funciona en MATLAB Desktop. En MATLAB Online, `audiorecorder` no tiene soporte completo desde el navegador.

**Uso:**
```matlab
>> main        % primero, para generar codebooks.mat
>> live_demo   % luego, para probar en vivo
```

---

#### `live_test.m`

**Funcion de grabacion y clasificacion.** Utilizada por `live_demo.m`.

**Flujo:**
1. Crea un objeto `audiorecorder(fs, 16, 1)` — 16kHz, 16-bit, mono
2. Graba `dur` segundos de audio
3. Obtiene la grabacion como vector double
4. Procesa con `preprocess` y `mfcc`
5. Calcula la distancia a cada codebook con `distance`
6. Retorna la palabra con la distancia minima

**Parametros de entrada:**
| Parametro | Tipo | Default | Descripcion |
|-----------|------|---------|-------------|
| `codebooks` | cell | — | Codebooks entrenados (de `codebooks.mat`) |
| `palabras` | cell | — | Lista de palabras |
| `fs` | integer | 16000 | Frecuencia de muestreo (Hz) |
| `dur` | integer | 2 | Duracion de grabacion (segundos) |

---

### Procesamiento de Audio

#### `preprocess.m`

**Preprocesamiento de la señal de audio.** Prepara la señal cruda para la extraccion de caracteristicas.

**Parametros internos:**

| Parametro | Valor | Descripcion |
|-----------|-------|-------------|
| Coeficiente pre-enfasis | `0.97` | `filter([1 -0.97], 1, s)` — realce de altas frecuencias |
| Frame VAD | `0.025 * fs` | 25ms por frame para deteccion de energia |
| Shift VAD | `0.010 * fs` | 10ms de desplazamiento entre frames |
| Umbral energia | `0.1` | Fraccion de la energia maxima para VAD |

**Pasos:**
1. **Pre-enfasis:** `s = filter([1 -0.97], 1, s)` — filtro de primer orden que realza las frecuencias altas, compensando la caida natural de 6dB/octava del espectro del habla. El coeficiente 0.97 controla la intensidad del realce (valores tipicos: 0.95-0.99).

2. **Deteccion de actividad vocal (VAD):** Divide la señal en frames de 25ms con desplazamiento de 10ms. Calcula la energia de cada frame como `sum(frame.^2)`. Normaliza las energias dividiendo por el maximo. Descarta todos los frames con energia menor al 10% (`umbral = 0.1`) de la energia maxima. Esto elimina silencios y ruido de fondo.

3. **Normalizacion:** `s_out = s / max(abs(s) + eps)` — escala la amplitud al rango [-1, 1] dividiendo por el valor absoluto maximo. `eps` evita division por cero.

---

#### `mfcc.m`

**Extraccion de descriptores MFCC (Mel-Frequency Cepstral Coefficients).** Es el corazon del sistema de reconocimiento. Convierte la señal de audio en un conjunto de vectores de caracteristicas que representan el contenido fonetico.

**Parametros internos:**

| Parametro | Valor | Descripcion |
|-----------|-------|-------------|
| `N` (frame) | `256` muestras | 16ms a 16kHz (tipico: 20-30ms) |
| `M` (shift) | `100` muestras | 6.25ms a 16kHz (tipico: 5-10ms) |
| `numFilters` | `26` | Numero de filtros Mel (tipico: 20-40) |
| `numCoeffs` | `12` | Coeficientes MFCC estaticos (tipico: 12-13) |
| `deltaWin` | `2` | Ventana para delta (tipico: 2-3) |

**Pasos detallados:**

1. **Framing:** Divide la señal en frames de N=256 muestras (16ms a 16kHz). El desplazamiento entre frames es M=100 muestras (6.25ms). Esto da una superposicion de 156 muestras (61%) entre frames consecutivos, lo que garantiza suavidad temporal.

2. **Ventaneo:** Aplica una ventana Hamming a cada frame para reducir el efecto de borde (leakage espectral) en la FFT. La ventana Hamming tiene la forma `w(n) = 0.54 - 0.46*cos(2*pi*n/(N-1))`.

3. **FFT:** Transformada Rapida de Fourier de 256 puntos. Convierte cada frame del dominio del tiempo al dominio de la frecuencia. Solo se conservan las primeras N/2+1 = 129 bandas de frecuencia (simetria conjugada).

4. **Banco de filtros Mel:** Se aplican 26 filtros triangulares espaciados uniformemente en la escala Mel. La escala Mel es logaritmica: `Mel(f) = 2595 * log10(1 + f/700)`. Esto simula la percepcion no lineal del oido humano, que es mas sensible a bajas frecuencias.

5. **Logaritmo y DCT:** Se toma el logaritmo natural de la salida de cada filtro (simula la percepcion logaritmica de la amplitud del oido) y luego se aplica la Transformada Coseno (DCT) para decorrelacionar los coeficientes.

6. **Seleccion de coeficientes:** Se descarta el coeficiente 0 (energia promedio del frame) y se conservan los 12 siguientes (c1 a c12). Los coeficientes de orden superior (>12) contienen informacion espectral fina que varia mucho entre hablantes y no es util para reconocimiento.

7. **Delta (1ra derivada):** Calcula la tasa de cambio de cada coeficiente entre frames usando una ventana de ±2 frames. La formula es: `delta(t) = sum(n * (c(t+n) - c(t-n))) / (2 * sum(n^2))` para n=1,2. Esto captura la dinamica temporal del habla.

8. **Delta-Delta (2da derivada):** Calcula la aceleracion (cambio de los deltas) usando la misma formula sobre los coeficientes delta.

9. **Energia:** Anade la energia logaritmica de cada frame (`log(sum(|FFT|^2))`) mas su delta y delta-delta. Esto proporciona informacion sobre la amplitud del frame y su evolucion temporal.

10. **Normalizacion por media:** Resta la media de cada coeficiente a traves de todos los frames. Esto elimina el sesgo del tracto vocal de cada hablante y hace las caracteristicas mas invariantes al locutor.

**Dimension del descriptor por frame:** 39

| Componente | Dimensiones |
|------------|-------------|
| MFCC estaticos (c1-c12) | 12 |
| Delta MFCC | 12 |
| Delta-Delta MFCC | 12 |
| Energia log + delta + delta-delta | 3 |
| **Total** | **39** |

---

#### `melFilterBank.m`

**Banco de filtros Mel.** Genera una matriz dispersa de filtros triangulares espaciados en la escala Mel.

**Parametros de entrada:**
| Parametro | Descripcion |
|-----------|-------------|
| `p` | Numero de filtros (default 26, antes 20) |
| `n` | Longitud de la FFT (256) |
| `fs` | Frecuencia de muestreo (Hz) |

**Funcionamiento:**
1. Calcula `p+2` puntos espaciados uniformemente en la escala Mel entre 0Hz y fs/2
2. Convierte esos puntos de vuelta a Hz
3. Para cada filtro `i`, crea un triangulo con:
   - Base izquierda en el punto `i-1`
   - Pico en el punto `i`
   - Base derecha en el punto `i+1`
4. Los filtros son mas densos en bajas frecuencias y mas espaciados en altas (escala Mel)

**Salida:** Matriz dispersa de tamaño `p x (1 + n/2)` donde cada fila es un filtro triangular.

---

### Cuantizacion Vectorial

#### `vqCodeBook.m`

**Algoritmo LBG (Linde-Buzo-Gray).** Crea un codebook de `k` centroides que representan los vectores de caracteristicas de entrenamiento.

**Parametros internos:**

| Parametro | Valor | Descripcion |
|-----------|-------|-------------|
| `e` (epsilon) | `0.0001` | Factor de perturbacion para splitting |
| `k` | `32` (configurable en main.m) | Numero de centroides deseados |
| Criterio convergencia | `(distortion - t)/t < e` | Detiene iteraciones cuando la mejora es menor a 0.01% |

**Algoritmo paso a paso:**

1. **Inicializacion:** El codebook comienza con un solo centroide: la media de todos los vectores de entrenamiento.

2. **Split:** Duplica cada centroide existente aplicando una pequena perturbacion:
   - `codebook_new = [codebook * (1+e), codebook * (1-e)]`
   - Esto crea 2 centroides ligeramente diferentes del original

3. **Asignacion:** Para cada vector de entrenamiento, calcula la distancia euclidiana a todos los centroides y lo asigna al mas cercano. Usa la funcion `distance.m`.

4. **Actualizacion:** Cada centroide se recalcula como la media de todos los vectores asignados a el.

5. **Convergencia:** Calcula la distorsion total `t` (suma de distancias de cada vector a su centroide). Si la mejora relativa `(distortion_anterior - t)/t` es menor que `e`, termina la iteracion. En caso contrario, repite desde paso 3.

6. **Repeticion del split:** Vuelve al paso 2 con el doble de centroides. Repite hasta alcanzar `k` centroides.

**Iteraciones de split (k=32):**
```
Iteracion 1: 1 → 2 centroides
Iteracion 2: 2 → 4 centroides
Iteracion 3: 4 → 8 centroides
Iteracion 4: 8 → 16 centroides
Iteracion 5: 16 → 32 centroides
```

**Nota:** El algoritmo LBG garantiza convergencia local pero no necesariamente global. El resultado depende de la inicializacion. Es sensible a centroides que quedan sin puntos asignados (vacios), lo que puede producir valores NaN en las distancias.

---

#### `distance.m`

**Distancia Euclidea por pares.** Calcula la distancia entre cada par de vectores columna de dos matrices.

**Formula:** `D(i,j) = sqrt(sum((X(:,i) - Y(:,j)).^2))`

**Optimizacion:** El algoritmo evita bucles anidados completos eligiendo la direccion de iteracion segun cual matriz tiene menos columnas. Si X tiene N columnas e Y tiene P columnas:
- Si N < P: Itera sobre las N columnas de X
- Si N >= P: Itera sobre las P columnas de Y

**Parametros de entrada:**
- `x`: Matriz de tamanos `M x N` (M = dimension, N = numero de vectores)
- `y`: Matriz de tamanos `M x P` (M = dimension, P = numero de vectores)

**Salida:**
- `d`: Matriz de tamanos `N x P` donde `d(i,j)` es la distancia entre `x(:,i)` e `y(:,j)`

---

### Clasificacion

#### `test_word.m`

**Clasificacion de un archivo de audio.** Determina que palabra contiene el audio.

**Flujo:**
1. Lee el archivo WAV con `audioread`
2. Aplica `preprocess` para limpiar la senal
3. Extrae MFCC con `mfcc`
4. Para cada codebook (uno por palabra):
   - Calcula la distancia de cada frame a cada centroide (`distance`)
   - Toma la distancia minima por frame (`min(d, [], 2)`)
   - Promedia esas minimas sobre todos los frames (`sum / size(d, 1)`)
5. Selecciona la palabra con la distancia promedio mas baja

**Formula de decision:**
```
distancia_promedio(palabra) = mean(frame_a_centroide_mas_cercano)
palabra_reconocida = argmin(distancia_promedio)
```

---

#### `train_word.m`

**Entrenamiento de codebooks por palabra.**

**Flujo:**
1. Para cada palabra en la lista:
   - Itera sobre todos los locutores de entrenamiento
   - Para cada locutor, itera sobre las `numReps` repeticiones
   - Lee cada audio: `[locutorDir]/[locutor]/Audios/[palabra]_[rep].wav`
   - Aplica `preprocess` + `mfcc`
   - Concatena todos los vectores MFCC en una matriz
2. Aplica `vqCodeBook` a la matriz concatenada
3. Almacena el codebook resultante

**Parametros:**
- `locutoresDir`: Directorio raiz de los locutores
- `palabras`: Lista de palabras
- `locutoresTrain`: Nombres de los locutores para entrenar
- `numReps`: Numero de repeticiones por palabra/locutor

---

#### `train.m` y `test.m`

**Archivos de tutorial.** Corresponden a una implementacion original de reconocimiento de locutores (no de palabras). No se utilizan en el flujo principal actual del sistema.

**Diferencias con el sistema actual:**
- `train.m`: Entrena un codebook por locutor (no por palabra)
- `test.m`: Identifica que locutor hablo (no que palabra)
- Usan `wavread` (funcion antigua, ahora `audioread`)
- No incluyen preprocesamiento ni VAD

---

### Organizacion de Datos

#### `organize.py`

**Script auxiliar de organizacion.** Reorganiza los audios de la carpeta `voces/` (con estructura original desordenada) en la estructura que espera el codigo (`locutores/`).

**Funcionalidades:**
- Escanea todos los locutores en `voces/Reconocimiento de Palabras/`
- Detecta y maneja multiples formatos de audio (WAV, MP3, OGG, MP4)
- Convierte todo a WAV 16kHz mono usando `ffmpeg`
- Mapea las distintas nomenclaturas de archivos al formato `palabra_NN.wav`
- Maneja casos especiales: archivos en subcarpetas, nombres con espacios, etc.

**Estructura que maneja:**
| Locutor | Estructura original | Formato |
|---------|-------------------|---------|
| Dulce | `Dulce/Nueva carpeta/{palabra}/{N}_{palabra}.mp3` | MP3 48kHz → WAV 16kHz |
| Jayme | `Jayme/{Palabra}/{Palabra}{N}.wav` | WAV 44.1kHz stereo → mono 16kHz |
| Leonel | `Leonel/{palabra}/record_out*.wav` | WAV convertido |
| Oscar | `Oscar/{Palabra}/Recording*.wav` | WAV convertido |
| Rodrigo | `Rodrigo/{palabra}/{palabra}{N}.wav` + `.ogg` | WAV/OGG convertido |

---

## Estructura de Directorios

```
Speech-Recognition-master/
│
├── main.m                    Script principal
├── live_demo.m               Demo en vivo con microfono
├── live_test.m               Funcion de grabacion/clasificacion
├── train_word.m              Entrenamiento por palabra
├── test_word.m               Clasificacion de un audio
│
├── preprocess.m              Preprocesamiento de senal
├── mfcc.m                    Extraccion de MFCC (descriptor principal)
├── melFilterBank.m           Banco de filtros Mel
│
├── vqCodeBook.m              Algoritmo LBG de cuantizacion vectorial
├── distance.m                Distancia Euclidea
│
├── train.m                   (no usado) Tutorial original
├── test.m                    (no usado) Tutorial original
│
├── locutores/                Datos de audio organizados
│   ├── Dulce/
│   │   └── Audios/
│   │       ├── arriba_01.wav
│   │       ├── arriba_02.wav
│   │       ├── ...
│   │       └── parar_05.wav     60 archivos (12 palabras x 5 reps)
│   ├── Jayme/
│   │   └── Audios/              55 archivos (11 palabras, falta parar)
│   ├── Leonel/
│   │   └── Audios/              61 archivos (algunos con 6 reps)
│   ├── Oscar/
│   │   └── Audios/              60 archivos
│   ├── Prueba/
│   │   └── Audios/              60 archivos
│   └── Rodrigo/
│       └── Audios/              72 archivos (12 palabras x 6 reps)
│
├── README.md                 Este archivo
└── .gitignore                Archivos ignorados por git
```

### Convencion de nombres de archivos

Cada locutor en `locutores/` debe tener una carpeta `Audios/` con archivos nombrados como:

```
locutores/NombreLocutor/Audios/palabra_NN.wav
```

Donde:
- `palabra`: Una de las palabras definidas en `palabras` (minusculas)
- `NN`: Numero de repeticion de dos digitos (01, 02, ..., 05)
- Extension: `.wav` (16-bit, mono, 16kHz recomendado)

**Ejemplos:**
- `arriba_01.wav` — Primera grabacion de "arriba"
- `silencio_05.wav` — Quinta grabacion de "silencio"

---

## Flujo de Datos Detallado

```
Audio (.wav)
    │
    ├── audioread(filename)
    │   └── [senal, fs] (senal: double[], fs: double)
    │
    ▼
┌──────────────────────────────────────────────────────┐
│                    preprocess.m                        │
│                                                       │
│  Entrada: s (senal cruda), fs (frecuencia muestreo)  │
│                                                       │
│  1. Pre-enfasis                                       │
│     s = filter([1, -0.97], 1, s)                      │
│     → Realza frecuencias altas                        │
│                                                       │
│  2. VAD (Voice Activity Detection)                    │
│     frameLen = round(0.025 * fs)   ← 25ms             │
│     frameShift = round(0.010 * fs) ← 10ms             │
│     energia = sum(frame.^2)  por cada frame           │
│     umbral = 0.1 * max(energia)                       │
│     voiced = energia > umbral                         │
│     → Elimina silencios al inicio y final             │
│                                                       │
│  3. Normalizacion                                     │
│     s_out = s / max(abs(s))                           │
│     → Amplitud en rango [-1, 1]                       │
│                                                       │
│  Salida: s_out (senal preprocesada)                   │
└──────────────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────────────┐
│                      mfcc.m                            │
│                                                       │
│  Entrada: s (senal preprocesada), fs (frecuencia)     │
│                                                       │
│  1. Framing                                           │
│     N = 256 (16ms a 16kHz)                            │
│     M = 100 (6.25ms de desplazamiento)                │
│     numFrames = 1 + floor((len-N)/M)                  │
│                                                       │
│  2. Ventana Hamming                                   │
│     frame = frame * hamming(N)                        │
│     → Reduce leakage espectral                        │
│                                                       │
│  3. FFT (256 puntos)                                  │
│     spectrum = fft(frame)                             │
│     Solo se usan las primeras 129 bandas              │
│                                                       │
│  4. Banco de filtros Mel (26 filtros)                 │
│     melSpectrum = filterBank * power_spectrum         │
│     → Simula percepcion auditiva humana               │
│                                                       │
│  5. Log + DCT                                         │
│     c = dct(log(melSpectrum))                         │
│     → Decorrelacion de coeficientes                   │
│                                                       │
│  6. Seleccion: 12 coeficientes (c1-c12)               │
│     c(1,:) = []  (descarta energia promedio)          │
│     c = c(1:12,:)                                     │
│                                                       │
│  7. Delta (ventana ±2)                                │
│     delta(t) = Σ n*(c(t+n)-c(t-n)) / 2*Σ n²          │
│     → Captura dinamica temporal                       │
│                                                       │
│  8. Delta-Delta (ventana ±2 sobre delta)              │
│     → Captura aceleracion espectral                   │
│                                                       │
│  9. Energia + delta + delta-delta                     │
│     energy = log(Σ |FFT|²)                            │
│     → Informacion de amplitud                         │
│                                                       │
│  10. Normalizacion por media                          │
│      c = c - mean(c, 2)                               │
│      → Elimina sesgo del hablante                     │
│                                                       │
│  Salida: c (39 x numFrames)                           │
│          12 MFCC + 12 Δ + 12 ΔΔ + 1 E + 1 ΔE + 1 ΔΔE│
└──────────────────────────────────────────────────────┘
    │
    ├─── ENTRENAMIENTO ───▶ vqCodeBook.m ──▶ codebook.mat
    │
    └─── PRUEBA ──────────▶ distance.m ────▶ palabra reconocida
```

---

## Como Usar

### 1. Requisitos

| Requisito | Especificacion |
|-----------|---------------|
| MATLAB | R2015b o superior (MATLAB Online compatible) |
| Toolbox requerido | Signal Processing Toolbox (para `hamming`, `dct`, etc.) |
| ffmpeg (opcional) | Solo para convertir audios con `organize.py` |
| Python 3 (opcional) | Solo para ejecutar `organize.py` |

### 2. Estructura de datos

Coloca los audios en `locutores/NombreLocutor/Audios/palabra_NN.wav`.

**Nuevo locutor:**
1. Crea la carpeta: `locutores/MiVoz/Audios/`
2. Graba 5 repeticiones de cada palabra
3. Nombra los archivos como `arriba_01.wav`, `arriba_02.wav`, etc.
4. El codigo lo detectara automaticamente

### 3. Ejecutar entrenamiento y prueba

```matlab
>> main
```

El programa:
1. Listara todos los locutores encontrados
2. Te pedira seleccionar cual usar para prueba
3. Entrenara con los demas
4. Probara y mostrara los resultados

### 4. Demo en vivo (solo MATLAB Desktop)

Primero entrena, luego ejecuta la demo:

```matlab
>> main        → genera codebooks.mat
>> live_demo   → reconocimiento por microfono
```

---

## Guia de Parametros

### En `main.m` — Configuracion del sistema

```matlab
locutoresDir = './locutores';        % Ruta a los datos
palabras = {'arriba', 'abajo', ...}; % Diccionario
numReps = 5;                         % Repeticiones por locutor
k = 32;                              % Centroides del codebook
```

**Efecto de `k` (numero de centroides):**

| k | Centroides | Precision tipica | Tiempo entrenamiento | Tiempo prueba |
|---|-----------|-----------------|---------------------|---------------|
| 16 | 16 | ~50-60% | Rapido | Rapido |
| 32 | 32 | ~60-80% | Moderado | Moderado |
| 64 | 64 | ~70-85% | Lento | Moderado |
| 128 | 128 | ~75-90% | Muy lento | Lento |

**Efecto de `numReps`:**

| numReps | Uso |
|---------|-----|
| 5 | Valor recomendado. Suficientes ejemplos por palabra |
| 3 | Minimo para entrenamiento basico |
| 10 | Mas datos = mejor generalizacion, mas lento |

### En `mfcc.m` — Descriptores acusticos

```matlab
N = 256;              % Frame size (muestras)
M = 100;              % Frame shift (muestras)
numFilters = 26;      % Filtros Mel
deltaWin = 2;          % Ventana para derivadas
```

**Efecto de `numFilters` (filtros Mel):**

| Filtros | Uso |
|---------|-----|
| 20 | Estandar, menos computo |
| 26 | Mejor resolucion espectral (actual) |
| 30-40 | Mayor detalle, mas dimensiones |

**Efecto de `N` (frame size) a 16kHz:**

| N | Duracion | Resolucion frecuencia | Resolucion tiempo |
|---|---------|----------------------|-------------------|
| 128 | 8ms | Baja | Alta |
| 256 | 16ms | Media | Media (actual) |
| 512 | 32ms | Alta | Baja |

**Efecto de `M` (frame shift) a 16kHz:**

| M | Desplazamiento | Superposicion | Numero de frames |
|---|---------------|--------------|-----------------|
| 64 | 4ms | 75% | Muchos |
| 100 | 6.25ms | 61% | Medios (actual) |
| 128 | 8ms | 50% | Pocos |

### En `preprocess.m` — Preprocesamiento

```matlab
coef_preenfasis = 0.97;     % Coeficiente del filtro pre-enfasis
frameLen = 0.025 * fs;      % 25ms para VAD
frameShift = 0.010 * fs;    % 10ms para VAD
threshold = 0.1;            % Umbral de energia (10%)
```

**Efecto de `threshold` (VAD):**

| Threshold | Efecto |
|-----------|--------|
| 0.05 | Menos agresivo, conserva silencios bajos |
| 0.10 | Balanceado (actual) |
| 0.15-0.20 | Mas agresivo, podria cortar inicio/final de palabra |

---

## Precision y Factores que la Afectan

### Factores que mejoran la precision

| Factor | Impacto | Explicacion |
|--------|---------|-------------|
| + Locutores entrenamiento | Alto | Mejor generalizacion inter-hablantes |
| + Repeticiones por palabra | Medio | Mas ejemplos para el codebook |
| + k (centroides) | Medio | Codebook mas detallado |
| Calidad de audio | Alto | Misma frecuencia, mismo microfono, sin ruido |
| Palabras foneticamente distintas | Alto | Palabras similares (apagar/parar) se confunden mas |

### Factores que reducen la precision

| Factor | Problema |
|--------|----------|
| Diferentes frecuencias de muestreo | MFCC inconsistentes |
| Ruido de fondo | VAD puede fallar o incluir ruido |
| Diferentes microfonos | Distinta coloracion espectral |
| Hablante nuevo sin datos | Voz no representada en codebooks |
| Centroides vacios en LBG | Distorsion NaN en codebook |

### Valores de precision tipicos

| Configuracion | Locutores | Precision |
|--------------|-----------|-----------|
| k=16, 5 reps | 3 train / 1 test | ~40-55% |
| k=32, 5 reps | 4 train / 1 test | ~60-75% |
| k=64, 5 reps | 4 train / 1 test | ~65-80% |
| k=128, 5 reps | 5 train / 1 test | ~70-85% |

---

## Troubleshooting

### Error: "Array indices must be positive integers"

**Causa:** El algoritmo LBG genera centroides vacios (sin puntos asignados), lo que produce valores `NaN` en las distancias. Ningun codebook produce una distancia valida, `idx` se queda en 0, y `palabras{0}` es invalido.

**Solucion:** Agregar mas descriptores en `mfcc.m` para que los vectores de caracteristicas sean mas discriminativos y los centroides no queden vacios. Alternativamente, aumentar `k` o `numReps`.

### Error: "No se encuentran archivos para la palabra X"

**Causa:** Ningun locutor de entrenamiento tiene archivos para la palabra X en el formato `palabra_NN.wav`.

**Solucion:** Verificar que los nombres de archivo coincidan exactamente con las palabras definidas en `palabras` (minusculas, con guion bajo y numero de dos digitos).

### Baja precision (<50%)

**Causas posibles:**
- Codebook demasiado pequeno (k=16 o menos)
- Centroides vacios en el codebook
- Audios con diferentes frecuencias de muestreo
- VAD muy agresivo que corta la palabra
- Locutor de prueba muy diferente a los de entrenamiento

**Posibles mejoras:**
- Aumentar k a 64 o 128
- Agregar mas locutores de entrenamiento
- Asegurar que todos los audios esten a 16kHz mono
- Agregar mas descriptores (mas filtros Mel, mas coeficientes, etc.)

---

## Notas Tecnicas

### Frecuencia de muestreo

El sistema esta disenado para 16kHz, la frecuencia estandar para reconocimiento de voz. Los frames de 256 muestras equivalen a 16ms. Si se usan otras frecuencias, los parametros de MFCC no escalan automaticamente (N y M estan en muestras, no en milisegundos).

### Formato de audio

Todos los archivos en `locutores/` estan en formato WAV, 16-bit, mono, 16kHz. El script `organize.py` convierte automaticamente cualquier formato a este estandar usando ffmpeg.

### Coeficiente 0 de MFCC

El coeficiente 0 (energia promedio del frame) se elimina porque es redundante con la energia que se anade como descriptor separado, y porque variaciones de volumen entre grabaciones distorsionarian las distancias euclideanas.
