from flask import Flask, jsonify
from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)


@app.route('/', methods=['GET'])
def home():
    return jsonify({"message": "Welcome to API"})




@app.route('/api/data', methods=['GET'])
def get_data():
    sample_data = {
        "id": 1,
        "name": "Sample Item",
        "description": "This is a sample item."
    }
    return jsonify(sample_data)


@app.route('/api/status', methods=['GET'])
def get_status():

    SECRET_KEY = os.getenv('SECRET_KEY')
    status = {
        "status": "OK",
        "message": "API is running smoothly.",
        "secret_key": SECRET_KEY
    }
    return jsonify(status)

if __name__ == '__main__':
    app.run(debug=True)
