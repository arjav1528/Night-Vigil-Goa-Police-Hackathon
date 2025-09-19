from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from prisma import Prisma
from models.model import User
from dotenv import load_dotenv
import os
from enum import Enum
from controllers.auth import UserOut

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
        profileImage = req.get("profileImage")
        role = req.get("role", "OFFICER")
        if not empid or not password or not role:
            return JSONResponse(status_code=400, content={"detail": "empid, name, and password are required"})
        existing_user = await db.user.find_unique(where={"empid": empid})
        if existing_user:
            return JSONResponse(status_code=400, content={"detail": "User with this empid already exists"})
        
        user = User(empid=empid, role=role, profileImage=profileImage)
        user.set_password(password)
        print(f"user : {user.to_dict()}")

        


        print(f"Creating user in database: {user.to_dict()}")

        result = await db.user.create(
            data=user.to_dict()
        )

        if not result:
            return JSONResponse(status_code=500, content={"detail": "Failed to create user"})

        result_dict = result.dict()
        for key, value in result_dict.items():
            if hasattr(value, "isoformat"):
                result_dict[key] = value.isoformat()

        return JSONResponse(status_code=201, content=result_dict)

    except Exception as e:
        print(f"Error during registration: {str(e)}")
        return JSONResponse(status_code=500, content={"detail": f"Internal server error: {str(e)}"})


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

        user_model = User(**user.dict())
        print(f"User model created: {user_model.empid}, role: {user_model.role}")

        if not user_model.verify_password(password):
            return JSONResponse(status_code=401, content={"detail": "Invalid credentials"})

        token = user_model.generate_token(SECRET_KEY)

        return JSONResponse(status_code=200, content={"access_token": token, "token_type": "bearer"})

    except Exception as e:
        await db.disconnect()
        print(f"Error during login: {str(e)}")
        return JSONResponse(status_code=500, content={"detail": str(e)})




@router.get("/me", response_model=UserOut)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user









