#!/bin/bash

try_gpu_compute() {
    local backend="$1"
    local index
    index=$(get_torch_index_url "$backend")
    local args="--python 3.11 --with torch"
    if [ -n "$index" ]; then
        args="$args --extra-index-url $index"
    fi

    uv run $args python -c "
import torch, sys
if not torch.cuda.is_available():
    sys.exit(2)
try:
    x = torch.zeros(16, device='cuda') + 1
    y = x.cpu()
    assert y[0].item() == 1.0
except Exception as e:
    print(f'GPU compute failed: {type(e).__name__}: {e}', file=sys.stderr)
    sys.exit(3)
print('GPU_OK:', torch.cuda.get_device_name(0))
" 2>/dev/null
}

prefetch_demucs_model() {
    local backend="$1"
    local model_name="${DEMUCS_MODEL_NAME:-htdemucs_ft}"

    if [ "$backend" = "amd" ] || [ "$backend" = "nvidia" ]; then
        print_info "  בדיקת GPU compute אמיתית..."
        if ! try_gpu_compute "$backend"; then
            if [ "$backend" = "amd" ]; then
                print_warn "  GPU compute נכשל — מנסה patchelf..."
                if patch_execstack_in_uv_cache; then
                    if try_gpu_compute "$backend"; then
                        print_success "  GPU compute עובד אחרי patchelf"
                    fi
                fi
                if ! try_gpu_compute "$backend"; then
                    print_warn "  GPU compute עדיין נכשל — מנסה HSA_OVERRIDE_GFX_VERSION=10.3.0..."
                    export HSA_OVERRIDE_GFX_VERSION=10.3.0
                    if try_gpu_compute "$backend"; then
                        print_success "  GPU compute עובד עם HSA_OVERRIDE_GFX_VERSION=10.3.0"
                    else
                        unset HSA_OVERRIDE_GFX_VERSION
                        print_warn "  גם override לא עזר — נופלים ל-CPU"
                        return 1
                    fi
                fi
            else
                print_warn "  GPU compute test failed for $backend — נופלים ל-CPU"
                return 1
            fi
        else
            print_success "  GPU compute עובד native"
        fi
    fi

    local uv_args
    uv_args=$(build_uv_args "$backend")
    uv run $uv_args python -c "from demucs.pretrained import get_model; get_model('$model_name'); print('OK')"
}

ensure_output_dir() {
    local output_dir="$1"
    mkdir -p "$output_dir"
}
