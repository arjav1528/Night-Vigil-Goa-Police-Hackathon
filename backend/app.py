from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from prisma import Prisma

app = FastAPI()
db = Prisma()

# --- Startup / Shutdown hooks ---
@app.on_event("startup")
async def startup():
    if not db.is_connected():
        await db.connect()

@app.on_event("shutdown")
async def shutdown():
    if db.is_connected():
        await db.disconnect()

# --- Request schema ---
class UserCreate(BaseModel):
    name: str
    email: str

# --- Routes ---
@app.get("/")
async def index():
    return {"message": "Welcome to the Night Vigil Backend!"}

@app.post("/add_user")
async def add_user(user: UserCreate):
    try:
        new_user = await db.user.create(
            data={"name": user.name, "email": user.email}
        )
        return new_user.dict()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/users")
async def get_users():
    users = await db.user.find_many()
    return [u.dict() for u in users]



if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
