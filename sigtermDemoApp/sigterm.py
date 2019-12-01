import time
import signal

running = True

def sigterm(x, y):
    global running
    print("SIGTERM received, flag instance as not ready")
    running = False

signal.signal(signal.SIGTERM, sigterm)

if __name__ == '__main__':
    while True:
        time.sleep(1)
        if (running):
            print('Running...')
        else:
            print('Cleaning up...')

