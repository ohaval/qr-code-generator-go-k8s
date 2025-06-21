package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	fmt.Println("QR Code Generator starting...")

	// Simple HTTP server for now
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "QR Code Generator API")
	})

	fmt.Println("Server starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}