#include <algorithm> // std::sort 
#include <vector>    
#include <cstring>   // std::memcpy 
#include <cmath>     // std::abs 
#include <thread>    


void ProcessChunkCpp(unsigned char* imgData, const unsigned char* imgCopy, int width, int stride, int yStart, int yEnd, int filterSize)
{

    int radius = filterSize / 2;                
    int windowPixels = filterSize * filterSize; 
    int medianIndex = windowPixels / 2;        

    std::vector<unsigned char> window(windowPixels);

    for (int y = yStart; y < yEnd; y++)
    {
        if (y < radius || y >= (yEnd + radius)) continue;


        for (int x = radius; x < width - radius; x++)
        {
   
            for (int c = 0; c < 3; c++)
            {
                int k = 0;

                for (int fy = -radius; fy <= radius; fy++)
                {
                    for (int fx = -radius; fx <= radius; fx++)
                    {

                        window[k++] = imgCopy[(y + fy) * stride + (x + fx) * 3 + c];
                    }
                }
                
                std::sort(window.begin(), window.end());


                imgData[y * stride + x * 3 + c] = window[medianIndex];
            }
        }
    }
}


extern "C" void __stdcall ProcessChunkAsm(
    unsigned char* imgData,       // wsk na dane wyjœciowe
    const unsigned char* imgCopy, // wsk na dane wejœciowe (kopia)
    int width,                    // szerokoœæ obrazu
    int height,                   // zysokoœæ obrazu
    int dstStride,                // stride wyjœciowy (mo¿e byæ ujemny!)
    int srcStride,                // stride wejœciowy (zawsze dodatni - bo to nasza kopia)
    int yStart,                   // pocz¹tkowy wiersz dla w¹tku
    int yEnd                      // koñcowy wiersz dla w¹tku
);


extern "C" {

    
    __declspec(dllexport) void __stdcall MedianFilterCpp(unsigned char* imgData, int width, int height, int stride, int numThreads, int filterSize)
    {
        int safeStride = std::abs(stride);
        int dataSize = safeStride * height;


        std::vector<unsigned char> imgCopy(dataSize);
        std::memcpy(imgCopy.data(), imgData, dataSize);

        if (numThreads < 1) numThreads = 1;

        int radius = filterSize / 2;

        int rowsToProcess = height - (2 * radius);
        if (rowsToProcess < 0) rowsToProcess = 0;

        int chunkHeight = rowsToProcess / numThreads;
        int currentY = radius; 

        std::vector<std::thread> threadsVector; 

        for (int i = 0; i < numThreads; i++)
        {
            int start = currentY;
            int end = (i == numThreads - 1) ? (height - radius) : (start + chunkHeight);

            if (start < end)
            {
                threadsVector.emplace_back(ProcessChunkCpp, imgData, imgCopy.data(), width, safeStride, start, end, filterSize);
            }
            currentY = end;
        }


        for (auto& t : threadsVector) t.join();
    }

    //Assemblo code version:
    __declspec(dllexport) void __stdcall MedianFilterAsm(unsigned char* imgData, int width, int height, int stride, int numThreads, int filterSize)
    {
        int safeStride = std::abs(stride); 
        int dataSize = safeStride * height;
        std::vector<unsigned char> imgCopy(dataSize);
        std::memcpy(imgCopy.data(), imgData, dataSize);

        if (numThreads < 1) numThreads = 1;

        int chunkHeight = (height - 2) / numThreads;
        int currentY = 1;

        std::vector<std::thread> threadsVector;

        for (int i = 0; i < numThreads; i++)
        {
            int start = currentY;
            int end = (i == numThreads - 1) ? height - 1 : start + chunkHeight;

            if (start < end)
            {
\
                threadsVector.emplace_back(ProcessChunkAsm, imgData, imgCopy.data(), width, height, stride, safeStride, start, end);
            }
            currentY = end;
        }

        for (auto& t : threadsVector) t.join();
    }
}