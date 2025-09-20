from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from prisma import Prisma
from models.model import User
from dotenv import load_dotenv
import os
from enum import Enum
from models.schemas import UserOut

from security import get_current_user
load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")

db = Prisma()

router = APIRouter(
    prefix="/users",
    tags=["auth"]
)

@router.on_event("startup")
async def startup():
    if not db.is_connected:
        await db.connect()

@router.on_event("shutdown")
async def shutdown():
    if db.is_connected:
        await db.disconnect()


@router.post("/register")
async def register(request: Request):
    try:
        if not db.is_connected():
            await db.connect()
        req = await request.json()
        empid = req.get("empid")
        password = req.get("password")
        profileImages = req.get("profileImages") 
        role = req.get("role", "OFFICER")
        
        print(f"Raw profileImages from request: {profileImages}")
        print(f"Type of profileImages: {type(profileImages)}")
        
        if not empid or not password or not role:
            return JSONResponse(status_code=400, content={"detail": "empid, password, and role are required"})
        
        existing_user = await db.user.find_unique(where={"empid": empid})
        if existing_user:
            return JSONResponse(status_code=400, content={"detail": "User with this empid already exists"})
        
        # Create user with profileImages
        user = User(empid=empid, role=role, profileImage=profileImages)
        user.set_password(password)
        
        print(f"User object profileImage after creation: {user.profileImage}")
        print(f"Type of user.profileImage: {type(user.profileImage)}")

        # Create user in database
        result = await db.user.create(
            data={
                "id": user.id,
                "empid": user.empid,
                "role": user.role.value if isinstance(user.role, Enum) else user.role,
                "profileImage": user.profileImage,
                "passwordHash": user.passwordHash,
                "createdAt": user.createdAt,
                "updatedAt": user.updatedAt,
            }
        )

        print(f"Database result profileImage: {result.profileImage}")

        # Now process images and create embeddings if images exist
        if user.profileImage:
            try:
                await process_user_images_and_create_embeddings(user.id, user.profileImage)
            except Exception as e:
                print(f"Error creating embeddings: {str(e)}")

        result_dict = result.dict()
        for key, value in result_dict.items():
            if hasattr(value, "isoformat"):
                result_dict[key] = value.isoformat()

        return JSONResponse(status_code=201, content=result_dict)

    except Exception as e:
        print(f"Error during registration: {str(e)}")
        return JSONResponse(status_code=500, content={"detail": f"Internal server error: {str(e)}"})

async def process_user_images_and_create_embeddings(user_id: str, image_paths: List[str]):
    """
    Process user images and create face embeddings
    """
    for image_path in image_paths:
        try:
            # TODO: Call your ML model here to get embeddings
            # embedding = await get_face_embedding_from_ml_model(image_path)
            embedding = [0.1, 0.2, 0.3]  # Placeholder - replace with actual ML model call
            
            # Store embedding in database
            await db.faceembedding.create(
                data={
                    "userId": user_id,
                    "embedding": embedding,
                }
            )
        except Exception as e:
            print(f"Error processing image {image_path}: {str(e)}")
            # Continue processing other images
            continue

@router.post("/login")
async def login(request: Request):
    try:
        if not db.is_connected():
            await db.connect()
        req = await request.json()
        empid = req.get("empid")
        password = req.get("password")
        if not empid or not password:
            return JSONResponse(status_code=400, content={"detail": "empid and password are required"})
        
        user = await db.user.find_unique(where={"empid": empid})
        if not user:
            return JSONResponse(status_code=404, content={"detail": "User not found"})
        
        print(user)

        user_model = User(
            id=user.id,
            empid=user.empid,
            role=user.role,
            profileImage=user.profileImage,
            passwordHash=user.passwordHash,
            createdAt=user.createdAt,
            updatedAt=user.updatedAt
            # Remove the faceEmbeddings parameter
        )
        print(f"User model created: {user_model.empid}, role: {user_model.role}")

        if not user_model.verify_password(password):
            return JSONResponse(status_code=401, content={"detail": "Invalid credentials"})

        token = user_model.generate_token(SECRET_KEY)

        return JSONResponse(status_code=200, content={"access_token": token, "token_type": "bearer"})

    except Exception as e:
        await db.disconnect()
        print(f"Error during login: {str(e)}")
        return JSONResponse(status_code=500, content={"detail": str(e)})
    

@router.post("/admin/login")
async def admin_login(request: Request):
    try:
        if not db.is_connected():
            await db.connect()

        request = await request.json()

        print(request)
        
        empid = request.get("empid")
        password = request.get("password")


        if not empid or not password:
            return JSONResponse(status_code=400, content={"message" : "Bad Request"})
        
        user = await db.user.find_unique(where={"empid": empid, "role" : "ADMIN"})
        if not user:
            return JSONResponse(status_code=404, content={"detail": "User not found"})
        
        print(user)

        user_model = User(
            id=user.id,
            empid=user.empid,
            role=user.role,
            profileImage=user.profileImage,
            passwordHash=user.passwordHash,
            createdAt=user.createdAt,
            updatedAt=user.updatedAt
            # Remove the faceEmbeddings parameter
        )
        print(f"User model created: {user_model.empid}, role: {user_model.role}")

        if not user_model.verify_password(password):
            return JSONResponse(status_code=401, content={"detail": "Invalid credentials"})

        token = user_model.generate_token(SECRET_KEY)

        return JSONResponse(status_code=200, content={"access_token": token, "token_type": "bearer"})
    

    except Exception as e:
        print(f"Error {e}")
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})
    


@router.post('/admin/register')
async def admin_register(request : Request):
    try:
        if not db.is_connected():
            await db.connect()

        request = await request.json()

        empid = request.get("empid")
        password = request.get("password")
        # print(request.body)

        



        if not empid or not password:
            return JSONResponse(status_code=400, content={"message" : "Bad t"})
            
        user = await db.user.find_unique(where={"empid": empid, "role" : "ADMIN"})
        if user:
            return JSONResponse(status_code=404, content={"detail": "User already exists"})
        
        

        new_user = User(empid=empid, role="ADMIN")
        new_user.set_password(password=password)
        print(f"new user : {new_user.to_dict()}")

        
        await db.user.create(data=new_user.to_dict())

        return JSONResponse(status_code=201, content={"detail": "User registered successfully"})
    
    except Exception as e:
        print(e)
        return JSONResponse(status_code=500,content={"message" : "Internal Server Error"})

@router.get("/me", response_model=UserOut)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user









