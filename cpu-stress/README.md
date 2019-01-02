# cpu-stress
Simple container to test auto-scaling capabilities for example in Kubernetes.

stress.sh generate periodic single-core cpu load. Lenght of period is defined as STRESS_TIMEOUT environmental variable. In order for multiple instances to have periods of stress vs. idle synchronized, we expect the same clock in each instance and use modulo on top of number of seconds in epoch time.

# Docker hub
Container image is pushed to Docker hub as tkubica/stress:linux and tkubica/stress:windows

