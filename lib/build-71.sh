#!/bin/bash

build_multi_format_output() {
    local drums="$1"
    local dry_vocal="$2"
    local bass="$3"
    local guitar="$4"
    local piano="$5"
    local other="$6"
    local echo_tail="$7"
    local video_file="$8"
    local metadata_source="$9"
    local output_mkv="${10}"

    local input_args=(
        -i "$drums" -i "$dry_vocal" -i "$bass"
        -i "$guitar" -i "$piano" -i "$other" -i "$echo_tail"
    )

    local map_args=()
    local has_video="false"
    if [ -n "$video_file" ] && [ -f "$video_file" ]; then
        input_args+=( -i "$video_file" )
        has_video="true"
    fi

    if [ -n "$metadata_source" ] && [ -f "$metadata_source" ]; then
        input_args+=( -i "$metadata_source" )
    fi

    local filter='
        [0:a]asplit=2[drums_hp_in][drums_lp_in];
        [drums_hp_in]highpass=f=100,channelsplit=channel_layout=stereo[drums_l][drums_r];
        [drums_lp_in]lowpass=f=120,pan=mono|c0=0.5*c0+0.5*c1[drums_bass_mono];
        [2:a]pan=mono|c0=0.5*c0+0.5*c1[bass_mono];
        [drums_bass_mono][bass_mono]amix=inputs=2:normalize=0[lfe];
        [1:a]pan=mono|c0=0.5*c0+0.5*c1[vocals_mono];
        [3:a]channelsplit=channel_layout=stereo[guitar_l][guitar_r];
        [4:a]channelsplit=channel_layout=stereo[piano_l][piano_r];
        [5:a]channelsplit=channel_layout=stereo[other_l_src][other_r_src];
        [other_l_src]asplit=2[other_l_sides][other_l_back];
        [other_r_src]asplit=2[other_r_sides][other_r_back];
        [6:a]channelsplit=channel_layout=stereo[echo_l][echo_r];
        [drums_l][echo_l]amix=inputs=2:weights=1.0 0.4:normalize=0[fl_out];
        [drums_r][echo_r]amix=inputs=2:weights=1.0 0.4:normalize=0[fr_out];
        [piano_l][other_l_sides]amix=inputs=2:weights=1.0 0.3:normalize=0[sl_out];
        [piano_r][other_r_sides]amix=inputs=2:weights=1.0 0.3:normalize=0[sr_out];
        [guitar_l][other_l_back]amix=inputs=2:weights=1.0 0.7:normalize=0[bl_out];
        [guitar_r][other_r_back]amix=inputs=2:weights=1.0 0.7:normalize=0[br_out];
        [fl_out][fr_out][vocals_mono][lfe][sl_out][sr_out][bl_out][br_out]join=inputs=8:channel_layout=7.1[stream_71_src];
        [stream_71_src]asplit=5[stream_71][copy_for_51][copy_for_21][copy_for_stereo][copy_for_mono];
        [copy_for_51]pan=5.1(side)|FL=FL|FR=FR|FC=FC|LFE=LFE|SL=SL+0.707*BL|SR=SR+0.707*BR[stream_51];
        [copy_for_21]pan=2.1|FL=FL+0.707*FC+0.707*SL+0.5*BL|FR=FR+0.707*FC+0.707*SR+0.5*BR|LFE=LFE[stream_21];
        [copy_for_stereo]pan=stereo|FL=FL+0.707*FC+0.707*SL+0.5*BL|FR=FR+0.707*FC+0.707*SR+0.5*BR[stream_stereo];
        [copy_for_mono]pan=mono|c0=0.2*FL+0.2*FR+0.2*FC+0.1*SL+0.1*SR+0.1*BL+0.1*BR[stream_mono]
    '

    local video_input_idx=7
    local metadata_input_idx=8
    if [ "$has_video" = "true" ]; then
        map_args+=( -map "${video_input_idx}:v:0" -c:v copy )
        metadata_input_idx=8
    else
        metadata_input_idx=7
    fi
    if [ -z "$metadata_source" ] || [ ! -f "$metadata_source" ]; then
        metadata_input_idx=""
    fi

    map_args+=(
        -map "[stream_71]"
        -map "[stream_51]"
        -map "[stream_21]"
        -map "[stream_stereo]"
        -map "[stream_mono]"
    )

    if [ -n "$metadata_input_idx" ]; then
        if [ "$has_video" = "true" ] && [ "$metadata_input_idx" -le "$video_input_idx" ]; then
            metadata_input_idx=$((video_input_idx + 1))
        fi
        map_args+=( -map_metadata "$metadata_input_idx" )
    fi

    ffmpeg -hide_banner -loglevel error -y \
        "${input_args[@]}" \
        -filter_complex "$filter" \
        "${map_args[@]}" \
        -c:a flac -ar 48000 -sample_fmt s16 \
        -metadata:s:a:0 title="7.1 Surround" \
        -metadata:s:a:0 language=und \
        -metadata:s:a:1 title="5.1 Surround" \
        -metadata:s:a:1 language=und \
        -metadata:s:a:2 title="2.1 (Stereo + LFE)" \
        -metadata:s:a:2 language=und \
        -metadata:s:a:3 title="Stereo" \
        -metadata:s:a:3 language=und \
        -metadata:s:a:4 title="Mono" \
        -metadata:s:a:4 language=und \
        -disposition:a:0 default \
        "$output_mkv"
}
