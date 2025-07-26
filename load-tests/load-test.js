import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '10s', target: 10 },   // Ramp up to 10 users
    { duration: '1m', target: 50 },    // Stay at 50 users
    { duration: '1m', target: 100 },   // Ramp to 100 users
    { duration: '2m', target: 100 },   // Stay at 100 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    // Overall thresholds
    'http_req_failed': ['rate<0.005'], // Less than 0.5% failures (99.5% success)

    // Health endpoint specific thresholds
    'http_req_duration{endpoint:health}': ['p(90)<200', 'p(95)<210'],
    'http_req_failed{endpoint:health}': ['rate<0.001'],

    // QR endpoint specific thresholds
    'http_req_duration{endpoint:qr}': ['p(90)<200', 'p(95)<210'],
    'http_req_failed{endpoint:qr}': ['rate<0.001'],
  },
};

export default function () {
  // Test health endpoint
  let healthRes = http.get(`http://${__ENV.TARGET_HOST}/health`, {
    tags: { endpoint: 'health' }
  });
  check(healthRes, {
    'health status is 200': (r) => r.status === 200,
  });

  // Test QR generation
  let qrRes = http.post(`http://${__ENV.TARGET_HOST}/api/v1/qr/generate?text=load-test-${__VU}-${__ITER}`, {
    tags: { endpoint: 'qr' }
  });

  // Debug QR response
  console.log(`QR Response: Status=${qrRes.status}, Duration=${qrRes.timings.duration}ms`);

  check(qrRes, {
    'QR status is 200': (r) => r.status === 200,
    'QR content-type is PNG': (r) => r.headers['Content-Type'] === 'image/png',
  });
}