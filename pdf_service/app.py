from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
import fitz  # PyMuPDF
import httpx
import os
import pytesseract
from PIL import Image
import io
import time
import base64

app = FastAPI(title="LLM PDF Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

LLAMA_URL = os.getenv("LLAMA_URL", "http://llama-server:8080")
LLAMA_URL_VISION = os.getenv("LLAMA_URL_VISION", "http://llama-server-vision:8080")
VISION_MODE = os.getenv("VISION_MODE", "false").lower() == "true"

# Servir l'interface web
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/")
async def root():
    return FileResponse("static/index.html")


class ChatRequest(BaseModel):
    question: str
    max_tokens: int = 1024


class ChatResponse(BaseModel):
    answer: str
    pages_extracted: int
    chars_extracted: int
    ocr_used: bool = False
    vision_used: bool = False
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0
    response_time: float = 0.0


def extract_images_from_pdf(pdf_bytes: bytes, max_pages: int = 5) -> list[str]:
    """Extrait les pages d'un PDF comme images base64."""
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    images_b64 = []
    
    for page_num in range(min(len(doc), max_pages)):
        page = doc[page_num]
        # Convertir la page en image
        mat = fitz.Matrix(1.5, 1.5)  # 1.5x zoom
        pix = page.get_pixmap(matrix=mat)
        img_data = pix.tobytes("png")
        
        # Convertir en base64
        img_b64 = base64.b64encode(img_data).decode('utf-8')
        images_b64.append(img_b64)
    
    doc.close()
    return images_b64


def extract_text_from_pdf(pdf_bytes: bytes) -> tuple[str, bool]:
    """Extrait le texte d'un PDF. Utilise OCR si le texte standard échoue."""
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    text = ""
    ocr_used = False
    
    # Essayer d'abord l'extraction de texte standard
    for page in doc:
        text += page.get_text()
    
    # Si peu ou pas de texte, utiliser l'OCR
    if len(text.strip()) < 100:
        ocr_used = True
        text = ""
        for page_num in range(len(doc)):
            page = doc[page_num]
            # Convertir la page en image haute résolution
            mat = fitz.Matrix(2.0, 2.0)  # 2x zoom pour meilleure OCR
            pix = page.get_pixmap(matrix=mat)
            img_data = pix.tobytes("png")
            img = Image.open(io.BytesIO(img_data))
            
            # OCR avec Tesseract (français + anglais)
            page_text = pytesseract.image_to_string(img, lang='fra+eng')
            text += page_text + "\n\n"
    
    doc.close()
    return text, ocr_used


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/analyze-pdf", response_model=ChatResponse)
async def analyze_pdf(
    file: UploadFile = File(...),
    question: str = "Résume ce document en français",
    max_tokens: int = 1024
):
    """
    Upload un PDF et pose une question dessus.
    """
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Le fichier doit être un PDF")
    
    pdf_bytes = await file.read()
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    page_count = doc.page_count
    doc.close()
    
    start_time = time.time()
    text = ""
    ocr_used = False
    vision_used = False
    
    # Mode Vision : envoyer les images directement au modèle
    if VISION_MODE:
        vision_used = True
        images_b64 = extract_images_from_pdf(pdf_bytes, max_pages=3)
        
        if not images_b64:
            raise HTTPException(status_code=400, detail="Impossible d'extraire les images du PDF")
        
        # Construire le message avec images pour l'API multimodale
        content = [{"type": "text", "text": question}]
        for img_b64 in images_b64:
            content.append({
                "type": "image_url",
                "image_url": {"url": f"data:image/png;base64,{img_b64}"}
            })
        
        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.post(
                f"{LLAMA_URL_VISION}/v1/chat/completions",
                json={
                    "messages": [{"role": "user", "content": content}],
                    "max_tokens": max_tokens,
                    "temperature": 0.7
                }
            )
            
            if response.status_code != 200:
                raise HTTPException(status_code=500, detail=f"Erreur LLM Vision: {response.text}")
            
            result = response.json()
            answer = result["choices"][0]["message"]["content"]
            usage = result.get("usage", {})
    
    # Mode Texte : OCR ou extraction de texte
    else:
        text, ocr_used = extract_text_from_pdf(pdf_bytes)
        
        if not text.strip():
            raise HTTPException(status_code=400, detail="Impossible d'extraire du texte du PDF (même avec OCR)")
        
        # Limiter la taille du texte (context window de ~8k tokens)
        # 4000 caractères ≈ 1000-1500 tokens, laissant de la marge pour le prompt et la réponse
        max_chars = 4000
        if len(text) > max_chars:
            text = text[:max_chars] + "\n\n[... document tronqué ...]"
        
        prompt = f"""Document PDF:
---
{text}
---

Question: {question}

Réponse:"""

        # Utiliser le serveur vision si VISION_MODE, sinon le serveur texte
        llm_url = LLAMA_URL_VISION if VISION_MODE else LLAMA_URL
        
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                f"{llm_url}/v1/chat/completions",
                json={
                    "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": max_tokens,
                    "temperature": 0.7
                }
            )
            
            if response.status_code != 200:
                raise HTTPException(status_code=500, detail=f"Erreur LLM: {response.text}")
            
            result = response.json()
            answer = result["choices"][0]["message"]["content"]
            usage = result.get("usage", {})
    
    response_time = round(time.time() - start_time, 2)
    
    return ChatResponse(
        answer=answer,
        pages_extracted=page_count,
        chars_extracted=len(text),
        ocr_used=ocr_used,
        vision_used=vision_used,
        prompt_tokens=usage.get("prompt_tokens", 0),
        completion_tokens=usage.get("completion_tokens", 0),
        total_tokens=usage.get("total_tokens", 0),
        response_time=response_time
    )


@app.post("/extract-text")
async def extract_text_endpoint(file: UploadFile = File(...)):
    """
    Extrait uniquement le texte d'un PDF sans appeler le LLM.
    """
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Le fichier doit être un PDF")
    
    pdf_bytes = await file.read()
    text, ocr_used = extract_text_from_pdf(pdf_bytes)
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    
    return {
        "filename": file.filename,
        "pages": doc.page_count,
        "chars": len(text),
        "ocr_used": ocr_used,
        "text": text
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
