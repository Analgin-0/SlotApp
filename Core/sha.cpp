#include "SHA.hpp"
#include <stdio.h>
#include <string>
#include <string.h>
#include <iostream>
#include <iomanip>
#include <cstdint>
#include <sstream>
#include <fstream>
#include <cstdint>

typedef uint32_t uint32;
typedef unsigned long long uint64;





std::string SHA256::hash(const std::string input)
{
    size_t nBuffer;
    uint32** buffer;
    uint32* h = new uint32[HASH_LEN];

    buffer = preprocess((unsigned char*)input.c_str(), nBuffer);
    process(buffer, nBuffer, h);

    freeBuffer(buffer, nBuffer);
    return digest(h);
}


uint32** SHA256::preprocess(const unsigned char* input, size_t& nBuffer)
{

    size_t mLen = strlen((const char*)input);
    size_t l = mLen * CHAR_LEN_BITS;
    size_t k = (448 - 1 - l) % MESSAGE_BLOCK_SIZE;
    nBuffer = (l + 1 + k + 64) / MESSAGE_BLOCK_SIZE;

    uint32** buffer = new uint32 * [nBuffer];

    for (size_t i = 0; i < nBuffer; i++) {
        buffer[i] = new uint32[SEQUENCE_LEN];
    }

    uint32 in;
    size_t index;


    for (size_t i = 0; i < nBuffer; i++)
    {
        for (size_t j = 0; j < SEQUENCE_LEN; j++)
        {
            in = static_cast<unsigned int>(0x00u);
            for (size_t k = 0; k < WORD_LEN; k++)
            {
                index = i * 64 + j * 4 + k;
                if (index < mLen) {
                    in = in << 8 | static_cast<unsigned int>(input[index]);
                }
                else if (index == mLen) {
                    in = in << 8 | static_cast<unsigned int>(0x80u);
                }
                else {
                    in = in << 8 | static_cast<unsigned int>(0x00u);
                }
            }
            buffer[i][j] = in;
        }
    }


    appendLen(l, buffer[nBuffer - 1][SEQUENCE_LEN - 1], buffer[nBuffer - 1][SEQUENCE_LEN - 2]);
    return buffer;
}


void SHA256::process(uint32** buffer, size_t nBuffer, uint32* h)
{

    uint32* s = new uint32[WORKING_VAR_LEN];
    uint32* w = new uint32[MESSAGE_SCHEDULE_LEN];

    memcpy(h, hPrime, WORKING_VAR_LEN * sizeof(uint32));

    for (size_t i = 0; i < nBuffer; i++) {

        memcpy(w, buffer[i], SEQUENCE_LEN * sizeof(uint32));


        for (size_t j = 16; j < MESSAGE_SCHEDULE_LEN; j++)
            w[j] = w[j - 16] + sig0_s(w[j - 15]) + w[j - 7] + sig1_s(w[j - 2]);


        memcpy(s, h, WORKING_VAR_LEN * sizeof(uint32));


        for (size_t j = 0; j < MESSAGE_SCHEDULE_LEN; j++)
        {
            uint32 temp1 = s[7] + Sig1_s(s[4]) + Ch_s(s[4], s[5], s[6]) + k[j] + w[j];
            uint32 temp2 = Sig0_s(s[0]) + Maj_s(s[0], s[1], s[2]);

            s[7] = s[6];
            s[6] = s[5];
            s[5] = s[4];
            s[4] = s[3] + temp1;
            s[3] = s[2];
            s[2] = s[1];
            s[1] = s[0];
            s[0] = temp1 + temp2;
        }


        for (size_t j = 0; j < WORKING_VAR_LEN; j++)
            h[j] += s[j];

    }
    delete[] s;
    delete[] w;
}


void SHA256::appendLen(size_t l, uint32& lo, uint32& hi)
{

    lo = l;
    hi = 0x00;
}

std::string SHA256::digest(uint32* h)
{

    std::stringstream ss;
    for (size_t i = 0; i < OUTPUT_LEN; i++) {
        ss << std::hex << std::setw(8) << std::setfill('0') << h[i];
    }
    delete[] h;
    return ss.str();
}


void SHA256::freeBuffer(uint32** buffer, size_t nBuffer)
{

    for (size_t i = 0; i < nBuffer; i++)
        delete[] buffer[i];


    delete[] buffer;
}



