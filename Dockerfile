# Usa a mesma imagem dos pods existentes — Python e custom nodes idênticos
FROM runpod/comfyui:latest

# Instala o SDK serverless do RunPod
RUN pip install --no-cache-dir runpod>=1.7.0

# Copia o handler
COPY handler.py /handler.py

# COMFY_HOME aponta para o volume de rede montado em /workspace
ENV COMFY_HOME=/workspace/runpod-slim/ComfyUI

# O handler inicia o ComfyUI e registra o worker serverless
CMD ["python3", "/handler.py"]
