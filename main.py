from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
import hashlib
import json

app = FastAPI(title="MD5 Validator")

class ValidationRequest(BaseModel):
    date: dict
    md5: str

@app.get("/health")
async def health_check():
    return{"status": "ok"}

@app.post("/validate-md5")
async def validate_md5(payload: ValidationRequest):
    #1. Canonicalize the JSON (Sort keys, remove unnecesary whitespace)
    # This ensure the MD5 is calculated on the same string every time.
    json_string = json.dumps(payload.data, sort_keys=True, separators=(',', ':'))

    #2. Calculate MD5
    calculated_md5 = hashlib.md5(json_string.encode()).hexdigest()

    #3. Compare
    if calculated_md5 == payload.md5:
        return {"md5": calculated_md5}
    
    raise HTTPException(
        status_code=400,
        detail=f"MD5 mismatch. Calculated {calculated_md5}"
    )