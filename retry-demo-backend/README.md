# Retry demo backend
This is simple app to test retry and circuit breaker wg. with service mesh. It accepts two arguments:

- failRate - probability of this service to fail from 1-99
- mode - busy or crash - crash mode fails by freezing for 2 seconds and exiting proces, busy immediately respond with 503 error code

Published to Docker hub as tkubica/retry-backend