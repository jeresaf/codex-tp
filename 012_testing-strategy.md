# 1. Test layers

## Unit tests
- pricing math
- position math
- risk rule evaluation
- order state transitions
- symbol mapping
- indicator generation

## Integration tests
- broker adapter requests/responses
- order pipeline
- fill ingestion
- reconciliation flows
- audit event creation

## Scenario tests
- stale market feed
- broker disconnect
- partial fill storm
- duplicate order events
- market gap
- risk breach
- deployment rollback

## Simulation tests
- backtest determinism
- walk-forward validation
- fee/slippage stress
- data quality degradation

## UAT flows
- register strategy
- run backtest
- request promotion
- approve paper
- deploy paper
- promote to limited live
- monitor orders
- trigger kill switch
- review audit trail