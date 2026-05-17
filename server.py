from fastapi import FastAPI, UploadFile, File, Form, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from PIL import Image
import io
import base64
import requests
import uvicorn
import os

# Initialize Rate-Limiter: Prevents API abuse and high CPU utilization.
# 5 requests per minute per client IP is a standard baseline for local vision LLMs.
limiter = Limiter(key_func=get_remote_address)
app = FastAPI()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Pull API key securely from environment variables, fallback to placeholder for local dev
API_KEY = os.getenv("AURA_API_KEY", "YOUR_SECURE_API_KEY_HERE")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Restrict this to your specific mobile domain or client ingress in production
    allow_methods=["POST"], # Expose only necessary POST methods for chat orchestration
    allow_headers=["*"],
)

def scale_image(image_bytes):
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.thumbnail((672, 672))
        buffered = io.BytesIO()
        img.save(buffered, format="JPEG", quality=85)
        return base64.b64encode(buffered.getvalue()).decode('utf-8')
    except Exception:
        return None

@app.post("/chat")
@limiter.limit("5/minute") # Active rate limiting window
async def chat(
    request: Request, # Required by the slowapi context executor
    prompt: str = Form(...), 
    image: UploadFile = File(None),
    x_api_key: str = Header(None)
):
    # 1. API Key Validation (Gateway Access Control)
    if x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Access Denied: Invalid or missing API key header.")

    payload = {
        "model": "aura", 
        "prompt": prompt,
        "stream": False
    }

    # 2. Image Processing & Pre-compression Validation
    if image:
        img_content = await image.read()
        base64_image = scale_image(img_content)
        if base64_image:
            payload["images"] = [base64_image]

    # 3. Downstream Ollama Engine Request with Lifecycle Timeouts
    try:
        # Utilizing loopback IP explicitly instead of localhost for faster resolution bindings
        response = requests.post(
            "http://127.0.0.1:11434/api/generate", 
            json=payload, 
            timeout=120
        )
        response.raise_for_status() # Catches 4xx or 5xx downstream engine exceptions
        return response.json()
    except requests.exceptions.Timeout:
        return {"error": "The local AI engine timed out processing the request."}
    except Exception as e:
        return {"error": f"Internal orchestration engine failure: {str(e)}"}

if __name__ == "__main__":
    # Binds to 0.0.0.0 to properly allow interface routing through container networks or reverse proxies
    uvicorn.run(app, host="0.0.0.0", port=8000)
