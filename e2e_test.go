//go:build e2e

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

var (
	// Base URL for the service - configurable via E2E_BASE_URL environment variable
	// Defaults to localhost for backwards compatibility
	baseURL = getBaseURL()
	// Timeout for HTTP requests
	requestTimeout = 10 * time.Second
)

// getBaseURL returns the base URL for testing, checking environment variable first
func getBaseURL() string {
	if envURL := os.Getenv("E2E_BASE_URL"); envURL != "" {
		// Remove trailing slash for consistency
		envURL = strings.TrimSuffix(envURL, "/")
		return envURL
	}
	return "http://localhost:8080"
}

// Test client with timeout
var client = &http.Client{
	Timeout: requestTimeout,
}

// TestE2EServiceReachable - run this first to verify setup
func TestE2EServiceReachable(t *testing.T) {
	t.Logf("🎯 Testing service at: %s", baseURL)
	resp, err := client.Get(baseURL + "/health")
	if err != nil {
		t.Fatalf("❌ Service not reachable at %s. Error: %v", baseURL, err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("❌ Service not healthy. Status: %d", resp.StatusCode)
	}

	t.Logf("✅ Service is reachable and healthy at %s", baseURL)
}

// TestE2EHealthEndpoint tests the health check endpoint
func TestE2EHealthEndpoint(t *testing.T) {
	resp, err := client.Get(baseURL + "/health")
	if err != nil {
		t.Fatalf("Failed to make health request: %v", err)
	}
	defer resp.Body.Close()

	// Check status code
	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, resp.StatusCode)
	}

	// Check content type
	contentType := resp.Header.Get("Content-Type")
	if !strings.Contains(contentType, "application/json") {
		t.Errorf("Expected JSON content type, got %s", contentType)
	}

	// Check response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("Failed to read response body: %v", err)
	}

	var healthResponse map[string]interface{}
	if err := json.Unmarshal(body, &healthResponse); err != nil {
		t.Fatalf("Failed to parse JSON response: %v", err)
	}

	if status, ok := healthResponse["status"]; !ok || status != "healthy" {
		t.Errorf("Expected status 'healthy', got %v", status)
	}

	t.Logf("✅ Health endpoint test passed")
}

// TestE2EQRGenerationText tests QR code generation with plain text
func TestE2EQRGenerationText(t *testing.T) {
	testCases := []struct {
		name     string
		text     string
		wantCode int
	}{
		{"Simple text", "hello world", http.StatusOK},
		{"Empty text", "", http.StatusBadRequest},
		{"Long text", strings.Repeat("a", 1000), http.StatusOK},
		{"Special characters", "Hello! @#$%^&*()_+", http.StatusOK},
		{"Unicode text", "Hello 世界 🌍", http.StatusOK},
		{"Numbers", "12345", http.StatusOK},
		{"Mixed alphanumeric", "Test123ABC", http.StatusOK},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			requestURL := fmt.Sprintf("%s/api/v1/qr/generate?text=%s", baseURL, url.QueryEscape(tc.text))
			resp, err := client.Post(requestURL, "", nil)
			if err != nil {
				t.Fatalf("Failed to make QR generation request: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != tc.wantCode {
				t.Errorf("Expected status %d, got %d", tc.wantCode, resp.StatusCode)
			}

			if tc.wantCode == http.StatusOK {
				// Check content type for successful requests
				contentType := resp.Header.Get("Content-Type")
				if contentType != "image/png" {
					t.Errorf("Expected image/png content type, got %s", contentType)
				}

				// Check that we got image data
				body, err := io.ReadAll(resp.Body)
				if err != nil {
					t.Fatalf("Failed to read response body: %v", err)
				}

				if len(body) == 0 {
					t.Error("Expected image data, got empty response")
				}

				// Check PNG header (first 8 bytes)
				if len(body) >= 8 {
					pngHeader := []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}
					if !bytes.Equal(body[:8], pngHeader) {
						t.Error("Response doesn't appear to be a valid PNG image")
					}
				}

				t.Logf("✅ Generated QR code for '%s' (%d bytes)", tc.text, len(body))
			} else {
				t.Logf("✅ Correctly rejected invalid input '%s' with status %d", tc.text, resp.StatusCode)
			}
		})
	}
}

