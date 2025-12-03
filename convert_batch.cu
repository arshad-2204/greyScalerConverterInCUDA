#include "convert_batch.hpp"

#include <tiffio.h>
#include <filesystem>
#include <iostream>
#include <vector>
#include <string>
#include <cassert>

#include <algorithm>
#include <cctype>

namespace fs = std::filesystem;

//------------------------------------------------------------------------------
// Host-side helpers
//------------------------------------------------------------------------------

std::vector<std::string>
listTiffFiles(const std::string& directory) {
    std::vector<std::string> out;
    for (const auto& entry : fs::directory_iterator(directory)) {
        if (!entry.is_regular_file()) continue;
        auto ext = entry.path().extension().string();
        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
        if (ext == ".tif" || ext == ".tiff")
            out.push_back(entry.path().string());
    }
    return out;
}

//------------------------------------------------------------------------------
// Single-image pipeline
//------------------------------------------------------------------------------
void processImage(const std::string& inPath,
                  const std::string& outPath,
                  int threadsPerBlock) {
    TIFF* tif = TIFFOpen(inPath.c_str(), "r");
    if (!tif) {
        std::cerr << "ERROR: Cannot open “" << inPath << "”\n";
        return;
    }

    uint32_t w=0, h=0;
    TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &w);
    TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &h);
    int total = w * h;

    uint32_t* h_raster = (uint32_t*) _TIFFmalloc(total * sizeof(uint32_t));
    uint8_t*  h_gray   = (uint8_t*)  std::malloc(total * sizeof(uint8_t));
    assert(h_raster && h_gray);

    if (!TIFFReadRGBAImageOriented(tif, w, h, h_raster,
                                   ORIENTATION_TOPLEFT, 0)) {
        std::cerr << "ERROR: TIFFReadRGBAImage failed for “"
                  << inPath << "”\n";
        TIFFClose(tif);
        return;
    }
    TIFFClose(tif);

    uint32_t* d_raster = nullptr;
    uint8_t*  d_gray   = nullptr;
    cudaMalloc(&d_raster, total * sizeof(uint32_t));
    cudaMalloc(&d_gray,   total * sizeof(uint8_t));

    cudaMemcpy(d_raster, h_raster,
               total * sizeof(uint32_t),
               cudaMemcpyHostToDevice);

    int blocks = (total + threadsPerBlock - 1) / threadsPerBlock;
    rgb2grayKernel<<<blocks, threadsPerBlock>>>(d_raster, d_gray, total);
    cudaDeviceSynchronize();

    cudaMemcpy(h_gray, d_gray,
               total * sizeof(uint8_t),
               cudaMemcpyDeviceToHost);

    TIFF* out = TIFFOpen(outPath.c_str(), "w");
    if (out) {
        TIFFSetField(out, TIFFTAG_IMAGEWIDTH,       w);
        TIFFSetField(out, TIFFTAG_IMAGELENGTH,      h);
        TIFFSetField(out, TIFFTAG_SAMPLESPERPIXEL,  1);
        TIFFSetField(out, TIFFTAG_BITSPERSAMPLE,    8);
        TIFFSetField(out, TIFFTAG_ORIENTATION,      ORIENTATION_TOPLEFT);
        TIFFSetField(out, TIFFTAG_PHOTOMETRIC,      PHOTOMETRIC_MINISBLACK);
        TIFFSetField(out, TIFFTAG_PLANARCONFIG,     PLANARCONFIG_CONTIG);

        tsize_t linebytes = w * sizeof(uint8_t);
        uint8_t* buf = (uint8_t*) _TIFFmalloc(linebytes);
        for (uint32_t row = 0; row < h; ++row) {
            memcpy(buf, h_gray + row * w, linebytes);
            TIFFWriteScanline(out, buf, row, 0);
        }
        _TIFFfree(buf);
        TIFFClose(out);
    } else {
        std::cerr << "ERROR: Cannot open “" << outPath << "” for write\n";
    }

    _TIFFfree(h_raster);
    free(h_gray);
    cudaFree(d_raster);
    cudaFree(d_gray);

    std::cout << "Done: “" << inPath << "” → “" << outPath << "”\n";
}

//------------------------------------------------------------------------------
// CUDA kernel
//------------------------------------------------------------------------------
__global__
void rgb2grayKernel(const uint32_t* raster,
                    uint8_t*      gray,
                    int           totalPixels) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= totalPixels) return;

    uint32_t pix = raster[idx];
    float r = float((pix      ) & 0xFF);
    float g = float((pix >>  8) & 0xFF);
    float b = float((pix >> 16) & 0xFF);
    gray[idx] = uint8_t(fminf(0.3f*r + 0.59f*g + 0.11f*b, 255.0f));
}

//------------------------------------------------------------------------------
// main: batch over folder
//------------------------------------------------------------------------------
int main(int argc, char** argv) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0]
                  << " <input_dir> <output_dir> [-t threadsPerBlock]\n";
        return 1;
    }

    std::string inDir  = argv[1];
    std::string outDir = argv[2];
    int threadsPerBlock = 256;
    for (int i = 3; i+1 < argc; i += 2) {
        if (std::string(argv[i]) == "-t")
            threadsPerBlock = std::stoi(argv[i+1]);
    }

    fs::create_directories(outDir);
    auto files = listTiffFiles(inDir);
    for (auto& inPath : files) {
        auto stem = fs::path(inPath).stem().string();
        std::string outPath = outDir + "/" + stem + "_gray.tiff";
        processImage(inPath, outPath, threadsPerBlock);
    }
    return 0;
}
