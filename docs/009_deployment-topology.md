# 1. Environments
- dev
- qa
- paper
- live

# 2. Suggested infrastructure layout

## Edge
- reverse proxy / ingress
- WAF later
- API gateway

## Application cluster
- web-ui
- gateway-service
- admin APIs
- reporting APIs

## Runtime cluster
- strategy-runtime-service
- feature-service
- risk-service
- order-service
- execution-service

## Data cluster
- PostgreSQL primary/replica
- TimescaleDB or ClickHouse
- Redis
- Kafka/Redpanda
- object storage

## Observability cluster
- Prometheus
- Grafana
- Loki or ELK
- OpenTelemetry collector
- alert manager

## Secrets/security
- Vault or equivalent
- certificate manager
- key rotation jobs

# 3. Minimum production topology

Internet / Internal Users
│
▼
Ingress / Gateway
│
▼
App Services
├─ Identity
├─ Config
├─ Workflow
├─ Reporting
└─ Admin APIs
Runtime Services
├─ Market Data
├─ Feature
├─ Strategy Runtime
├─ Portfolio
├─ Risk
├─ Order
├─ Execution
└─ Broker Adapters
Data Services
├─ PostgreSQL
├─ Kafka/Redpanda
├─ Redis
├─ Timeseries DB
└─ Object Storage