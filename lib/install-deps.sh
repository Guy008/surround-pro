#!/bin/bash

detect_os_id() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

detect_pkg_manager() {
    if command -v pacman >/dev/null 2>&1; then echo "pacman"; return; fi
    if command -v apt-get >/dev/null 2>&1; then echo "apt"; return; fi
    if command -v dnf >/dev/null 2>&1; then echo "dnf"; return; fi
    if command -v zypper >/dev/null 2>&1; then echo "zypper"; return; fi
    echo "none"
}

is_pacman_available() {
    command -v pacman >/dev/null 2>&1
}

is_pkg_installed() {
    local pkg="$1"
    local mgr
    mgr=$(detect_pkg_manager)
    case "$mgr" in
        pacman) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
        apt)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        dnf)    rpm -q "$pkg" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

run_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_pkg_install() {
    local pkg="$1"
    local mgr
    mgr=$(detect_pkg_manager)

    case "$mgr" in
        pacman) run_sudo pacman -S --needed --noconfirm "$pkg" ;;
        apt)
            run_sudo apt-get update -y >/dev/null 2>&1 || true
            run_sudo apt-get install -y --no-install-recommends "$pkg"
            ;;
        dnf)    run_sudo dnf install -y "$pkg" ;;
        zypper) run_sudo zypper --non-interactive install "$pkg" ;;
        *) return 1 ;;
    esac
}

install_via_pip() {
    local pip_pkg="$1"
    local pip_cmd
    if command -v pip3 >/dev/null 2>&1; then
        pip_cmd="pip3"
    elif command -v pip >/dev/null 2>&1; then
        pip_cmd="pip"
    else
        return 1
    fi

    if [ "$(id -u)" -eq 0 ]; then
        $pip_cmd install --break-system-packages --no-cache-dir --upgrade "$pip_pkg"
    else
        $pip_cmd install --user --no-cache-dir --upgrade "$pip_pkg"
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

resolve_pkg_for_cmd() {
    local cmd="$1"
    local mgr
    mgr=$(detect_pkg_manager)

    case "$cmd" in
        yt-dlp)
            case "$mgr" in
                pacman) echo "PKG:yt-dlp" ;;
                *) echo "PIP:yt-dlp" ;;
            esac
            ;;
        ffmpeg|ffprobe)
            echo "PKG:ffmpeg"
            ;;
        patchelf)
            echo "PKG:patchelf"
            ;;
        readelf)
            echo "PKG:binutils"
            ;;
        *)
            echo "PKG:$cmd"
            ;;
    esac
}

ensure_cmd() {
    local cmd="$1"

    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi

    local mgr
    mgr=$(detect_pkg_manager)
    if [ "$mgr" = "none" ]; then
        print_error "$cmd חסר ואין package manager (pacman/apt/dnf/zypper) — התקן ידנית"
        return 1
    fi

    local resolved
    resolved=$(resolve_pkg_for_cmd "$cmd")
    local resolved_type="${resolved%%:*}"
    local pkg="${resolved#*:}"

    print_info "$cmd לא מותקן — מתקין דרך $mgr ($pkg)..."

    if [ "$resolved_type" = "PIP" ]; then
        if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
            run_pkg_install python3-pip || true
        fi
        if install_via_pip "$pkg"; then
            if command -v "$cmd" >/dev/null 2>&1; then
                print_success "$cmd הותקן (pip)"
                return 0
            fi
        fi
    else
        if run_pkg_install "$pkg"; then
            if command -v "$cmd" >/dev/null 2>&1; then
                print_success "$cmd הותקן ($mgr)"
                return 0
            fi
        fi
    fi
    print_error "כשל בהתקנת $cmd"
    return 1
}

ensure_uv() {
    if command -v uv >/dev/null 2>&1; then
        return 0
    fi

    local mgr
    mgr=$(detect_pkg_manager)

    if [ "$mgr" = "pacman" ]; then
        print_info "uv לא מותקן — מתקין דרך pacman..."
        if run_pkg_install uv; then
            print_success "uv הותקן"
            return 0
        fi
        print_warn "התקנת uv דרך pacman נכשלה — מנסה curl..."
    else
        print_info "uv לא מותקן — מתקין user-local דרך curl..."
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
    ensure_cmd yt-dlp   || failed=$((failed + 1))
    ensure_cmd ffmpeg   || failed=$((failed + 1))
    ensure_cmd ffprobe  || failed=$((failed + 1))
    ensure_uv           || failed=$((failed + 1))
    return "$failed"
}

ensure_rocm_runtime_for_amd() {
    local backend="$1"
    if [ "$backend" != "amd" ]; then
        return 0
    fi

    if ! is_pacman_available; then
        print_warn "AMD GPU זוהה אבל Arch (pacman) לא זמין."
        print_warn "להתקנת ROCm ידנית: https://rocm.docs.amd.com/projects/install-on-linux/"
        print_warn "כרגע נופלים ל-CPU mode."
        return 1
    fi

    local failed=0
    if ! is_pkg_installed rocm-hip-runtime; then
        print_info "מתקין rocm-hip-runtime..."
        if ! run_pkg_install rocm-hip-runtime; then
            print_warn "התקנת rocm-hip-runtime נכשלה"
            failed=1
        fi
    fi

    ensure_cmd patchelf || failed=1
    ensure_cmd readelf || true

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
