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
    # 1. Convert the Pydantic model to a standard dictionary
    data_dict = payload.model_dump()
    
    # 2. Extract and remove the client's sent MD5 signature
    client_md5 = data_dict.pop("md5", None)
    
    # 3. Canonicalize ONLY the remaining data payload fields
    json_string = json.dumps(data_dict, sort_keys=True, separators=(',', ':'))
    
    # 4. Calculate the true mathematical hash of the data fields
    calculated_md5 = hashlib.md5(json_string.encode('utf-8')).hexdigest()
    
    # 5. Execute the validation match check
    if client_md5 != calculated_md5:
        raise HTTPException(status_code=400, detail=f"MD5 mismatch. Calculated {calculated_md5}")
        
    return {"status": "success", "message": "Payload integrity verified"}