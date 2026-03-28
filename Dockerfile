# Usa a mesma imagem dos pods — Python e custom nodes idênticos
FROM runpod/comfyui:latest

# Instala o SDK serverless do RunPod
RUN pip install --no-cache-dir "runpod>=1.7.0"

# Copia o handler
COPY handler.py /handler.py

# COMFY_HOME aponta para o volume de rede em /workspace
ENV COMFY_HOME=/workspace/runpod-slim/ComfyUI

# ENTRYPOINT (não CMD) garante que o handler roda direto,
# ignorando o /start.sh da imagem base
ENTRYPOINT ["python3", "/handler.py"]
