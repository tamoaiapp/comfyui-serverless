# =============================================================================
# Worker ComfyUI — RunPod Serverless — pipeline FotoCardápio (Qwen-Image-Edit 2511)
# Base: worker-comfyui oficial (handler + ComfyUI já embutidos e mantidos).
# Modelos BAKED na imagem (não network volume) → roda em qualquer datacenter,
# máximo de GPUs no pool. Imagem ~30 GB; RunPod faz cache nos workers.
# =============================================================================
FROM runpod/worker-comfyui:5.8.5-base
# Se a build/run acusar nó faltando (TextEncodeQwenImageEditPlus), suba a tag acima.

# Acelera o download dos modelos grandes do HF. O build do RunPod tem limite de 30min
# e o HF estrangula download sem token (~KB/s), o que estourava o tempo. hf_transfer
# da ~50MB/s constante e mantem o build bem dentro do limite.
ENV HF_HUB_ENABLE_HF_TRANSFER=1
RUN python3 -m pip install --no-cache-dir -q "huggingface_hub[hf_transfer]"

# Baixa os modelos Qwen-Image-Edit-2511 + LoRAs pra dentro da imagem (/comfyui/models)
COPY download_models.sh /tmp/download_models.sh
RUN chmod +x /tmp/download_models.sh && /tmp/download_models.sh

# Sanidade no log do build
RUN echo "=== loras ===" && ls -lh /comfyui/models/loras/ 2>/dev/null; \
    echo "=== diffusion_models ===" && ls -lh /comfyui/models/diffusion_models/ 2>/dev/null; \
    echo "=== text_encoders ===" && ls -lh /comfyui/models/text_encoders/ 2>/dev/null; \
    echo "=== vae ===" && ls -lh /comfyui/models/vae/ 2>/dev/null
