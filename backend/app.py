from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/api/data', methods=['GET'])
def get_data():
    sample_data = {
        "id": 1,
        "name": "Sample Item",
        "description": "This is a sample item."
    }
    return jsonify(sample_data)

if __name__ == '__main__':
    app.run(debug=True)
