# =============================================================================
# Worker ComfyUI — RunPod Serverless — pipeline FotoCardápio (Qwen-Image-Edit 2511)
# Base: worker-comfyui oficial (handler + ComfyUI já embutidos e mantidos).
# Modelos BAKED na imagem (não network volume) → roda em qualquer datacenter,
# máximo de GPUs no pool. Imagem ~30 GB; RunPod faz cache nos workers.
# =============================================================================
FROM runpod/worker-comfyui:5.8.5-base AS runtime_base

# Freeze core compatibility to the day of the last successful production build.
ARG COMFYUI_REF=0b04660ba329ce643f29cabf4905aa9b5a71c6f8
# Se a build/run acusar nó faltando (TextEncodeQwenImageEditPlus), suba a tag acima.

# The base predates Flux2 nodes; use the compatible production core above.
# O comfy-cli faz "git clone" em /comfyui — confirmado no Dockerfile upstream.
RUN cd /comfyui && git fetch --depth=1 origin "$COMFYUI_REF" && git reset --hard FETCH_HEAD && \
    pip install --no-cache-dir -r requirements.txt --quiet

# Acelera o download dos modelos grandes do HF. O build do RunPod tem limite de 30min
# e o HF estrangula download sem token (~KB/s), o que estourava o tempo. hf_transfer
# da ~50MB/s constante e mantem o build bem dentro do limite.
ENV HF_HUB_ENABLE_HF_TRANSFER=1
RUN python3 -m pip install --no-cache-dir -q "huggingface_hub[hf_transfer]"

# Download independent models concurrently, with isolated temporary caches.
COPY download_models.sh /tmp/download_models.sh
RUN chmod +x /tmp/download_models.sh

FROM runtime_base
# Keep download staging out of exported build layers. Exporting a second complete
# copy of all weights as an intermediate-stage cache exceeded RunPod's 30m limit.
RUN --mount=type=cache,id=tamowork-models-v1,target=/model-cache,sharing=locked \
    set -eu; \
    pids=""; \
    for model_group in qwen_unet qwen_clip qwen_vae lightning flux_unet flux_clip flux_vae custom_loras; do \
      COMFY_DIR=/model-cache /tmp/download_models.sh "$model_group" & pids="$pids $!"; \
    done; \
    result=0; \
    for model_pid in $pids; do wait "$model_pid" || result=1; done; \
    test "$result" -eq 0; \
    mkdir -p /comfyui/models/diffusion_models; \
    cp /model-cache/models/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors /comfyui/models/diffusion_models/

# Each RUN creates a separate model layer, keeping pulls independently retryable.
RUN --mount=type=cache,id=tamowork-models-v1,target=/model-cache,sharing=locked \
    mkdir -p /comfyui/models/text_encoders && cp /model-cache/models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors /comfyui/models/text_encoders/
RUN --mount=type=cache,id=tamowork-models-v1,target=/model-cache,sharing=locked \
    mkdir -p /comfyui/models/vae && cp /model-cache/models/vae/qwen_image_vae.safetensors /comfyui/models/vae/
RUN --mount=type=cache,id=tamowork-models-v1,target=/model-cache,sharing=locked \
    mkdir -p /comfyui/models/loras && cp /model-cache/models/loras/Qwen-Image-Edit-2511-Lightning-8steps-V1.0-bf16.safetensors /comfyui/models/loras/
RUN --mount=type=cache,id=tamowork-models-v1,target=/model-cache,sharing=locked \
    cp /model-cache/models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors /comfyui/models/diffusion_models/
RUN --mount=type=cache,id=tamowork-models-v1,target=/model-cache,sharing=locked \
    cp /model-cache/models/text_encoders/qwen_3_8b_fp8mixed.safetensors /comfyui/models/text_encoders/
RUN --mount=type=cache,id=tamowork-models-v1,target=/model-cache,sharing=locked \
    cp /model-cache/models/vae/flux2-vae.safetensors /comfyui/models/vae/
RUN --mount=type=cache,id=tamowork-models-v1,target=/model-cache,sharing=locked \
    cp /model-cache/models/loras/tamowork_*.safetensors /comfyui/models/loras/

# Sanidade no log do build
RUN echo "=== loras ===" && ls -lh /comfyui/models/loras/ 2>/dev/null; \
    echo "=== diffusion_models ===" && ls -lh /comfyui/models/diffusion_models/ 2>/dev/null; \
    echo "=== text_encoders ===" && ls -lh /comfyui/models/text_encoders/ 2>/dev/null; \
    echo "=== vae ===" && ls -lh /comfyui/models/vae/ 2>/dev/null
