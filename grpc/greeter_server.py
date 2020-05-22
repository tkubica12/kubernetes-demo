from concurrent import futures
import logging

import grpc

import helloworld_pb2
import helloworld_pb2_grpc

import socket
import os

port = '[::]:' + str(os.environ.get("PORT", 50001))

class Greeter(helloworld_pb2_grpc.GreeterServicer):

    def SayHello(self, request, context):
        return helloworld_pb2.HelloReply(message='Hello from %s!' % socket.gethostname())


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    helloworld_pb2_grpc.add_GreeterServicer_to_server(Greeter(), server)
    server.add_insecure_port(port)
    server.start()
    print("Listening on ", port)
    server.wait_for_termination()


if __name__ == '__main__':
    logging.basicConfig()
    serve()