#ifndef CONVERT_BATCH_HPP
#define CONVERT_BATCH_HPP

#include <string>
#include <vector>
#include <cstdint>

/// Scan a directory and return all files ending in “.tif” or “.tiff”
std::vector<std::string> listTiffFiles(const std::string &directory);

/// Load one TIFF, convert it on the GPU, and write out a grayscale TIFF
void processImage(const std::string &inPath,
                  const std::string &outPath,
                  int threadsPerBlock = 256);

/// CUDA kernel: each thread reads one RGBA uint32, writes one 8‑bit gray
__global__ void rgb2grayKernel(const uint32_t *raster,
                               uint8_t *gray,
                               int totalPixels);

#endif // CONVERT_BATCH_HPP
