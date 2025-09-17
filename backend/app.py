from flask import Flask, request, jsonify
from prisma import Prisma

app = Flask(__name__)
db = Prisma()



@app.route("/")
async def index():
    return jsonify({"message": "Welcome to the Night Vigil Backend!"})

@app.route("/add_user", methods=["POST"])
async def add_user():
    
    if not db.is_connected():
        await db.connect()

    data = request.get_json()
    name = data.get("name")
    email = data.get("email")

    if not name or not email:
        return jsonify({"error": "Name and email are required"}), 400

    try:
        user = await db.user.create(
            data={
                "name": name,
                "email": email
            }
        )
        return jsonify(user.dict()), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- Fetch all users ---
@app.route("/users", methods=["GET"])
async def get_users():
    if not db.is_connected():
        await db.connect()
    users = await db.user.find_many()
    return jsonify([u.dict() for u in users])

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
