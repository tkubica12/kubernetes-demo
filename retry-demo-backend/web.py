import cherrypy
from random import *
import os
import time

class web(object):
    @cherrypy.expose
    def index(self, failRate=50):
        if int(failRate) > randint(1, 100):   # Should fail?
            time.sleep(5)
            os._exit(os.EX_UNAVAILABLE)
        else:
            return "OK"

cherrypy.config.update({'server.socket_port': 80, 'server.socket_host': '0.0.0.0'})
cherrypy.quickstart(web())
