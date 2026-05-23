#!/usr/bin/env bash
# Baixa os modelos do pipeline Qwen-Image-Edit-2511 + LoRAs pras pastas do ComfyUI.
# Modelos grandes (UNET/CLIP/VAE/Lightning) via huggingface-cli + hf_transfer (rapido,
# ~50MB/s constante) pra caber no limite de 30min do build do RunPod. wget sem token
# estrangulava no HF e estourava o tempo. LoRAs custom vem de GitHub Release (ja rapido).
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-/comfyui}"
TMP="/tmp/hfdl"

# Baixa um arquivo do HuggingFace (repo, caminho-no-repo, destino) com hf_transfer.
# Usa --local-dir (arquivo real, sem duplicar no cache) e move pro destino (mesmo fs = rename).
hf_dl () {
  echo ">>> [HF] baixando $(basename "$3")"
  huggingface-cli download "$1" "$2" --local-dir "$TMP"
  mkdir -p "$(dirname "$3")"
  mv -f "$TMP/$2" "$3"
}

# Baixa um asset publico (url, destino) - GitHub Release, rapido.
dl () {
  mkdir -p "$(dirname "$2")"
  echo ">>> baixando $(basename "$2")"
  wget -q -O "$2" "$1"
}

hf_dl "Comfy-Org/Qwen-Image-Edit_ComfyUI" "split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors" "$COMFY_DIR/models/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"
hf_dl "Comfy-Org/Qwen-Image_ComfyUI"      "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"        "$COMFY_DIR/models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
hf_dl "Comfy-Org/Qwen-Image_ComfyUI"      "split_files/vae/qwen_image_vae.safetensors"                            "$COMFY_DIR/models/vae/qwen_image_vae.safetensors"
hf_dl "lightx2v/Qwen-Image-Edit-2511-Lightning" "Qwen-Image-Edit-2511-Lightning-8steps-V1.0-bf16.safetensors"     "$COMFY_DIR/models/loras/Qwen-Image-Edit-2511-Lightning-8steps-V1.0-bf16.safetensors"

GH="https://github.com/tamoaiapp/comfyui-serverless/releases/download/models-v1"
dl "$GH/tamowork_qwen_edit_2511_lora_v1.safetensors"          "$COMFY_DIR/models/loras/tamowork_qwen_edit_2511_lora_v1.safetensors"
dl "$GH/tamowork_acc_qwen_edit_2511_lora_v1.safetensors"      "$COMFY_DIR/models/loras/tamowork_acc_qwen_edit_2511_lora_v1.safetensors"
dl "$GH/tamowork_calcados_qwen_edit_2511_lora_v1.safetensors" "$COMFY_DIR/models/loras/tamowork_calcados_qwen_edit_2511_lora_v1.safetensors"

rm -rf "$TMP"
echo "OK - modelos prontos em $COMFY_DIR/models"
