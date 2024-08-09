package main

import "fmt"

func add(a, b int) (r int)

func main() {
	fmt.Println(add(12, 34))
}

// GOARCH=amd64 go build
// ./mm2
