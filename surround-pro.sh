#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
LIB_DIR="$SCRIPT_DIR/lib"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"

RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'
YELLOW='\e[33m'
BOLD='\e[1m'
RESET='\e[0m'

print_error()   { echo -e "${RED}[שגיאה]${RESET} $1" >&2; }
print_info()    { echo -e "${CYAN}[מידע]${RESET}  $1"; }
print_success() { echo -e "${GREEN}[הצלחה]${RESET} $1"; }
print_warn()    { echo -e "${YELLOW}[אזהרה]${RESET} $1"; }
print_stage() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  $1${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

source "$LIB_DIR/install-deps.sh"
source "$LIB_DIR/detect-hardware.sh"
source "$LIB_DIR/setup-env.sh"
source "$LIB_DIR/handle-input.sh"
source "$LIB_DIR/separate-stems.sh"
source "$LIB_DIR/build-71.sh"
source "$LIB_DIR/cleanup.sh"

process_source() {
    local source_input="$1"
    local gpu_backend="$2"

    local source_title
    source_title=$(get_source_title "$source_input")
    local safe
    safe=$(safe_title "$source_title")

    print_stage "🎵 מעבד: $source_title"

    local is_video="false"
    if is_video_source "$source_input"; then
        is_video="true"
    fi
    print_info "סוג מקור: $( [ "$is_video" = "true" ] && echo וידאו || echo שמע )"

    local work_dir="${OUTPUT_DIR}/.${safe}_7.1_work_${RANDOM}"
    rm -rf "$work_dir"
    mkdir -p "$work_dir"
    CURRENT_WORK_DIR="$work_dir"

    print_stage "שלב 2/5 ▸ הכנת קובץ מקור"
    fetch_source_to_workdir "$source_input" "$work_dir" "$is_video"
    print_success "מקור מוכן"

    print_stage "שלב 3/5 ▸ הפרדה משולשת (BS-RoFormer → De-Echo → Demucs)"
    local audio_file="$work_dir/original_audio.wav"

    print_info "  (3a) הפרדת ווקאל איכותית עם BS-RoFormer..."
    local sep_vocal_dir="$work_dir/sep_vocal"
    mkdir -p "$sep_vocal_dir"
    extract_vocals_with_separator "$audio_file" "$sep_vocal_dir" "$GPU_BACKEND"

    local vocal_wet
    vocal_wet=$(locate_vocal_wet_file "$sep_vocal_dir")
    local instrumental
    instrumental=$(locate_instrumental_file "$sep_vocal_dir")
    if [ -z "$vocal_wet" ] || [ ! -f "$vocal_wet" ] || [ -z "$instrumental" ] || [ ! -f "$instrumental" ]; then
        print_error "audio-separator לא יצר vocals/instrumental ב-$sep_vocal_dir"
        ls -la "$sep_vocal_dir" >&2 || true
        cleanup_work_dir "$work_dir"
        CURRENT_WORK_DIR=""
        return 1
    fi
    cp "$vocal_wet"    "$work_dir/vocal_wet.wav"
    cp "$instrumental" "$work_dir/instrumental.wav"
    print_success "  vocals + instrumental מופרדים"

    print_info "  (3b) הפרדת dry vocal + echo tail (De-Echo)..."
    local sep_deecho_dir="$work_dir/sep_deecho"
    mkdir -p "$sep_deecho_dir"
    split_vocal_dry_echo "$work_dir/vocal_wet.wav" "$sep_deecho_dir" "$GPU_BACKEND"

    local dry_vocal
    dry_vocal=$(locate_dry_vocal_file "$sep_deecho_dir")
    local echo_tail
    echo_tail=$(locate_echo_tail_file "$sep_deecho_dir")
    if [ -z "$dry_vocal" ] || [ ! -f "$dry_vocal" ] || [ -z "$echo_tail" ] || [ ! -f "$echo_tail" ]; then
        print_error "De-Echo לא יצר dry/echo ב-$sep_deecho_dir"
        ls -la "$sep_deecho_dir" >&2 || true
        cleanup_work_dir "$work_dir"
        CURRENT_WORK_DIR=""
        return 1
    fi
    cp "$dry_vocal"  "$work_dir/dry_vocal.wav"
    cp "$echo_tail"  "$work_dir/echo_tail.wav"
    print_success "  dry vocal + echo מופרדים"

    print_info "  (3c) Demucs htdemucs_ft על instrumental..."
    run_demucs "$work_dir/instrumental.wav" "$work_dir" "$GPU_BACKEND"
    local stems_dir="$work_dir/$(get_demucs_model_name)"
    if ! verify_demucs_instrumental_stems "$stems_dir"; then
        print_error "חסר אחד או יותר מ-Demucs (drums/bass/other) ב-$stems_dir"
        cleanup_work_dir "$work_dir"
        CURRENT_WORK_DIR=""
        return 1
    fi
    print_success "  drums + bass + other מופרדים"
    print_success "הפרדה משולשת הושלמה"

    print_stage "שלב 4/5 ▸ מיפוי 7.1 + 5.1 + 2.1 + Stereo + Mono לתוך MKV"
    local final_base="${OUTPUT_DIR}/${safe}_surround"
    local final_output
    final_output=$(get_unique_filename "$final_base" ".mkv")

    local video_file=""
    local metadata_source=""
    if [ "$is_video" = "true" ]; then
        video_file="$work_dir/video.mp4"
        if is_url "$source_input"; then
            metadata_source="$work_dir/video.mp4"
        else
            metadata_source="$source_input"
        fi
    elif ! is_url "$source_input"; then
        metadata_source="$source_input"
    fi

    build_multi_format_output \
        "$stems_dir/drums.wav" \
        "$work_dir/dry_vocal.wav" \
        "$stems_dir/bass.wav" \
        "$stems_dir/guitar.wav" \
        "$stems_dir/piano.wav" \
        "$stems_dir/other.wav" \
        "$work_dir/echo_tail.wav" \
        "$video_file" \
        "$metadata_source" \
        "$final_output"
    print_success "קובץ MKV עם 5 פורמטים נוצר"

    print_stage "שלב 5/5 ▸ ניקוי"
    cleanup_work_dir "$work_dir"
    CURRENT_WORK_DIR=""
    print_success "קובץ סופי: $final_output"
}

process_directory() {
    local dir_path="$1"
    local gpu_backend="$2"
    local abs_dir
    abs_dir=$(readlink -f "$dir_path")
    local file_count
    file_count=$(find "$abs_dir" -maxdepth 1 -type f | wc -l)
    if [ "$file_count" -eq 0 ]; then
        print_error "תיקייה ריקה: $abs_dir"
        exit 1
    fi
    local i=0
    while IFS= read -r -d $'\0' file; do
        i=$((i + 1))
        print_info "━━ קובץ $i/$file_count: $(basename "$file")"
        process_source "$file" "$GPU_BACKEND" || print_warn "נכשל בעיבוד: $(basename "$file") — ממשיך"
    done < <(find "$abs_dir" -maxdepth 1 -type f -print0)
    print_success "✅ עובדו $file_count קבצים"
}

prompt_for_input() {
    local user_input=""
    read -rp "הזן URL, נתיב קובץ, או נתיב תיקיה: " user_input || true
    echo "$user_input"
}

GPU_BACKEND=""
BROWSER_FOR_COOKIES=""
CURRENT_WORK_DIR=""

trap_cleanup_on_exit() {
    if [ -n "${CURRENT_WORK_DIR:-}" ] && [ -d "${CURRENT_WORK_DIR:-}" ]; then
        rm -rf "$CURRENT_WORK_DIR"
        CURRENT_WORK_DIR=""
    fi
}
trap trap_cleanup_on_exit EXIT INT TERM

cleanup_orphaned_work_dirs() {
    if [ ! -d "$OUTPUT_DIR" ]; then return; fi
    local count=0
    while IFS= read -r -d '' orphan; do
        rm -rf "$orphan" && count=$((count + 1))
    done < <(find "$OUTPUT_DIR" -maxdepth 1 -type d -name '.*_7.1_work_*' -mmin +60 -print0 2>/dev/null)
    if [ "$count" -gt 0 ]; then
        print_info "נוקו $count תיקיות עבודה ישנות מ-output/"
    fi
}

show_help() {
    cat << 'HELPEOF'
surround-pro v1.0 — Stereo → 7.1 Surround AI Pipeline

USAGE:
    ./surround-pro.sh [INPUT]

INPUT TYPES:
    URL              YouTube etc.             ./surround-pro.sh "https://www.youtube.com/watch?v=..."
    file path        Local media file         ./surround-pro.sh /path/to/song.mp3
    folder path      Batch (all files in dir) ./surround-pro.sh /path/to/folder/
    search query     Auto-search YouTube      ./surround-pro.sh "Hadag Nahash The Ringing Slap"
    (no arg)         Interactive mode         ./surround-pro.sh

OUTPUT (v1.0):
    Single MKV with 5 audio tracks, switchable in any player (mpv/VLC/ffmpeg):
      Track 1: 7.1 Surround (default)
      Track 2: 5.1 Surround
      Track 3: 2.1 (Stereo + LFE)
      Track 4: Stereo
      Track 5: Mono
    For video sources, original video is preserved on track 0.

ENVIRONMENT VARIABLES:
    BROWSER_FOR_COOKIES        Override auto-detected browser (chrome|chromium|brave|firefox|vivaldi|opera)
    AUDIO_SEPARATOR_MODEL_DIR  Where audio-separator caches models (default: ~/.cache/audio-separator-models/)

OUTPUT:
    Audio source → output/<title>_7.1.flac
    Video source → output/<title>_7.1.mkv  (original video + new 7.1 audio track)

FIRST-RUN NOTE:
    First run downloads ~3GB (torch + audio-separator + AI models).
    All cached for subsequent runs.

PROJECT:
    https://github.com/Guy008/surround-pro
HELPEOF
}

run_stage_1_scan_and_prepare() {
    print_stage "שלב 1/5 ▸ סריקת חומרה והכנת סביבה"

    cleanup_orphaned_work_dirs

    local os_id pkg_mgr
    os_id=$(detect_os_id)
    pkg_mgr=$(detect_pkg_manager)
    print_info "OS: $os_id | package manager: $pkg_mgr"
    if [ "$pkg_mgr" != "pacman" ]; then
        print_warn "התקנה אוטומטית נתמכת רק על Arch Linux. התלויות חייבות להיות מותקנות ידנית:"
        print_warn "  uv, yt-dlp, ffmpeg/ffprobe, ודפדפן (chrome/chromium/firefox/brave/...)"
        print_warn "  ל-AMD GPU גם: rocm-hip-runtime + patchelf + binutils"
    fi

    print_info "בודק תלויות ליבה (yt-dlp, ffmpeg, uv)..."
    if ! ensure_core_tools; then
        print_error "חסרות תלויות ליבה שלא ניתן להתקין אוטומטית. עצירה."
        exit 1
    fi
    print_success "כל תלויות הליבה מוכנות"

    local browser
    browser=$(detect_installed_browser)
    if [ -z "$browser" ]; then
        print_warn "לא זוהה דפדפן נתמך — yt-dlp יעבוד בלי cookies (עלול להיכשל ב-YouTube)"
        BROWSER_FOR_COOKIES=""
    else
        print_success "דפדפן ל-cookies: $browser"
        BROWSER_FOR_COOKIES="$browser"
    fi
    export BROWSER_FOR_COOKIES

    local backend
    backend=$(detect_gpu_backend)
    local gpu_name
    gpu_name=$(detect_gpu_name "$backend")
    print_info "GPU backend מזוהה: $backend → $gpu_name"

    if [ "$backend" = "amd" ]; then
        if ! ensure_rocm_runtime_for_amd "amd"; then
            print_warn "נופלים ל-CPU mode כי ROCm לא מותקן/לא ניתן להתקנה"
            backend="cpu"
        fi
    fi

    print_info "מוודא ש-Demucs המודל זמין (יוריד torch + מודל בריצה ראשונה — עשוי לקחת דקות)..."
    if ! prefetch_demucs_model "$backend"; then
        if [ "$backend" != "cpu" ]; then
            print_warn "טעינת torch עם backend '$backend' נכשלה — נופלים ל-CPU mode"
            backend="cpu"
            print_info "מוריד torch CPU (זה הורדה חדשה כי ה-wheel שונה)..."
            if ! prefetch_demucs_model "$backend"; then
                print_error "כשל גם ב-CPU mode — אין דרך להמשיך"
                exit 1
            fi
        else
            print_error "כשל בהכנת סביבת Demucs (CPU)"
            exit 1
        fi
    fi

    GPU_BACKEND="$backend"
    print_success "סביבה מוכנה — backend סופי: $GPU_BACKEND"

    ensure_output_dir "$OUTPUT_DIR"
}

main() {
    if [ $# -gt 0 ] && { [ "$1" = "--help" ] || [ "$1" = "-h" ]; }; then
        show_help
        exit 0
    fi

    print_stage "🎬 surround-pro v1.0 — Stereo → 7.1 Surround"

    run_stage_1_scan_and_prepare

    local user_input
    if [ $# -gt 0 ]; then
        user_input="$1"
    else
        user_input=$(prompt_for_input)
    fi

    if [ -z "${user_input:-}" ]; then
        print_error "לא הוזן קלט"
        exit 1
    fi

    if [ -d "$user_input" ]; then
        process_directory "$user_input" "$GPU_BACKEND"
    elif is_url "$user_input"; then
        process_source "$user_input" "$GPU_BACKEND"
        print_success "✅ הסתיים"
    elif [ -f "$user_input" ]; then
        process_source "$(readlink -f "$user_input")" "$GPU_BACKEND"
        print_success "✅ הסתיים"
    else
        print_info "לא URL/קובץ/תיקייה — מחפש ביוטיוב: $user_input"
        local search_url
        search_url=$(search_youtube_first "$user_input")
        if [ -z "$search_url" ]; then
            print_error "לא נמצאה התאמה ב-YouTube ל-: $user_input"
            exit 1
        fi
        print_success "נמצא: $search_url"
        process_source "$search_url" "$GPU_BACKEND"
        print_success "✅ הסתיים"
    fi
}

main "$@"
