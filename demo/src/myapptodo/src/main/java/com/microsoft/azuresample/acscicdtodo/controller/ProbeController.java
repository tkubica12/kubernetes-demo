package com.microsoft.azuresample.acscicdtodo.controller;

import org.springframework.web.bind.annotation.*;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
public class ProbeController {
    static final Logger LOG = LoggerFactory.getLogger(ProbeController.class);

    @RequestMapping(value = "/", method = { RequestMethod.GET })
    public
    @ResponseBody
    String probe() {
        LOG.info("Probe.");
        return "OK";
    }
}