std::string SHA256::hash_file(const std::string& path)
{
    std::fstream fs;
    fs.open(path);
    if (not fs.is_open())
        throw std::runtime_error("failed open file");


    std::stringstream sstr;

    while (fs >> sstr.rdbuf());


    fs.close();
    return hash(sstr.str());
}







std::string SHA384::hash(const std::string input)
{
    size_t nBuffer;
    uint64** buffer;
    uint64* h = new uint64[HASH_LEN];

    buffer = preprocess((unsigned char*)input.c_str(), nBuffer);
    process(buffer, nBuffer, h);

    freeBuffer(buffer, nBuffer);
    return digest(h);
}

uint64** SHA384::preprocess(const unsigned char* input, size_t& nBuffer)
{

    size_t mLen = strlen((const char*)input);
    size_t l = mLen * CHAR_LEN_BITS;
    size_t k = (896 - 1 - l) % MESSAGE_BLOCK_SIZE;
    nBuffer = (l + 1 + k + 128) / MESSAGE_BLOCK_SIZE;

    uint64** buffer = new uint64 * [nBuffer];

    for (size_t i = 0; i < nBuffer; i++) {
        buffer[i] = new uint64[SEQUENCE_LEN];
    }

    uint64 in;
    size_t index;


    for (size_t i = 0; i < nBuffer; i++)
    {
        for (size_t j = 0; j < SEQUENCE_LEN; j++)
        {
            in = 0x0ULL;
            for (size_t k = 0; k < WORD_LEN; k++)
            {
                index = i * 128 + j * 8 + k;
                if (index < mLen)
                    in = in << 8 | (uint64)input[index];
                else if (index == mLen)
                    in = in << 8 | 0x80ULL;
                else
                    in = in << 8 | 0x0ULL;

            }
            buffer[i][j] = in;
        }
    }


    appendLen(l, buffer[nBuffer - 1][SEQUENCE_LEN - 1], buffer[nBuffer - 1][SEQUENCE_LEN - 2]);
    return buffer;
}


void SHA384::process(uint64** buffer, size_t nBuffer, uint64* h)
{

    uint64* s = new uint64[WORKING_VAR_LEN];
    uint64* w = new uint64[MESSAGE_SCHEDULE_LEN];

    memcpy(h, hPrime, WORKING_VAR_LEN * sizeof(uint64));

    for (size_t i = 0; i < nBuffer; i++) {

        memcpy(w, buffer[i], SEQUENCE_LEN * sizeof(uint64));


        for (size_t j = 16; j < MESSAGE_SCHEDULE_LEN; j++)
            w[j] = w[j - 16] + sig0(w[j - 15]) + w[j - 7] + sig1(w[j - 2]);


        memcpy(s, h, WORKING_VAR_LEN * sizeof(uint64));

        // Compression
        for (size_t j = 0; j < MESSAGE_SCHEDULE_LEN; j++)
        {
            uint64 temp1 = s[7] + Sig1(s[4]) + Ch(s[4], s[5], s[6]) + k[j] + w[j];
            uint64 temp2 = Sig0(s[0]) + Maj(s[0], s[1], s[2]);

            s[7] = s[6];
            s[6] = s[5];
            s[5] = s[4];
            s[4] = s[3] + temp1;
            s[3] = s[2];
            s[2] = s[1];
            s[1] = s[0];
            s[0] = temp1 + temp2;
        }


        for (size_t j = 0; j < WORKING_VAR_LEN; j++)
            h[j] += s[j];
    }
    delete[] s;
    delete[] w;
}


void SHA384::appendLen(size_t l, uint64& lo, uint64& hi)
{
    lo = l;
    hi = 0x00ULL;
}


std::string SHA384::digest(uint64* h)
{
    std::stringstream ss;
    for (size_t i = 0; i < OUTPUT_LEN; i++) {
        ss << std::hex << std::setw(16) << std::setfill('0') << h[i];
    }
    delete[] h;
    return ss.str();
}


void SHA384::freeBuffer(uint64** buffer, size_t nBuffer)
{
    for (size_t i = 0; i < nBuffer; i++) {
        delete[] buffer[i];
    }

    delete[] buffer;
}



