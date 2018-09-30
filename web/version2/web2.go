package main

import (
   "github.com/go-martini/martini"
   "os/exec"
)

func main() {
  m := martini.Classic()

  uuid, err := exec.Command("uuidgen").Output()
  if err != nil {
    panic("Unable to generate uuid")
  }

  m.Get("/", func() string {
    return "<h1>Welcome to Version 2<br><br>This is server " + string(uuid) + "</h1>"
  })

  m.Run()
}
