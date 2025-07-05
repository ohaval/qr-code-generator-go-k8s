#!/bin/bash

# Load Test Automation Script for QR Code Generator
# Fetches ALB endpoint from EKS ingress and runs k6 load test

set -e

echo "🚀 QR Code Generator Load Test"
echo "================================="

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo "❌ k6 not found. Please install k6 first:"
    echo "   brew install k6"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Fetch ALB endpoint
echo "🔍 Fetching ALB endpoint from ingress..."
INGRESS_HOST=$(kubectl get ingress qr-generator-ingress -n qr-generator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$INGRESS_HOST" ]; then
    echo "❌ Could not fetch ingress hostname. Make sure:"
    echo "   1. You're authenticated to the EKS cluster"
    echo "   2. The ingress resource exists: kubectl get ingress -n qr-generator"
    echo "   3. The ALB has been provisioned (may take a few minutes)"
    exit 1
fi

echo "🎯 Target: http://$INGRESS_HOST"
echo "⚡ Starting load test..."
echo ""

# Run the load test
TARGET_HOST=$INGRESS_HOST k6 run "$(dirname "$0")/load-test.js"

echo ""
echo "✅ Load test completed!"
echo "📊 Check the results above for performance metrics"