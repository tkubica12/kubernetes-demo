package com.microsoft.azuresample.acscicdtodo.controller;

import com.microsoft.azuresample.acscicdtodo.model.ToDo;
import com.microsoft.azuresample.acscicdtodo.model.ToDoDAO;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.UUID;
import java.util.Date;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
public class MainController {
    static final Logger LOG = LoggerFactory.getLogger(MainController.class);

    ToDoDAO dao=new ToDoDAO();

    @CrossOrigin(origins = "http://localhost:8080")
    @RequestMapping(value = "/api/todo/{id}", method = { RequestMethod.PUT })
    public
    @ResponseBody
    ToDo putToDo(@RequestBody ToDo item) {
        LOG.info("PUT todo.");
        item.setCreated(new Date());
        dao.update(item);
        item=dao.query(item.getId());
        return item;
    }

    @CrossOrigin(origins = "http://localhost:8080")
    @RequestMapping(value = "/api/todo", method = { RequestMethod.GET })
    public
    @ResponseBody
    List<ToDo> getToDo() {
        LOG.info("Get todoes.");
        List<ToDo> ret = dao.query();
        return ret;
    }

    @CrossOrigin(origins = "http://localhost:8080")
    @RequestMapping(value = "/api/todo", method = { RequestMethod.POST })
    public
    @ResponseBody
    ToDo postToDo(@RequestBody ToDo item) {
        LOG.info("POST todo.");
        item.setId(UUID.randomUUID().toString());
        item.setCreated(new Date());
        item.setUpdated(new Date());
        dao.create(item);
        item=dao.query(item.getId());
        return item;
    }

    @CrossOrigin(origins = "http://localhost:8080")
    @RequestMapping(value = "/api/todo/{id}", method = { RequestMethod.GET })
    public
    @ResponseBody
    ToDo getToDo(@PathVariable("id") String id) {
        LOG.info("Get todo.");
        ToDo ret = dao.query(id);
        return ret;
    }
}

