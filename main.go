package main

import (
	"bytes"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/skip2/go-qrcode"
)

// QRCodeGenerator represents the core QR code generation functionality
type QRCodeGenerator struct{}

// GenerateQRCodeBytes generates a QR code and returns raw PNG bytes
func (qr *QRCodeGenerator) GenerateQRCodeBytes(text string) ([]byte, error) {
	if text == "" {
		return nil, fmt.Errorf("text cannot be empty")
	}

	pngBytes, err := qrcode.Encode(text, qrcode.Medium, 256)
	if err != nil {
		return nil, fmt.Errorf("failed to generate QR code: %w", err)
	}

	return pngBytes, nil
}

func main() {
	fmt.Println("QR Code Generator starting...")

	qrGen := &QRCodeGenerator{}

	// Simple HTTP server for now with QR generation endpoint
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		fmt.Fprintf(w, "QR Code Generator API")
	})

	http.HandleFunc("/test-qr", func(w http.ResponseWriter, r *http.Request) {
		text := r.URL.Query().Get("text")
		if text == "" {
			http.Error(w, "Missing required parameter 'text'. Usage: /test-qr?text=your-text-here", http.StatusBadRequest)
			return
		}

		pngBytes, err := qrGen.GenerateQRCodeBytes(text)
		if err != nil {
			http.Error(w, fmt.Sprintf("Error generating QR code: %v", err), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "image/png")
		w.Header().Set("Content-Length", fmt.Sprintf("%d", len(pngBytes)))

		reader := bytes.NewReader(pngBytes)
		http.ServeContent(w, r, "qrcode.png", time.Time{}, reader)
	})

	fmt.Println("Server starting on :8080")
	fmt.Println("Test QR endpoint: http://localhost:8080/test-qr?text=your-text-here")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
