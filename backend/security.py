# backend/security.py

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from prisma import Prisma
import os

# Import your User model
from models.model import User

SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = "HS256"

# This dependency extractor looks for the "Authorization: Bearer <token>" header
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/users/login")
db = Prisma()

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """
    Decodes the JWT to get the user's empid, fetches the user from the DB,
    and returns the user object. This is the primary dependency for user authentication.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
    )
    try:
        if not db.is_connected():
            await db.connect()
            
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        empid: str = payload.get("empid")
        if empid is None:
            raise credentials_exception
            
    except JWTError:
        raise credentials_exception
        
    user = await db.user.find_unique(where={"empid": empid})
    if user is None:
        raise credentials_exception
        
    return user

async def get_current_admin_user(current_user: User = Depends(get_current_user)):
    """
    A dependency that relies on get_current_user to first get the user,
    and then checks if the user's role is 'ADMIN'.
    """
    if current_user.role != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="The user does not have privileges to access this resource"
        )
    return current_user