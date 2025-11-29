from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi import Request
import subprocess, json, shlex

app = FastAPI(title="MCP Server - kubectl wrapper")

class ToolCall(BaseModel):
    tool: str
    args: dict = {}

def run_kubectl(cmd_args: list):
    try:
        out = subprocess.check_output(["kubectl"] + cmd_args, stderr=subprocess.STDOUT)
        return out.decode()
    except subprocess.CalledProcessError as e:
        raise RuntimeError(e.output.decode())

@app.post("/call")
def call_tool(call: ToolCall):
    """
    Supported tools:
      - list_pods  -> args: {namespace: str }
      - scale      -> args: {deployment: str, namespace: str, replicas: int}
      - get_logs   -> args: {pod: str, namespace: str, tail: int}
      - rollout_status -> args: {deployment: str, namespace: str, timeout: str (e.g. '2m')}
    """
    tool = call.tool
    a = call.args or {}

    try:
        if tool == "list_pods":
            ns = a.get("namespace", "default")
            out = run_kubectl(["get", "pods", "-n", ns, "-o", "json"])
            return {"ok": True, "output": json.loads(out)}
        if tool == "scale":
            deployment = a["deployment"]
            ns = a.get("namespace", "default")
            replicas = int(a["replicas"])
            # safety: prevent scaling to zero unless allowed
            if replicas == 0:
                return {"ok": False, "error": "Scaling to 0 replicas is blocked by policy."}
            out = run_kubectl(["scale", "deployment", deployment, "-n", ns, f"--replicas={replicas}"])
            return {"ok": True, "output": out}
        if tool == "get_logs":
            pod = a["pod"]
            ns = a.get("namespace", "default")
            tail = str(a.get("tail", 200))
            out = run_kubectl(["logs", pod, "-n", ns, f"--tail={tail}"])
            return {"ok": True, "output": out}
        if tool == "rollout_status":
            deployment = a["deployment"]
            ns = a.get("namespace", "default")
            timeout = a.get("timeout", "2m")
            out = run_kubectl(["rollout", "status", f"deployment/{deployment}", "-n", ns, f"--timeout={timeout}"])
            return {"ok": True, "output": out}
        return {"ok": False, "error": f"Tool '{tool}' not supported"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

#------------------------new end point


@app.post("/exec_script")
async def exec_script(req: Request):
    """
    Accept a raw bash script payload in JSON {"script": "<bash script>"}.
    Runs the script with dry-run or actual run (env var DRY_RUN).
    """
    data = await req.json()
    script = data.get("script")
    if not script:
        raise HTTPException(status_code=400, detail="Missing 'script' in request body.")

    import tempfile, os, subprocess

    # Save script to temp file
    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".sh") as f:
        f.write(script)
        path = f.name

    # Set DRY_RUN environment (default true)
    dry_run = os.environ.get("DRY_RUN", "true").lower() == "true"

    try:
        # Check syntax only first
        subprocess.check_output(["bash", "-n", path], stderr=subprocess.STDOUT)

        if dry_run:
            # Just return the script and dry-run notice
            return {"ok": True, "dry_run": True, "script": script}

        # Run script with bash -x for trace
        proc = subprocess.run(["bash", "-x", path], capture_output=True, text=True, timeout=300)
        return {"ok": proc.returncode == 0, "stdout": proc.stdout, "stderr": proc.stderr, "returncode": proc.returncode}

    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=400, detail=f"Script syntax error: {e.output.decode()}")
    finally:
        os.unlink(path)
