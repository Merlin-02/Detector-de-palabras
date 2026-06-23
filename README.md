# Detector de Palabras

Sistema de reconocimiento de palabras aisladas en español usando **MFCC** + **Cuantización Vectorial (VQ-LBG)** implementado en **MATLAB**.

## Descripcion General

El sistema entrena un codebook por palabra usando grabaciones de multiples locutores, y luego clasifica audios desconocidos midiendo la distancia euclidiana minima a cada codebook.

**Palabras reconocidas (12):**
arriba, abajo, encender, apagar, abrir, cerrar, subir, bajar, silencio, alto, seguir, parar

---

## Archivos del Proyecto

### Scripts Principales

#### `main.m`
**Script principal.** Orquesta todo el flujo:
1. Escanea el directorio `locutores/` y lista los locutores disponibles
2. Pide al usuario seleccionar manualmente que locutor usar para PRUEBA
3. Entrena un codebook por palabra con los locutores restantes
4. Guarda los codebooks en `codebooks.mat`
5. Prueba cada audio del locutor de prueba contra todos los codebooks
6. Muestra matriz de confusion y precision final

**Configuracion editable:**
| Linea | Variable | Descripcion |
|-------|----------|-------------|
| 4 | `locutoresDir` | Ruta a la carpeta con los locutores |
| 5-6 | `palabras` | Lista de palabras a reconocer |
| 7 | `numReps` | Numero de repeticiones por palabra por locutor |
| 8 | `k` | Tamaño del codebook (numero de centroides) |

#### `live_demo.m`
**Demo en vivo.** Carga `codebooks.mat` y permite reconocer palabras en tiempo real:
1. Carga los codebooks pre-entrenados
2. Espera que el usuario presione ENTER
3. Graba 2 segundos de audio con el microfono
4. Reconoce la palabra y la muestra en pantalla
5. Repite en ciclo infinito hasta Ctrl+C

Requiere `codebooks.mat` generado por `main.m`. Solo funciona en MATLAB Desktop (no en MATLAB Online, ya que `audiorecorder` no tiene soporte completo en navegador).

#### `train_word.m`
**Entrenamiento de codebooks por palabra.** Para cada palabra:
1. Itera sobre todos los locutores de entrenamiento
2. Lee cada audio (`locutor/Audios/palabra_NN.wav`)
3. Aplica preprocesamiento y extrae MFCC
4. Concatena todos los vectores MFCC de todos los locutores
5. Aplica el algoritmo LBG para crear un codebook de k centroides
6. Retorna una celda con 12 codebooks (uno por palabra)

#### `test_word.m`
**Clasificacion de un audio.** Dado un archivo de audio:
1. Lee el audio y extrae MFCC (mismo proceso que entrenamiento)
2. Calcula la distancia euclidiana de cada frame a cada codebook
3. La distancia total de la palabra es el promedio de las distancias minimas por frame
4. Devuelve la palabra con la distancia total mas baja

### Procesamiento de Audio

#### `preprocess.m`
**Preprocesamiento de la señal.** Pasos:
1. **Pre-enfasis:** `filter([1 -0.97], 1, s)` — realza frecuencias altas para compensar la caida natural del espectro del habla
2. **Deteccion de actividad vocal (VAD):** Divide la señal en frames de 25ms con desplazamiento de 10ms, calcula la energia de cada frame, y descarta frames con energia menor al 10% de la energia maxima — elimina silencios
3. **Normalizacion:** Escala la amplitud al rango [-1, 1]

#### `mfcc.m`
**Extraccion de coeficientes MFCC.** Descriptor principal del sistema:
1. **Framing:** Divide la señal en frames de 256 muestras (16ms a 16kHz) con desplazamiento de 100 muestras (6.25ms)
2. **Ventaneo:** Aplica ventana Hamming a cada frame
3. **FFT:** Transformada rapida de Fourier de 256 puntos
4. **Banco de filtros Mel:** 26 filtros triangulares espaciados en la escala Mel — simula la percepcion no lineal del oido humano
5. **Logaritmo y DCT:** Aplica logaritmo natural y transformada coseno para obtener los coeficientes cepstrales
6. **Seleccion:** Conserva los 12 primeros coeficientes (excluyendo el coeficiente 0 de energia)
7. **Delta:** Calcula la primera derivada temporal (tasa de cambio entre frames consecutivos) con ventana de ±2 frames — captura la dinamica del habla
8. **Delta-Delta:** Calcula la segunda derivada temporal (aceleracion)
9. **Energia:** Anade la energia logaritmica de cada frame, su delta y su delta-delta
10. **Normalizacion por media:** Resta la media de cada coeficiente para reducir el sesgo del locutor

**Dimension total del descriptor por frame:** 39 (12 MFCC + 12 delta + 12 delta-delta + 1 energia + 1 delta energia + 1 delta-delta energia)

#### `melFilterBank.m`
**Banco de filtros Mel.** Genera una matriz dispersa de `p` filtros triangulares (por defecto 20-26) espaciados uniformemente en la escala Mel. Cada filtro multiplica el espectro de frecuencia y suma las contribuciones, simulando como el oido humano percibe las frecuencias.

