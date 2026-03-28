"""
RunPod Serverless Handler para TamoWork ComfyUI.

Aceita:
  input.workflow  — JSON do workflow ComfyUI
  input.images    — lista de { name, image (base64) }

Retorna:
  { message: ["base64_output"], status: "success" }
"""

import runpod
import os
import time
import json
import base64
import urllib.request
import urllib.error

COMFY_HOST = "http://127.0.0.1:8188"
COMFY_HOME = os.environ.get("COMFY_HOME", "/workspace/runpod-slim/ComfyUI")
OUTPUT_DIR = os.path.join(COMFY_HOME, "output")


def wait_for_comfy(timeout=300):
    """Aguarda o ComfyUI inicializar."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(f"{COMFY_HOST}/system_stats", timeout=3)
            return True
        except Exception:
            time.sleep(2)
    raise RuntimeError(f"ComfyUI não respondeu em {timeout}s")


def upload_images(images: list):
    """Faz upload de cada imagem para o ComfyUI /upload/image."""
    import urllib.parse
    import io

    for img in images:
        name = img["name"]
        data = base64.b64decode(img["image"])

        boundary = "----FormBoundary"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="image"; filename="{name}"\r\n'
            f"Content-Type: image/jpeg\r\n\r\n"
        ).encode() + data + (
            f"\r\n--{boundary}\r\n"
            f'Content-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n'
            f"--{boundary}--\r\n"
        ).encode()

        req = urllib.request.Request(
            f"{COMFY_HOST}/upload/image",
            data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
            method="POST",
        )
        urllib.request.urlopen(req)


def queue_workflow(workflow: dict) -> str:
    """Envia o workflow ao ComfyUI e retorna o prompt_id."""
    payload = json.dumps({"prompt": workflow}).encode()
    req = urllib.request.Request(
        f"{COMFY_HOST}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as res:
        return json.loads(res.read())["prompt_id"]


def wait_for_output(prompt_id: str, timeout=600) -> list:
    """Aguarda o job terminar e retorna lista de base64 dos arquivos gerados."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(f"{COMFY_HOST}/history/{prompt_id}") as res:
                history = json.loads(res.read())
            if prompt_id not in history:
                time.sleep(3)
                continue

            entry = history[prompt_id]
            status = entry.get("status", {})

            # Falha explícita
            if status.get("status_str") == "error":
                raise RuntimeError(f"ComfyUI falhou: {status}")

            # Coletar todos os arquivos de saída
            outputs = []
            for node_output in entry.get("outputs", {}).values():
                for key in ("images", "gifs", "videos"):
                    for f in node_output.get(key, []):
                        fname = f["filename"]
                        subfolder = f.get("subfolder", "")
                        ftype = f.get("type", "output")
                        url = f"{COMFY_HOST}/view?filename={urllib.parse.quote(fname)}&subfolder={urllib.parse.quote(subfolder)}&type={ftype}"
                        with urllib.request.urlopen(url) as r:
                            outputs.append(base64.b64encode(r.read()).decode())

            if outputs:
                return outputs

        except urllib.error.URLError:
            pass

        time.sleep(3)

    raise RuntimeError(f"Timeout: job {prompt_id} não concluiu em {timeout}s")


def handler(job):
    job_input = job.get("input", {})
    workflow = job_input.get("workflow")
    images = job_input.get("images", [])

    if not workflow:
        return {"error": "Campo 'workflow' ausente no input"}

    try:
        # 1. Garantir que ComfyUI está pronto
        wait_for_comfy()

        # 2. Upload das imagens
        if images:
            upload_images(images)

        # 3. Enfileirar workflow
        prompt_id = queue_workflow(workflow)

        # 4. Aguardar resultado
        outputs = wait_for_output(prompt_id)

        return {"message": outputs, "status": "success"}

    except Exception as e:
        return runpod.RunPodError(str(e))


# Iniciar ComfyUI em background antes de registrar o handler
import subprocess
import sys

if __name__ == "__main__":
    comfy_cmd = [
        sys.executable,
        f"{COMFY_HOME}/main.py",
        "--listen", "127.0.0.1",
        "--port", "8188",
        "--disable-auto-launch",
    ]
    subprocess.Popen(comfy_cmd)
    print(f"[handler] ComfyUI iniciando em {COMFY_HOME}...")
    runpod.serverless.start({"handler": handler})
