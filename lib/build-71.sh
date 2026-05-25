#!/bin/bash

build_71_audio() {
    local drums="$1"
    local dry_vocal="$2"
    local bass="$3"
    local other="$4"
    local echo_tail="$5"
    local output_flac="$6"

    ffmpeg -hide_banner -loglevel error -y \
        -i "$drums" \
        -i "$dry_vocal" \
        -i "$bass" \
        -i "$other" \
        -i "$echo_tail" \
        -filter_complex "
            [0:a]asplit=2[drums_hp_in][drums_lp_in];
            [drums_hp_in]highpass=f=250,channelsplit=channel_layout=stereo[drums_l][drums_r];
            [drums_lp_in]lowpass=f=120,pan=mono|c0=0.5*c0+0.5*c1[drums_bass_mono];
            [2:a]pan=mono|c0=0.5*c0+0.5*c1[bass_mono];
            [drums_bass_mono][bass_mono]amix=inputs=2:normalize=0[lfe];
            [1:a]pan=mono|c0=0.5*c0+0.5*c1[vocals_mono];
            [3:a]channelsplit=channel_layout=stereo[other_l][other_r];
            [4:a]channelsplit=channel_layout=stereo[echo_l][echo_r];
            [drums_l][echo_l]amix=inputs=2:normalize=0[fl_out];
            [drums_r][echo_r]amix=inputs=2:normalize=0[fr_out];
            [fl_out][fr_out][vocals_mono][lfe][other_l][other_r][other_l][other_r]join=inputs=8:channel_layout=7.1:map=0.0-FL|1.0-FR|2.0-FC|3.0-LFE|4.0-SL|5.0-SR|6.0-BL|7.0-BR[out]
        " \
        -map "[out]" \
        -c:a flac -ar 48000 -sample_fmt s16 \
        "$output_flac"
}

mux_video_with_71_audio() {
    local video_file="$1"
    local audio_71="$2"
    local metadata_source="$3"
    local output_mkv="$4"

    ffmpeg -hide_banner -loglevel error -y \
        -i "$video_file" \
        -i "$audio_71" \
        -i "$metadata_source" \
        -map 0:v:0 -map 1:a:0 -map_metadata 2 \
        -c:v copy -c:a copy \
        "$output_mkv"
}
