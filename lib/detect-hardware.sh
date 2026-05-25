#!/bin/bash

detect_gpu_backend() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        if nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | grep -q .; then
            echo "nvidia"
            return
        fi
    fi

    if command -v rocm-smi >/dev/null 2>&1; then
        if rocm-smi --showproductname 2>/dev/null | grep -qi "card series"; then
            echo "amd"
            return
        fi
    fi

    if [ -e /dev/kfd ]; then
        echo "amd"
        return
    fi

    if command -v clinfo >/dev/null 2>&1; then
        if clinfo 2>/dev/null | grep -qi "Device Name.*Intel"; then
            echo "intel"
            return
        fi
    fi

    echo "cpu"
}

detect_gpu_name() {
    local backend="$1"
    case "$backend" in
        nvidia)
            nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1
            ;;
        amd)
            if command -v rocm-smi >/dev/null 2>&1; then
                rocm-smi --showproductname 2>/dev/null \
                    | grep -i "card series" \
                    | head -1 \
                    | awk -F': ' '{print $2}' \
                    | sed 's/^ *//;s/ *$//'
            else
                echo "AMD GPU (kfd device detected)"
            fi
            ;;
        intel)
            clinfo 2>/dev/null \
                | grep "Device Name" \
                | grep -i intel \
                | head -1 \
                | awk -F': ' '{print $2}' \
                | sed 's/^ *//;s/ *$//'
            ;;
        cpu)
            echo "CPU only"
            ;;
    esac
}

detect_ffmpeg_video_encoder() {
    local backend="$1"
    local encoders
    encoders=$(ffmpeg -hide_banner -encoders 2>/dev/null || true)

    case "$backend" in
        nvidia)
            echo "$encoders" | grep -q hevc_nvenc && { echo "hevc_nvenc"; return; }
            echo "$encoders" | grep -q h264_nvenc && { echo "h264_nvenc"; return; }
            ;;
        amd)
            echo "$encoders" | grep -q hevc_amf && { echo "hevc_amf"; return; }
            echo "$encoders" | grep -q h264_amf && { echo "h264_amf"; return; }
            ;;
        intel)
            echo "$encoders" | grep -q hevc_qsv && { echo "hevc_qsv"; return; }
            echo "$encoders" | grep -q h264_qsv && { echo "h264_qsv"; return; }
            ;;
    esac
    echo ""
}

get_torch_index_url() {
    local backend="$1"
    case "$backend" in
        nvidia) echo "https://download.pytorch.org/whl/cu121" ;;
        amd)    echo "https://download.pytorch.org/whl/rocm6.0" ;;
        *)      echo "" ;;
    esac
}

get_demucs_device() {
    local backend="$1"
    case "$backend" in
        nvidia|amd) echo "cuda" ;;
        intel)      echo "xpu" ;;
        *)          echo "cpu" ;;
    esac
}

build_uv_args() {
    local backend="$1"
    local args="--python 3.11 --with demucs --with torchcodec --with soundfile"
    if [ "$backend" = "intel" ]; then
        args="$args --with intel-extension-for-pytorch"
    fi
    local index
    index=$(get_torch_index_url "$backend")
    if [ -n "$index" ]; then
        args="$args --extra-index-url $index"
    fi
    echo "$args"
}

detect_installed_browser() {
    if command -v google-chrome >/dev/null 2>&1 \
       || command -v google-chrome-stable >/dev/null 2>&1; then
        echo "chrome"; return
    fi
    if command -v chromium >/dev/null 2>&1 \
       || command -v chromium-browser >/dev/null 2>&1; then
        echo "chromium"; return
    fi
    if command -v brave >/dev/null 2>&1 \
       || command -v brave-browser >/dev/null 2>&1; then
        echo "brave"; return
    fi
    if command -v firefox >/dev/null 2>&1; then
        echo "firefox"; return
    fi
    if command -v vivaldi >/dev/null 2>&1 \
       || command -v vivaldi-stable >/dev/null 2>&1; then
        echo "vivaldi"; return
    fi
    if command -v opera >/dev/null 2>&1; then
        echo "opera"; return
    fi
    echo ""
}
