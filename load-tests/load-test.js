import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp up to 10 users
    { duration: '1m', target: 50 },    // Stay at 50 users
    { duration: '1m', target: 100 },   // Ramp to 100 users
    { duration: '2m', target: 100 },   // Stay at 100 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
};

export default function () {
  // Test health endpoint
  let healthRes = http.get(`http://${__ENV.TARGET_HOST}/health`);
  check(healthRes, {
    'health status is 200': (r) => r.status === 200,
    'health response time < 200ms': (r) => r.timings.duration < 200,
  });

  // Test QR generation
  let qrRes = http.post(`http://${__ENV.TARGET_HOST}/api/v1/qr/generate?text=load-test-${__VU}-${__ITER}`);
  check(qrRes, {
    'QR status is 200': (r) => r.status === 200,
    'QR response time < 500ms': (r) => r.timings.duration < 500,
    'QR content-type is PNG': (r) => r.headers['Content-Type'] === 'image/png',
  });

  sleep(1);
}