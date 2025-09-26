from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from prisma import Prisma
import os

from models.model import Role, User
from dotenv import load_dotenv
load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = "HS256"

if not SECRET_KEY:
    raise ValueError("SECRET_KEY environment variable is required")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/users/login")
db = Prisma()

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    if not token or token.strip() == "":
        raise credentials_exception
        
    try:
        if not db.is_connected():
            await db.connect()
            
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        empid: str = payload.get("empid")
        
        if empid is None or empid.strip() == "":
            raise credentials_exception
            
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token validation failed: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication service error: {str(e)}"
        )
    
    try:
        if not db.is_connected():
            await db.connect()
            
        user_data = await db.user.find_unique(where={"empid": empid})
        if user_data is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Convert database record to User model instance with null safety
        user = User(
            id=user_data.id,
            empid=user_data.empid,
            role=user_data.role,
            profileImage=user_data.profileImage if user_data.profileImage else [],
            passwordHash=user_data.passwordHash,
            createdAt=user_data.createdAt,
            updatedAt=user_data.updatedAt
        )
        
        return user
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error during authentication: {str(e)}"
        )

async def get_current_admin_user(current_user: User = Depends(get_current_user)):
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required"
        )
        
    if current_user.role != Role.ADMIN:
        print("Admin access required")
        print(f"Current user role: {current_user.role}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Admin privileges required to access this resource"
        )
    return current_user