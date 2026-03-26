#!/usr/bin/env bash
set -euo pipefail
curl -s -X POST http://localhost:8006/api/risk/kill-switches -H "Content-Type: application/json" -d '{"scope_type":"global","switch_action":"reject_new_orders","reason":"smoke_test"}'
echo
curl -s http://localhost:8006/api/risk/kill-switches
echo
curl -s http://localhost:8007/api/execution/quality-metrics
echo
curl -s -X POST http://localhost:8018/api/reconciliation/runs -H "Content-Type: application/json" -d '{"run_type":"order"}'
echo
curl -s http://localhost:8018/api/reconciliation/runs
echo
