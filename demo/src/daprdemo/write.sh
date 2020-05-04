#!/bin/bash
curl -X POST http://localhost:3500/v1.0/state/mystate \
  -H "Content-Type: application/json" \
  -d '[
        {
          "key": "00-11-22",
          "value": "Tomas"
        }
      ]'