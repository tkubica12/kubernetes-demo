#!/bin/bash
curl -X POST http://localhost:3500/v1.0/publish/orders -H "Content-Type: application/json" -d '{"orderCreated": "ABC01"}'