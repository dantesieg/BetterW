/********************************************************************
 *                                                                  *
 * THIS FILE IS PART OF THE libopusfile SOFTWARE CODEC SOURCE CODE. *
 * USE, DISTRIBUTION AND REPRODUCTION OF THIS LIBRARY SOURCE IS     *
 * GOVERNED BY A BSD-STYLE SOURCE LICENSE INCLUDED WITH THIS SOURCE *
 * IN 'COPYING'. PLEASE READ THESE TERMS BEFORE DISTRIBUTING.       *
 *                                                                  *
 * THE libopusfile SOURCE CODE IS (C) COPYRIGHT 1994-2012           *
 * by the Xiph.Org Foundation and contributors http://www.xiph.org/ *
 *                                                                  *
 ********************************************************************/

/** `COPYING` - `libopusfile`:
 Copyright (c) 1994-2013 Xiph.Org Foundation and contributors
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of the Xiph.Org Foundation nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/**
 * pr0crustes:
 * This file contains code from `libopusfile` example `opusfile_example.c`.
 * The code was modified to fulfill my need.
 * All code used is conforming to the license.
 */

#include "_opus_conversor.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

#include <opus/opusfile.h>


static void put_le32(unsigned char *header, opus_uint32 value) {
    header[0] = (unsigned char) (value & 0xFF);
    header[1] = (unsigned char) (value >> 8 & 0xFF);
    header[2] = (unsigned char) (value >> 16 & 0xFF);
    header[3] = (unsigned char) (value >> 24 & 0xFF);
}


static int make_wav_header(unsigned char header[44], ogg_int64_t duration) {

    static const unsigned char WAV_HEADER_TEMPLATE[44] = {
        'R',   'I',  'F',  'F', 0xFF, 0xFF, 0xFF, 0x7F, 
        'W',   'A',  'V',  'E',  'f',  'm',  't',  ' ', 
        0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 
        0x80, 0xBB, 0x00, 0x00, 0x00, 0xEE, 0x02, 0x00, 
        0x04, 0x00, 0x10, 0x00,  'd',  'a',  't',  'a', 
        0xFF, 0xFF, 0xFF, 0x7F
    };

    memcpy(header, WAV_HEADER_TEMPLATE, sizeof(WAV_HEADER_TEMPLATE));

    if (duration > 0) {
        if (duration > 0x1FFFFFF6) {
            return PR0CRUSTES_FAIL;
        } else {
            opus_uint32 audio_size = (opus_uint32) (duration * 4);
            put_le32(header + 4, audio_size + 36);
            put_le32(header + 40, audio_size);
        }
    }
    return PR0CRUSTES_OK;
}


/**
 * 0 in case it goes right, negative values in case of failure.
 */
static int writeOpusAsWav(OggOpusFile *opusFile, FILE *outputFile) {
    unsigned char wav_header[44];
    make_wav_header(wav_header, 0);

    if (!fwrite(wav_header, sizeof(wav_header), 1, outputFile)) {
        return PR0CRUSTES_FAIL;
    }

    while(1) {
        opus_int16 pcm[120 * 48 * 2];
        unsigned char out[120 * 48 * 2 * 2];
        
        int read_frames = op_read_stereo(opusFile, pcm, sizeof(pcm) / sizeof(*pcm));
        if (read_frames <= 0) {
            return PR0CRUSTES_OK;
        }

        /* Ensure the data is little-endian before writing it out. */
        for(int i = 0; i < 2 * read_frames ; i++) {
            out[2 * i + 0] = (unsigned char) (pcm[i] & 0xFF);
            out[2 * i + 1] = (unsigned char) (pcm[i] >> 8 & 0xFF);
        }

        if (!fwrite(out, sizeof(*out) * 4 * read_frames, 1, outputFile)) {
            return PR0CRUSTES_FAIL;
        }
    }
}


/**
 * 0 in case it goes right, negative values in case of failure.
 */
int pr0crustes_opusToWav(const char * inFilePath, const char * outFilePath) {

    int err;

    OggOpusFile *opusFile = op_open_file(inFilePath, &err);
    FILE *outputFile = fopen(outFilePath, "w");

    if (opusFile == NULL || outputFile == NULL) {
        return PR0CRUSTES_FILE_ERROR;
    }

    int return_value = writeOpusAsWav(opusFile, outputFile);

    fclose(outputFile);
    op_free(opusFile);

    return return_value;
}
