from flask import Flask
app = Flask(__name__)

@app.route('/add', methods=['POST'])
def add():
    return "Added!"

if __name__ == '__main__':
    app.run()