#!/bin/bash

ytdlp() {
    if [ -n "${BROWSER_FOR_COOKIES:-}" ]; then
        yt-dlp --cookies-from-browser "$BROWSER_FOR_COOKIES" "$@"
    else
        yt-dlp "$@"
    fi
}

is_url() {
    [[ "$1" == http* ]]
}

get_source_title() {
    local input="$1"
    if is_url "$input"; then
        ytdlp --get-title "$input" 2>/dev/null || echo "output"
    else
        basename "$input" | sed 's/\.[^.]*$//'
    fi
}

is_video_source() {
    local input="$1"
    if is_url "$input"; then
        ytdlp --list-formats "$input" 2>/dev/null | grep -q 'video only'
    else
        ffprobe -v error -select_streams v:0 -count_packets \
            -show_entries stream=nb_read_packets -of csv=p=0 "$input" 2>/dev/null \
            | grep -q '[1-9]'
    fi
}

safe_title() {
    local title="$1"
    local safe
    safe=$(echo "$title" | sed 's|[/\\?%*:|"<>]|_|g' | xargs)
    if [ -z "$safe" ]; then
        safe="output_processed"
    fi
    echo "$safe"
}

download_url_video() {
    local url="$1"
    local video_file="$2"
    ytdlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" \
        --output "$video_file" "$url"
}

download_url_audio() {
    local url="$1"
    local audio_file="$2"
    ytdlp -f bestaudio --extract-audio --audio-format wav \
        --output "$audio_file" "$url"
}

extract_audio_from_media() {
    local media_file="$1"
    local audio_file="$2"
    ffmpeg -hide_banner -loglevel error -y \
        -i "$media_file" -vn -acodec pcm_s16le -ar 48000 -ac 2 "$audio_file"
}

strip_audio_from_video() {
    local media_file="$1"
    local video_file="$2"
    ffmpeg -hide_banner -loglevel error -y \
        -i "$media_file" -vcodec copy -an "$video_file"
}

fetch_source_to_workdir() {
    local source_input="$1"
    local work_dir="$2"
    local is_video="$3"
    local video_file="$work_dir/video.mp4"
    local audio_file="$work_dir/original_audio.wav"
    local original_media="$work_dir/original_media"

    if is_url "$source_input"; then
        if [ "$is_video" = "true" ]; then
            download_url_video "$source_input" "$video_file"
            extract_audio_from_media "$video_file" "$audio_file"
        else
            download_url_audio "$source_input" "$audio_file"
        fi
    else
        cp "$source_input" "$original_media"
        if [ "$is_video" = "true" ]; then
            strip_audio_from_video "$original_media" "$video_file"
            extract_audio_from_media "$original_media" "$audio_file"
        else
            extract_audio_from_media "$original_media" "$audio_file"
        fi
    fi
}
