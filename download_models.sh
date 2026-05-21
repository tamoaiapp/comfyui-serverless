#!/usr/bin/env bash
# Baixa os modelos do pipeline Qwen-Image-Edit-2511 + LoRAs pras pastas do ComfyUI.
# URLs verificadas (HuggingFace Comfy-Org + lightx2v). LoRA custom vem do Supabase.
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-/comfyui}"
HF="https://huggingface.co"

URL_UNET="$HF/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"
URL_CLIP="$HF/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
URL_VAE="$HF/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"
URL_LIGHTNING="$HF/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-8steps-V1.0-bf16.safetensors"

# LoRA treinada (hospedada como GitHub Release asset deste prÃ³prio repo â€” pÃºblico)
URL_CUSTOM_LORA="https://github.com/tamoaiapp/comfyui-serverless/releases/download/models-v1/tamowork_qwen_edit_2511_lora_v1.safetensors"
URL_ACC_LORA="https://github.com/tamoaiapp/comfyui-serverless/releases/download/models-v1/tamowork_acc_qwen_edit_2511_lora_v1.safetensors"

dl () {
  mkdir -p "$(dirname "$2")"
  echo ">>> baixando $(basename "$2")"
  wget -q -O "$2" "$1"
}

dl "$URL_UNET"        "$COMFY_DIR/models/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"
dl "$URL_CLIP"        "$COMFY_DIR/models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
dl "$URL_VAE"         "$COMFY_DIR/models/vae/qwen_image_vae.safetensors"
dl "$URL_LIGHTNING"   "$COMFY_DIR/models/loras/Qwen-Image-Edit-2511-Lightning-8steps-V1.0-bf16.safetensors"
dl "$URL_CUSTOM_LORA" "$COMFY_DIR/models/loras/tamowork_qwen_edit_2511_lora_v1.safetensors"
dl "$URL_ACC_LORA" "$COMFY_DIR/models/loras/tamowork_acc_qwen_edit_2511_lora_v1.safetensors"

echo "OK â€” modelos prontos em $COMFY_DIR/models"
