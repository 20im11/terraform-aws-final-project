from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello ECS"

@app.route("/health")
def health():
    return "OK"