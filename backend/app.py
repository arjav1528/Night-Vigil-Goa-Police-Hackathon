from time import time
from fastapi import FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from prisma import Prisma
from controllers import auth
from controllers import duties
import logging


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Night Vigil Backend API",
    description="Backend API for Night Vigil Goa Police Hackathon",
    version="1.0.0"
)

db = Prisma()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def ensure_db_connection():
    """Ensure database connection with error handling"""
    try:
        if not db.is_connected():
            await db.connect()
            logger.info("Database connected successfully")
    except Exception as e:
        logger.error(f"Database connection failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database connection failed: {str(e)}"
        )

@app.on_event("startup")
async def startup():
    await ensure_db_connection()
    logger.info("Application started successfully")

@app.on_event("shutdown")
async def shutdown():
    try:
        if db.is_connected():
            await db.disconnect()
            logger.info("Database disconnected successfully")
    except Exception as e:
        logger.error(f"Error during shutdown: {str(e)}")

@app.middleware("http")
async def middleware(request: Request, call_next):
    start_time = time()
    
    # Skip logging for documentation endpoints
    if request.url.path in ["/", "/docs", "/openapi.json", "/redoc"]:
        response = await call_next(request)
        return response
    
    logger.info(f"Request: {request.method} {request.url.path}")
    
    try:
        response = await call_next(request)
        process_time = time() - start_time
        response.headers["X-Process-Time"] = str(process_time)
        
        logger.info(f"Response: {response.status_code} - {process_time:.4f}s")
        return response
        
    except Exception as e:
        process_time = time() - start_time
        logger.error(f"Request failed: {request.method} {request.url.path} - {str(e)} - {process_time:.4f}s")
        
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"detail": "Internal server error occurred"}
        )

# Include routers
app.include_router(auth.router)
app.include_router(duties.router)

@app.get("/")
async def index():
    return {
        "message": "Welcome to the Night Vigil Backend!",
        "version": "1.0.0",
        "status": "operational"
    }

@app.get("/health")
async def health_check():
    try:
        await ensure_db_connection()
        return {
            "status": "healthy",
            "database": "connected",
            "timestamp": time()
        }
    except Exception as e:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unhealthy",
                "database": "disconnected",
                "error": str(e),
                "timestamp": time()
            }
        )

@app.get("/users")
async def get_users():
    try:
        await ensure_db_connection()
        
        users = await db.user.find_many()

        Users = []
        for user in users:
            Users.append({
                "id": user.id,
                "empid": user.empid,
                "role": user.role,
                "profileImage": user.profileImage if user.profileImage else [],
                "createdAt": user.createdAt.isoformat() if user.createdAt else None,
                "updatedAt": user.updatedAt.isoformat() if user.updatedAt else None
            })

        print(Users)

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"users": Users, "count": len(Users)}
        )
        
    except Exception as e:
        logger.error(f"Error fetching users: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch users: {str(e)}"
        )

@app.delete("/users")
async def delete_all_users():
    try:
        await ensure_db_connection()
        
        # Delete in proper order to maintain referential integrity
        await db.notification.delete_many()
        await db.dutyreport.delete_many()
        await db.dutylog.delete_many()
        await db.dutyassignment.delete_many()
        await db.faceembedding.delete_many()
        deleted_users = await db.user.delete_many()
        
        logger.info("All users and related data deleted")
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"detail": "All users deleted successfully"}
        )
        
    except Exception as e:
        logger.error(f"Error deleting all users: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete users: {str(e)}"
        )

@app.delete("/users/{empid}")
async def delete_user(empid: str):
    try:
        await ensure_db_connection()
        
        if not empid or empid.strip() == "":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="empid is required"
            )
        
        empid = empid.strip()
        
        user = await db.user.find_unique(where={"empid": empid})
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Delete related data in proper order
        await db.notification.delete_many(where={"userId": user.id})
        await db.dutyreport.delete_many(where={"officerId": user.id})
        await db.dutylog.delete_many(where={"officerId": user.id})
        await db.dutyassignment.delete_many(where={"officerId": user.id})
        await db.faceembedding.delete_many(where={"userId": user.id})
        await db.user.delete(where={"empid": empid})
        
        logger.info(f"User {empid} and related data deleted")
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"detail": f"User {empid} deleted successfully"}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting user {empid}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete user: {str(e)}"
        )

# Global exception handler
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "detail": exc.detail,
            "status_code": exc.status_code,
            "path": request.url.path
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {str(exc)}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "An unexpected error occurred",
            "status_code": 500,
            "path": request.url.path
        }
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=True,
        reload_dirs=["./"],
        reload_includes=["*.py"]
    )
