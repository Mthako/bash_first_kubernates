from fastapi import FastAPI
from pydantic import BaseModel
import requests

app = FastAPI(title="Orchestrator (chat simulator)")

MCP_URL = "http://127.0.0.1:9001/call"

class ChatIn(BaseModel):
    user: str

@app.post("/chat")
def chat_endpoint(msg: ChatIn):
    text = msg.user.strip().lower()

    if text.startswith("list pods"):
        payload = {
            "tool": "list_pods",
            "args": {"namespace": "default"}
        }
        r = requests.post(MCP_URL, json=payload)
        return {
            "reply": "Called MCP list_pods",
            "mcp": r.json()
        }

    return {"reply": "Unknown command. Try 'list pods'."}
