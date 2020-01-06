package main

import (
   "github.com/go-martini/martini"
   "github.com/satori/go.uuid"
)

func main() {
  m := martini.Classic()

  id, err := uuid.NewV4()
  if err != nil {
    panic("Unable to generate uuid")
  }

  m.Get("/", func() (int, string) {
    return 503, "I am dead: " + id.String()
  })

  m.Run()
}
