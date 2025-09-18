from fastapi import APIRouter, HTTPException, Request
from prisma import Prisma
from models.model import User


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
            raise HTTPException(status_code=400, message="empid, name, and password are required")
        existing_user = await db.user.find_unique(where={"empid": empid})
        if existing_user:
            raise HTTPException(status_code=400, message="User with this empid already exists")
        
        user = User(empid=empid, role=role, profileImage=profileImage)
        user.set_password(password)

        result = await db.user.create(
            data={
                "empid": user.empid,
                "role": user.role,
                "profileImage": user.profileImage,
                "passwordHash": user.passwordHash
            }
        )

        if not result:
            raise HTTPException(status_code=500, message="Failed to create user")

        return result

    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, message=f"Internal server error: {str(e)}")