### Cuantizacion Vectorial

#### `vqCodeBook.m`
**Algoritmo LBG (Linde-Buzo-Gray).** Crea un codebook de `k` centroides a partir de los vectores de entrenamiento:
1. Inicializa con el centroide global (media de todos los vectores)
2. **Split:** Duplica cada centroide con una pequeña perturbacion `(1+e)` y `(1-e)`
3. **Asignacion:** Asigna cada vector de entrenamiento al centroide mas cercano
4. **Actualizacion:** Recalcula cada centroide como la media de los vectores asignados
5. **Convergencia:** Repite hasta que la distorsion relativa sea menor a `e=0.0001`
6. Repite el split hasta obtener `k` centroides (log2(k) iteraciones: 1, 2, 4, 8, 16, 32...)

#### `distance.m`
**Distancia Euclidea por pares.** Calcula la distancia euclidiana entre cada par de vectores columna de dos matrices. Optimizado para evitar bucles anidados usando expansion vectorizada.

### Clasificacion

#### `test.m` y `train.m`
Versiones originales del tutorial base (reconocimiento de locutores, no de palabras). No se usan en el flujo principal actual.

### Organizacion de Datos

#### `organize.py`
Script auxiliar que reorganiza los audios de la carpeta `voces/` en la estructura que espera el codigo (`locutores/`). Convierte MP3/OGG a WAV 16kHz mono con ffmpeg.

---

## Estructura de Directorios

```
Speech-Recognition-master/
├── main.m                 Script principal
├── live_demo.m            Demo en vivo
├── live_test.m            Funcion de grabacion y prueba en vivo
├── train_word.m           Entrenamiento por palabra
├── test_word.m            Clasificacion de un audio
├── preprocess.m           Preprocesamiento de señal
├── mfcc.m                 Extraccion de MFCC
├── melFilterBank.m        Banco de filtros Mel
├── vqCodeBook.m           Algoritmo LBG de cuantizacion vectorial
├── distance.m             Distancia Euclidea
├── train.m                (no usado) Tutorial original
├── test.m                 (no usado) Tutorial original
├── locutores/
│   ├── Dulce/
│   │   └── Audios/        palabra_01.wav ... palabra_05.wav
│   ├── Jayme/
│   │   └── Audios/        55-60 audios por locutor
│   ├── Leonel/
│   │   └── Audios/
│   ├── Oscar/
│   │   └── Audios/
│   └── Rodrigo/
│       └── Audios/
└── README.md
```

Cada locutor en `locutores/` debe tener una carpeta `Audios/` con archivos nombrados como `palabra_NN.wav` (ej: `arriba_01.wav`, `abajo_05.wav`, etc.).

---

## Flujo de Datos

```
Audio (WAV)
    │
    ▼
preprocess.m
    ├── Pre-enfasis (realce de altas frecuencias)
    ├── VAD (eliminacion de silencios)
    └── Normalizacion de amplitud
    │
    ▼
mfcc.m
    ├── Framing + Ventana Hamming
    ├── FFT
    ├── Banco de filtros Mel (26 filtros)
    ├── Log + DCT
    ├── 12 coeficientes MFCC
    ├── Delta + Delta-Delta
    ├── Energia + Delta + Delta-Delta
    └── Normalizacion por media
    │
    ▼
Entrenamiento:    vqCodeBook.m → codebook de 32 centroides por palabra
Prueba:           distance.m   → minima distancia al codebook
```

---

## Como Usar

### 1. Requisitos
- MATLAB R2015b o superior (o MATLAB Online)
- Toolbox de Procesamiento de Señales (Signal Processing Toolbox)

### 2. Estructura de datos
Coloca los audios en `locutores/` con el formato:
```
locutores/
└── NombreLocutor/
    └── Audios/
        ├── palabra_01.wav
        ├── palabra_02.wav
        └── ...
```

Si tienes audios en otros formatos (MP3, OGG) o distribuidos en carpetas, usa `organize.py` para reorganizarlos.

### 3. Ejecutar
```matlab
>> main
```
El programa te pedira seleccionar que locutor usar para prueba.

### 4. Demo en vivo (solo MATLAB Desktop)
```matlab
>> live_demo
```
Requiere haber ejecutado `main` antes para generar `codebooks.mat`.

---

## Configuracion

En `main.m` puedes ajustar:

| Variable | Default | Descripcion |
|----------|---------|-------------|
| `k` | 32 | Centroides del codebook. Mayor valor = mas precision pero mas lento |
| `numReps` | 5 | Repeticiones por palabra esperadas por cada locutor |
| `palabras` | 12 palabras | Agrega o quita palabras del diccionario |
| `locutoresDir` | `'./locutores'` | Ruta a la carpeta de locutores |

---

## Precision

La precision depende de:
- **Cantidad de locutores** de entrenamiento (a mas locutores, mejor generalizacion)
- **Calidad de los audios** (misma frecuencia de muestreo, mismo microfono)
- **Numero de repeticiones** por palabra
- **Tamaño del codebook** `k`

Valores tipicos con 5 locutores, 5 repeticiones y k=32: **60-80%** de precision.
