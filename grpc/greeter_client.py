from __future__ import print_function
import logging

import grpc

import helloworld_pb2
import helloworld_pb2_grpc

import os
import time

endpoint = os.environ.get("SERVER_WITH_PORT", 'localhost:50001')


def run():
    with grpc.insecure_channel(endpoint) as channel:
        stub = helloworld_pb2_grpc.GreeterStub(channel)
        while True:
            response = stub.SayHello(helloworld_pb2.HelloRequest(name='you'))
            print("Greeter client received: " + response.message)
            time.sleep(5)


if __name__ == '__main__':
    logging.basicConfig()
    run()