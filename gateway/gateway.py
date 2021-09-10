import pika
from flask import Flask, render_template, request

app = Flask(__name__)

connection = pika.BlockingConnection(pika.ConnectionParameters('rabbit', heartbeat=600))
channel = connection.channel()

channel.basic_qos(prefetch_count=1)

channel.queue_declare(queue='queue')

@app.route('/')
def home():
    return render_template("home.html")

@app.route('/add')
def add():
    channel.basic_publish(exchange='', routing_key='queue', body='Hello World!')
    return render_template("add.html")

@app.route('/get')
def get():
    res = channel.queue_declare(
        queue="queue",
        passive=True
    )
    return render_template("get.html", count=str(res.method.message_count))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