std::string SHA384::hash_file(const std::string& path)
{
    std::fstream fs;
    fs.open(path);
    if (not fs.is_open())
        throw std::runtime_error("failed open file");


    std::stringstream sstr;

    while (fs >> sstr.rdbuf());


    fs.close();
    return hash(sstr.str());
}

std::string SHA512::hash(const std::string input)
{
    size_t nBuffer;
    uint64** buffer;
    uint64* h = new uint64[HASH_LEN];

    buffer = preprocess((unsigned char*)input.c_str(), nBuffer);
    process(buffer, nBuffer, h);

    freeBuffer(buffer, nBuffer);
    return digest(h);
}

std::string SHA512::hash_file(const std::string& path)
{
    std::fstream fs;
    fs.open(path);
    if (not fs.is_open())
        throw std::runtime_error("failed open file");


    std::stringstream sstr;

    while (fs >> sstr.rdbuf());


    fs.close();
    return hash(sstr.str());
}


uint64** SHA512::preprocess(const unsigned char* input, size_t& nBuffer)
{

    size_t mLen = strlen((const char*)input);
    size_t l = mLen * CHAR_LEN_BITS;
    size_t k = (896 - 1 - l) % MESSAGE_BLOCK_SIZE;
    nBuffer = (l + 1 + k + 128) / MESSAGE_BLOCK_SIZE;

    uint64** buffer = new uint64 * [nBuffer];

    for (size_t i = 0; i < nBuffer; i++) {
        buffer[i] = new uint64[SEQUENCE_LEN];
    }

    uint64 in;
    size_t index;


    for (size_t i = 0; i < nBuffer; i++) {
        for (size_t j = 0; j < SEQUENCE_LEN; j++) {
            in = 0x0ULL;
            for (size_t k = 0; k < WORD_LEN; k++) {
                index = i * 128 + j * 8 + k;
                if (index < mLen) {
                    in = in << 8 | (uint64)input[index];
                }
                else if (index == mLen) {
                    in = in << 8 | 0x80ULL;
                }
                else {
                    in = in << 8 | 0x0ULL;
                }
            }
            buffer[i][j] = in;
        }
    }


    appendLen(l, buffer[nBuffer - 1][SEQUENCE_LEN - 1], buffer[nBuffer - 1][SEQUENCE_LEN - 2]);
    return buffer;
}


void SHA512::process(uint64** buffer, size_t nBuffer, uint64* h) {
    uint64* s = new uint64[WORKING_VAR_LEN];
    uint64* w = new uint64[MESSAGE_SCHEDULE_LEN];

    memcpy(h, hPrime, WORKING_VAR_LEN * sizeof(uint64));

    for (size_t i = 0; i < nBuffer; i++) {

        memcpy(w, buffer[i], SEQUENCE_LEN * sizeof(uint64));


        for (size_t j = 16; j < MESSAGE_SCHEDULE_LEN; j++) {
            w[j] = w[j - 16] + sig0(w[j - 15]) + w[j - 7] + sig1(w[j - 2]);
        }

        memcpy(s, h, WORKING_VAR_LEN * sizeof(uint64));


        for (size_t j = 0; j < MESSAGE_SCHEDULE_LEN; j++) {
            uint64 temp1 = s[7] + Sig1(s[4]) + Ch(s[4], s[5], s[6]) + k[j] + w[j];
            uint64 temp2 = Sig0(s[0]) + Maj(s[0], s[1], s[2]);

            s[7] = s[6];
            s[6] = s[5];
            s[5] = s[4];
            s[4] = s[3] + temp1;
            s[3] = s[2];
            s[2] = s[1];
            s[1] = s[0];
            s[0] = temp1 + temp2;
        }


        for (size_t j = 0; j < WORKING_VAR_LEN; j++) {
            h[j] += s[j];
        }
    }
    delete[] s;
    delete[] w;
}


void SHA512::appendLen(size_t l, uint64& lo, uint64& hi) {
    lo = l;
    hi = 0x00ULL;
}


std::string SHA512::digest(uint64* h) {
    std::stringstream ss;
    for (size_t i = 0; i < OUTPUT_LEN; i++) {
        ss << std::hex << std::setw(16) << std::setfill('0') << h[i];
    }
    delete[] h;
    return ss.str();
}


void SHA512::freeBuffer(uint64** buffer, size_t nBuffer) {
    for (size_t i = 0; i < nBuffer; i++)
        delete[] buffer[i];


    delete[] buffer;
}