# Batch Grayscale Conversion of Aerial TIFF Images Using CUDA

A small utility that scans a folder of high‑resolution TIFF images, converts each pixel from RGBA to 8‑bit grayscale on the GPU, and writes out `_gray.tiff` files. Leverages CUDA for parallel pixel processing and libtiff for fast disk I/O, while C++17’s `<filesystem>` handles directory traversal.

tldr: gray_out folder contains result and images contain orignal images images used are from the assignment links

---

## Table of Contents

- [Features](#features)  
- [Prerequisites](#prerequisites)  
- [Directory Structure](#directory-structure)  
- [Building](#building)  
- [Running](#running)  
- [Example](#example)  
- [License](#license)

---

## Features

- **Batch processing**: Automatically finds all `.tif`/`.tiff` files in an input folder.  
- **GPU‑accelerated**: Converts RGBA to grayscale in parallel on the CUDA device.  
- **LibTIFF I/O**: Fast, lossless reading/writing of TIFF images.  
- **Modern C++17**: Uses `<filesystem>` for clean directory traversal.

---

## Prerequisites

- **CUDA Toolkit** (10.x or newer)  
- **libtiff** development headers and library  
- A C++17‑capable host compiler (e.g., `g++`, `clang++`)  
- **make**, **bash**

_On Ubuntu/Debian, you can install dependencies via_  
```bash
sudo apt update
sudo apt install build-essential libtiff-dev cuda-toolkit make
```

Directory Structure
.
├── convert_batch.cu      # main batch + kernel implementation
├── convert_batch.hpp     # declarations for batch functions & kernel
├── Makefile              # build rules
├── run.sh                # simple runner script
└── images/               # (place your .tiff inputs here)

Building

From the project root, simply run:
```bash
make
```
This compiles convert_batch.cu into the convert_batch executable, linking against libtiff and the CUDA runtime.

If you ever need to clean up:

```bash
make clean
```

Running

You can invoke the tool directly:
```bash
./convert_batch <input_dir> <output_dir> [-t threadsPerBlock]
```
Or use the provided run.sh wrapper:
```bash
bash run.sh <input_dir> <output_dir> [threadsPerBlock]
```
<input_dir>: folder containing your .tif/.tiff files

<output_dir>: folder where *_gray.tiff files will be written (created if missing)

threadsPerBlock (optional): number of threads per CUDA block (default: 256)

Example

Place your aerial images in images/.

Build the project:
```bash
make
```
Run the batch conversion:
```bash
bash run.sh images/ gray_out/ 512
```
Check gray_out/ for your converted _gray.tiff files.

Also i have tried following as much as c++ guidelines as possible 