// TestE2EQRGenerationURL tests QR code generation with URLs
func TestE2EQRGenerationURL(t *testing.T) {
	testCases := []struct {
		name string
		url  string
	}{
		{"HTTP URL", "http://example.com"},
		{"HTTPS URL", "https://www.google.com"},
		{"URL with path", "https://github.com/user/repo"},
		{"URL with query", "https://example.com/search?q=test"},
		{"Complex URL", "https://api.example.com/v1/users?id=123&format=json"},
		{"URL with fragment", "https://example.com/page#section"},
		{"URL with port", "http://localhost:8080/api"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			reqURL := fmt.Sprintf("%s/api/v1/qr/generate?text=%s", baseURL, url.QueryEscape(tc.url))
			resp, err := client.Post(reqURL, "", nil)
			if err != nil {
				t.Fatalf("Failed to make QR generation request: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				t.Errorf("Expected status %d, got %d", http.StatusOK, resp.StatusCode)
			}

			contentType := resp.Header.Get("Content-Type")
			if contentType != "image/png" {
				t.Errorf("Expected image/png content type, got %s", contentType)
			}

			body, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatalf("Failed to read response body: %v", err)
			}

			if len(body) == 0 {
				t.Error("Expected image data, got empty response")
			}

			t.Logf("✅ Generated QR code for URL '%s' (%d bytes)", tc.url, len(body))
		})
	}
}

// TestE2EBadRoutes tests non-existent routes
func TestE2EBadRoutes(t *testing.T) {
	testCases := []struct {
		name   string
		path   string
		method string
		expect int
	}{
		{"Non-existent API", "/api/v1/nonexistent", "GET", http.StatusNotFound},
		{"Wrong API version", "/api/v2/qr/generate", "POST", http.StatusNotFound},
		{"Missing qr path", "/api/v1/generate", "POST", http.StatusNotFound},
		{"Extra path segments", "/api/v1/qr/generate/extra", "POST", http.StatusNotFound},
		{"Wrong case", "/API/V1/QR/GENERATE", "POST", http.StatusNotFound},
		{"Missing api prefix", "/v1/qr/generate", "POST", http.StatusNotFound},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req, err := http.NewRequest(tc.method, baseURL+tc.path, nil)
			if err != nil {
				t.Fatalf("Failed to create request: %v", err)
			}

			resp, err := client.Do(req)
			if err != nil {
				t.Fatalf("Failed to make request: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != tc.expect {
				t.Errorf("Expected status %d, got %d", tc.expect, resp.StatusCode)
			}

			t.Logf("✅ Bad route '%s %s' correctly returned status %d", tc.method, tc.path, resp.StatusCode)
		})
	}
}

// TestE2ERootPath tests the root path behavior
func TestE2ERootPath(t *testing.T) {
	resp, err := client.Get(baseURL + "/")
	if err != nil {
		t.Fatalf("Failed to make request to root path: %v", err)
	}
	defer resp.Body.Close()

	// Root path should return 200 with info message
	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected status %d for root path, got %d", http.StatusOK, resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("Failed to read response body: %v", err)
	}

	bodyStr := string(body)
	if !strings.Contains(bodyStr, "QR Code Generator") {
		t.Errorf("Expected root path to contain 'QR Code Generator', got: %s", bodyStr)
	}

	t.Logf("✅ Root path test passed: %s", bodyStr)
}

// TestE2EBadMethods tests incorrect HTTP methods
func TestE2EBadMethods(t *testing.T) {
	testCases := []struct {
		name   string
		path   string
		method string
	}{
		{"GET on generate endpoint", "/api/v1/qr/generate", "GET"},
		{"PUT on generate endpoint", "/api/v1/qr/generate", "PUT"},
		{"DELETE on generate endpoint", "/api/v1/qr/generate", "DELETE"},
		{"PATCH on generate endpoint", "/api/v1/qr/generate", "PATCH"},
		{"HEAD on generate endpoint", "/api/v1/qr/generate", "HEAD"},

	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req, err := http.NewRequest(tc.method, baseURL+tc.path, nil)
			if err != nil {
				t.Fatalf("Failed to create request: %v", err)
			}

			resp, err := client.Do(req)
			if err != nil {
				t.Fatalf("Failed to make request: %v", err)
			}
			defer resp.Body.Close()

			// Should return Method Not Allowed (405) for wrong methods
			if resp.StatusCode != http.StatusMethodNotAllowed {
				t.Errorf("Expected status %d, got %d", http.StatusMethodNotAllowed, resp.StatusCode)
			}

			t.Logf("✅ Bad method '%s %s' correctly returned status %d", tc.method, tc.path, resp.StatusCode)
		})
	}
}

