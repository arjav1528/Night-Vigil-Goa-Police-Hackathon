from time import time
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from prisma import Prisma
from controllers import auth
from controllers import duties

app = FastAPI()
db = Prisma()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # allows everything
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)




@app.on_event("startup")
async def startup():
    if not db.is_connected():
        await db.connect()

@app.on_event("shutdown")
async def shutdown():
    if db.is_connected():
        await db.disconnect()



app.include_router(auth.router)
app.include_router(duties.router)

@app.middleware("http")
async def middleware(request: Request, call_next):

    if request.url.path in ["/", "/users", "/openapi.json", "/redoc"]:
        response = await call_next(request)
        return response
    print(f"Request to {request.url.path}")
    print(f"Method: {request.method}")
    print(f"Header: {request.headers}")
    

    response = await call_next(request)
    return response





@app.get("/")
async def index():
    return {"message": "Welcome to the Night Vigil Backend!"}



@app.get("/users")
async def get_users():
    users = await db.user.find_many()
    return [u.dict() for u in users]


@app.delete("/users")
async def delete_all_users():
    if not db.is_connected():
        await db.connect()
    await db.faceembedding.delete_many()
    await db.user.delete_many()
    return {"detail": "All users deleted"}

@app.delete("/users/{empid}")
async def delete_user(empid):
    if not db.is_connected():
        await db.connect()

    user = await db.user.find_unique(where={"empid": empid})
    if user:
        await db.dutyassignment.delete_many(where={"officerId": user.id})
        await db.faceembedding.delete_many(where={"userId": user.id})
        await db.user.delete(where={"empid": empid})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"detail": "User deleted"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
