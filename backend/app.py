from time import time
from fastapi import FastAPI, HTTPException, Request, Response
from pydantic import BaseModel
from prisma import Prisma
from controllers import auth
from starlette.middleware.base import BaseHTTPMiddleware

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

@app.middleware("http")
async def middleware(request: Request, call_next):
    print(f"Request to {request.url.path}")
    print(f"Method: {request.method}")
    print(f"Header: {request.headers}")
    try:
        data = await request.json()
        print(f"JSON Body: {data}")

        response = await call_next(request)
        return response
    except Exception as e:
        # pass  # Not all requests have JSON bodies
        print("No JSON body found")
        return Response("Invalid request", status_code=400)


    # response = await call_next(request)
    # return response



@app.get("/")
async def index():
    return {"message": "Welcome to the Night Vigil Backend!"}



@app.get("/users")
async def get_users():
    users = await db.user.find_many()
    return [u.dict() for u in users]



if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
