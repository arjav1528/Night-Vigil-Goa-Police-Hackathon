from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from PIL import Image
import requests
from io import BytesIO

# Import your face recognition utility functions and the Prisma client
import face_recog as fu
from prisma import Prisma

# --- Application Setup ---
app = FastAPI(
    title="Face Recognition Microservice",
    description="A service to enroll and verify faces, storing embeddings in PostgreSQL.",
)

# --- Database Connection ---
db = Prisma(auto_register=True)

# --- Configuration ---
RECOGNITION_THRESHOLD = 0.8 # Confidence threshold for a successful match

# --- Pydantic Models for API Data Validation ---
class EnrollRequest(BaseModel):
    user_id: str # This should be the user's unique ID from your main User table
    image_urls: List[str]

class VerifyRequest(BaseModel):
    user_id: str
    selfie_url: str

# --- API Endpoints ---

@app.on_event("startup")
async def startup():
    await db.connect()

@app.on_event("shutdown")
async def shutdown():
    if db.is_connected():
        await db.disconnect()

@app.get("/")
async def root():
    return {"message": "Face Recognition Microservice is running."}

@app.get("/users")
async def get_users():
    """
    Fetches all users from the PostgreSQL database.
    """
    users = await db.user.find_many()
    return {"users": users}

@app.post("/enroll")
async def enroll_face(request: EnrollRequest):
    """
    Enrolls a user by processing their images and storing the embeddings in PostgreSQL.
    """
    # --- FIX: First, verify the user actually exists ---
    user = await db.user.find_unique(where={'id': request.user_id})
    if not user:
        # If the user is not found, we can't create an embedding for them.
        # It's better to stop here and return a clear error.
        raise HTTPException(
            status_code=404, 
            detail=f"User with ID '{request.user_id}' not found. Cannot enroll face."
        )

    # --- If the user exists, proceed as before ---
    successful_enrollments = 0
    for url in request.image_urls:
        try:
            response = requests.get(url, stream=True)
            response.raise_for_status()
            img = Image.open(BytesIO(response.content))
            embedding = fu.extract_embedding(img)
            
            if embedding:
                # Store the new embedding, now we know the user exists.
                await db.faceembedding.create(
                    data={'userId': request.user_id, 'embedding': embedding}
                )
                successful_enrollments += 1
        except Exception as e:
            # Log the error but continue trying other images
            print(f"Failed to process image {url} for user {request.user_id}: {e}")

    if successful_enrollments == 0:
         raise HTTPException(
            status_code=400, 
            detail=f"Could not process any of the provided images for user {request.user_id}."
        )

    return {"message": f"Successfully enrolled {successful_enrollments} images for user {request.user_id}"}

@app.post("/verify")
async def verify_face(request: VerifyRequest):
    """
    Verifies a new selfie against a user's stored embeddings from PostgreSQL.
    """
    # 1. Get the embedding from the new selfie
    try:
        response = requests.get(request.selfie_url, stream=True)
        response.raise_for_status()
        img = Image.open(BytesIO(response.content))
        unknown_embedding = fu.extract_embedding(img)
        if not unknown_embedding:
            raise HTTPException(status_code=400, detail="No face detected in the provided selfie.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Could not process selfie image: {e}")

    # 2. Get the user's stored embeddings from the PostgreSQL database
    stored_embeddings = await db.faceembedding.find_many(where={'userId': request.user_id})
    if not stored_embeddings:
        raise HTTPException(status_code=404, detail="User is not enrolled for face recognition.")

    # 3. Compare the new selfie to all stored embeddings and find the best match
    highest_similarity = 0.0
    for record in stored_embeddings:
        similarity = fu.cosine_sim(unknown_embedding, record.embedding)
        if similarity > highest_similarity:
            highest_similarity = similarity

    # 4. Return the result based on the confidence threshold
    is_verified = highest_similarity >= RECOGNITION_THRESHOLD
    return {
        "verified": is_verified,
        "confidence": round(highest_similarity, 4)
    }

