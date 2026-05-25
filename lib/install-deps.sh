#!/bin/bash

is_pacman_available() {
    command -v pacman >/dev/null 2>&1
}

is_pacman_pkg_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

run_pacman_install() {
    local pkg="$1"
    if [ "$(id -u)" -eq 0 ]; then
        pacman -S --needed --noconfirm "$pkg"
    else
        sudo pacman -S --needed --noconfirm "$pkg"
    fi
}

ensure_pacman_cmd() {
    local cmd="$1"
    local pkg="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi

    if ! is_pacman_available; then
        print_error "$cmd חסר וגם pacman לא זמין — אין דרך אוטומטית להתקין"
        return 1
    fi

    print_info "$cmd לא מותקן — מתקין $pkg..."
    if run_pacman_install "$pkg"; then
        print_success "$pkg הותקן"
        return 0
    else
        print_error "כשל בהתקנת $pkg"
        return 1
    fi
}

ensure_uv() {
    if command -v uv >/dev/null 2>&1; then
        return 0
    fi

    if is_pacman_available; then
        print_info "uv לא מותקן — מתקין דרך pacman..."
        if run_pacman_install uv; then
            print_success "uv הותקן"
            return 0
        fi
        print_warn "התקנת uv דרך pacman נכשלה — מנסה user-local דרך curl..."
    else
        print_info "אין pacman — מתקין uv דרך curl (user-local)..."
    fi

    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
        if command -v uv >/dev/null 2>&1; then
            print_success "uv הותקן user-local"
            return 0
        fi
    fi

    print_error "כשל בהתקנת uv"
    return 1
}

ensure_core_tools() {
    local failed=0

    ensure_pacman_cmd yt-dlp yt-dlp   || failed=$((failed + 1))
    ensure_pacman_cmd ffmpeg ffmpeg   || failed=$((failed + 1))
    ensure_pacman_cmd ffprobe ffmpeg  || failed=$((failed + 1))
    ensure_uv                         || failed=$((failed + 1))

    return "$failed"
}

ensure_rocm_runtime_for_amd() {
    local backend="$1"
    if [ "$backend" != "amd" ]; then
        return 0
    fi

    if ! is_pacman_available; then
        print_warn "AMD GPU זוהה אבל אין pacman — לא ניתן להתקין ROCm אוטומטית"
        return 1
    fi

    local failed=0
    if ! is_pacman_pkg_installed rocm-hip-runtime; then
        print_info "מתקין rocm-hip-runtime..."
        if ! run_pacman_install rocm-hip-runtime; then
            print_warn "התקנת rocm-hip-runtime נכשלה"
            failed=1
        fi
    fi

    ensure_pacman_cmd patchelf patchelf || failed=1
    ensure_pacman_cmd readelf binutils || true

    if [ "$failed" -eq 0 ]; then
        print_success "ROCm runtime + patchelf מוכנים"
        return 0
    fi
    return 1
}

patch_execstack_in_uv_cache() {
    if ! command -v patchelf >/dev/null 2>&1; then
        return 1
    fi
    if ! command -v readelf >/dev/null 2>&1; then
        return 1
    fi

    local patched=0
    local lib
    while IFS= read -r lib; do
        if readelf -lW "$lib" 2>/dev/null | grep -q "GNU_STACK.*RWE"; then
            if patchelf --clear-execstack "$lib" 2>/dev/null; then
                patched=$((patched + 1))
            fi
        fi
    done < <(find "$HOME/.cache/uv/" \
        \( -name "libamdhip64.so*" -o -name "libhiprtc.so*" -o -name "libroctracer*.so*" -o -name "librocfft*.so*" \) \
        -type f 2>/dev/null)

    print_info "patchelf: $patched ספריות AMD ROCm תוקנו (execstack flag)"
    [ "$patched" -gt 0 ]
}
