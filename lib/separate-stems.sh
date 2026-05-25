#!/bin/bash

DEMUCS_MODEL_NAME="htdemucs_ft"
VOCAL_SEPARATOR_MODEL="model_bs_roformer_ep_368_sdr_12.9628.ckpt"
DEECHO_SEPARATOR_MODEL="UVR-DeEcho-DeReverb.pth"

get_demucs_model_name() { echo "$DEMUCS_MODEL_NAME"; }

get_demucs_shifts() {
    local backend="$1"
    if [ "$backend" = "cpu" ]; then echo "1"; else echo "4"; fi
}

build_separator_uv_args() {
    local backend="$1"
    local args="--python 3.11 --with audio-separator --with onnxruntime --with soundfile"
    local index
    index=$(get_torch_index_url "$backend")
    if [ -n "$index" ]; then
        args="$args --extra-index-url $index"
    fi
    echo "$args"
}

extract_vocals_with_separator() {
    local input_wav="$1"
    local output_dir="$2"
    local backend="$3"
    local sep_args
    sep_args=$(build_separator_uv_args "$backend")

    uv run $sep_args audio-separator "$input_wav" \
        --model_filename "$VOCAL_SEPARATOR_MODEL" \
        --output_dir "$output_dir" \
        --output_format WAV
}

split_vocal_dry_echo() {
    local vocal_wav="$1"
    local output_dir="$2"
    local backend="$3"
    local sep_args
    sep_args=$(build_separator_uv_args "$backend")

    uv run $sep_args audio-separator "$vocal_wav" \
        --model_filename "$DEECHO_SEPARATOR_MODEL" \
        --output_dir "$output_dir" \
        --output_format WAV
}

run_demucs() {
    local input_wav="$1"
    local output_dir="$2"
    local backend="$3"
    local device
    device=$(get_demucs_device "$backend")
    local uv_args
    uv_args=$(build_uv_args "$backend")
    local shifts
    shifts=$(get_demucs_shifts "$backend")

    uv run $uv_args demucs \
        -n "$DEMUCS_MODEL_NAME" \
        --shifts "$shifts" \
        -o "$output_dir" \
        --filename "{stem}.{ext}" \
        --device "$device" \
        "$input_wav"
}

find_separator_output() {
    local search_dir="$1"
    local pattern="$2"
    find "$search_dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | head -1
}

locate_vocal_wet_file() {
    local dir="$1"
    local f
    f=$(find_separator_output "$dir" "*(Vocals)*.wav")
    [ -n "$f" ] && { echo "$f"; return; }
    f=$(find "$dir" -maxdepth 1 -type f -iname "*vocals*.wav" 2>/dev/null \
        | grep -vi "no.*echo\|no.*reverb\|instrumental" | head -1)
    echo "$f"
}

locate_instrumental_file() {
    local dir="$1"
    local f
    f=$(find_separator_output "$dir" "*(Instrumental)*.wav")
    [ -n "$f" ] && { echo "$f"; return; }
    f=$(find "$dir" -maxdepth 1 -type f -iname "*instrumental*.wav" 2>/dev/null | head -1)
    echo "$f"
}

locate_dry_vocal_file() {
    local dir="$1"
    local f
    f=$(find "$dir" -maxdepth 1 -type f \
        \( -iname "*No Reverb*.wav" -o -iname "*No-Reverb*.wav" \
           -o -iname "*NoReverb*.wav" -o -iname "*No_Reverb*.wav" \
           -o -iname "*No Echo*.wav" -o -iname "*No-Echo*.wav" \
           -o -iname "*NoEcho*.wav" -o -iname "*No_Echo*.wav" \
           -o -iname "*Dry*.wav" \) 2>/dev/null | head -1)
    echo "$f"
}

locate_echo_tail_file() {
    local dir="$1"
    local f
    f=$(find "$dir" -maxdepth 1 -type f -iname "*Reverb*.wav" 2>/dev/null \
        | grep -viE "No[ _-]?Reverb" | head -1)
    [ -n "$f" ] && { echo "$f"; return; }
    f=$(find "$dir" -maxdepth 1 -type f -iname "*Echo*.wav" 2>/dev/null \
        | grep -viE "No[ _-]?Echo" | head -1)
    echo "$f"
}

verify_demucs_instrumental_stems() {
    local stems_dir="$1"
    for stem in drums bass other; do
        if [ ! -f "$stems_dir/$stem.wav" ]; then
            return 1
        fi
    done
    return 0
}
