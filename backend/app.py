from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from prisma import Prisma
from controllers import auth

app = FastAPI()
db = Prisma()




@app.on_event("startup")
async def startup():
    if not db.is_connected():
        await db.connect()

@app.on_event("shutdown")
async def shutdown():
    if db.is_connected():
        await db.disconnect()

app.include_router(auth.router)


@app.get("/")
async def index():
    return {"message": "Welcome to the Night Vigil Backend!"}



@app.get("/users")
async def get_users():
    users = await db.user.find_many()
    return [u.dict() for u in users]



if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