// TestE2EQRGenerationMissingParameter tests requests without required parameters
func TestE2EQRGenerationMissingParameter(t *testing.T) {
	testCases := []struct {
		name string
		url  string
	}{
		{"No parameters", "/api/v1/qr/generate"},
		{"Wrong parameter name", "/api/v1/qr/generate?content=hello"},
		{"Multiple wrong parameters", "/api/v1/qr/generate?data=hello&content=world"},
		{"Empty parameter value", "/api/v1/qr/generate?text="},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			resp, err := client.Post(baseURL+tc.url, "", nil)
			if err != nil {
				t.Fatalf("Failed to make request: %v", err)
			}
			defer resp.Body.Close()

			// Should return Bad Request (400) for missing/invalid parameters
			if resp.StatusCode != http.StatusBadRequest {
				t.Errorf("Expected status %d, got %d", http.StatusBadRequest, resp.StatusCode)
			}

			t.Logf("✅ Missing parameter test '%s' correctly returned status %d", tc.url, resp.StatusCode)
		})
	}
}

// TestE2EServiceAvailability tests that the service is responsive under load
func TestE2EServiceAvailability(t *testing.T) {
	// Test service responsiveness under multiple concurrent requests
	const numRequests = 10
	results := make(chan error, numRequests)

	for i := 0; i < numRequests; i++ {
		go func(id int) {
			text := fmt.Sprintf("concurrent-test-%d", id)
			requestURL := fmt.Sprintf("%s/api/v1/qr/generate?text=%s", baseURL, url.QueryEscape(text))
			resp, err := client.Post(requestURL, "", nil)
			if err != nil {
				results <- fmt.Errorf("request %d failed: %v", id, err)
				return
			}
			resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				results <- fmt.Errorf("request %d returned status %d", id, resp.StatusCode)
				return
			}

			results <- nil
		}(i)
	}

	// Collect results
	var errors []error
	for i := 0; i < numRequests; i++ {
		if err := <-results; err != nil {
			errors = append(errors, err)
		}
	}

	if len(errors) > 0 {
		t.Errorf("Concurrent request test failed with %d errors:", len(errors))
		for _, err := range errors {
			t.Errorf("  - %v", err)
		}
	} else {
		t.Logf("✅ Service handled %d concurrent requests successfully", numRequests)
	}
}

// TestE2EResponseHeaders tests that responses have correct headers
func TestE2EResponseHeaders(t *testing.T) {
	t.Run("Health endpoint headers", func(t *testing.T) {
		resp, err := client.Get(baseURL + "/health")
		if err != nil {
			t.Fatalf("Failed to make health request: %v", err)
		}
		defer resp.Body.Close()

		contentType := resp.Header.Get("Content-Type")
		if !strings.Contains(contentType, "application/json") {
			t.Errorf("Expected JSON content type for health, got %s", contentType)
		}
		t.Logf("✅ Health endpoint has correct content type: %s", contentType)
	})

	t.Run("QR generation headers", func(t *testing.T) {
		requestURL := fmt.Sprintf("%s/api/v1/qr/generate?text=%s", baseURL, url.QueryEscape("test"))
		resp, err := client.Post(requestURL, "", nil)
		if err != nil {
			t.Fatalf("Failed to make QR generation request: %v", err)
		}
		defer resp.Body.Close()

		contentType := resp.Header.Get("Content-Type")
		if contentType != "image/png" {
			t.Errorf("Expected image/png content type for QR, got %s", contentType)
		}

		// Check if Content-Disposition is set (optional but good practice)
		contentDisposition := resp.Header.Get("Content-Disposition")
		if contentDisposition != "" && !strings.Contains(contentDisposition, "filename") {
			t.Errorf("Content-Disposition header should include filename if present, got %s", contentDisposition)
		}

		t.Logf("✅ QR generation has correct content type: %s", contentType)
	})
}

// TestE2ELargeInput tests QR generation with large text input
func TestE2ELargeInput(t *testing.T) {
	// Test with increasingly large inputs
	testCases := []struct {
		name string
		size int
	}{
		{"Medium text (500 chars)", 500},
		{"Large text (1000 chars)", 1000},
		{"Very large text (2000 chars)", 2000},
	}

		for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			text := strings.Repeat("A", tc.size)
			requestURL := fmt.Sprintf("%s/api/v1/qr/generate?text=%s", baseURL, url.QueryEscape(text))

			resp, err := client.Post(requestURL, "", nil)
			if err != nil {
				t.Fatalf("Failed to make request with %d chars: %v", tc.size, err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				t.Errorf("Expected status 200 for %d chars, got %d", tc.size, resp.StatusCode)
			}

			body, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatalf("Failed to read response: %v", err)
			}

			if len(body) == 0 {
				t.Error("Expected image data for large input")
			}

			t.Logf("✅ Generated QR for %d character input (%d bytes)", tc.size, len(body))
		})
	}
}