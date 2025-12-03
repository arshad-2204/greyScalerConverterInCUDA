# Makefile

NVCC        := nvcc
CXXFLAGS    := -std=c++17 -I/usr/include/opencv4
OPENCV_LIBS := -lopencv_core -lopencv_imgcodecs

TARGET      := convert_gray
SRC         := ConvertRGBToGrey.cu

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(NVCC) $(CXXFLAGS) $< -o $@ $(OPENCV_LIBS)

clean:
	rm -f $(TARGET)
