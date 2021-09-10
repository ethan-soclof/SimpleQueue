import pika, sys, os
import time

def main():
    connection = pika.BlockingConnection(pika.ConnectionParameters('rabbit', heartbeat=600))
    channel = connection.channel()
    channel.queue_declare(queue='queue')

    def callback(ch, method, properties, body):
        print("Received")
        ch.basic_ack(delivery_tag=method.delivery_tag)
        time.sleep(3)

    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue='queue', on_message_callback=callback, auto_ack=False)

    channel.start_consuming()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('Interrupted')
        try:
            sys.exit(0)
        except SystemExit:
            os._exit(0)
