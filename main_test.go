package main

import (
	"testing"
)

func TestQRCodeGenerator_GenerateQRCodeBytes(t *testing.T) {
	qrGen := &QRCodeGenerator{}

	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{
			name:    "valid URL",
			input:   "https://example.com",
			wantErr: false,
		},
		{
			name:    "valid text",
			input:   "Hello World",
			wantErr: false,
		},
		{
			name:    "empty string",
			input:   "",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := qrGen.GenerateQRCodeBytes(tt.input)

			if tt.wantErr {
				if err == nil {
					t.Errorf("GenerateQRCodeBytes() expected error but got none")
				}
				return
			}

			if err != nil {
				t.Errorf("GenerateQRCodeBytes() unexpected error: %v", err)
				return
			}

			if len(result) == 0 {
				t.Errorf("GenerateQRCodeBytes() returned empty result")
				return
			}

			// Check PNG header (first 8 bytes should be PNG signature)
			pngSignature := []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}
			if len(result) < 8 {
				t.Errorf("GenerateQRCodeBytes() result too short to be PNG")
				return
			}

			for i, b := range pngSignature {
				if result[i] != b {
					t.Errorf("GenerateQRCodeBytes() invalid PNG signature at byte %d: got %x, want %x", i, result[i], b)
					return
				}
			}
		})
	}
}
