# 1. Core roles

## Super Admin
Full control.

## Platform Admin
Users, configs, environments, connectors.

## Quant Researcher
Research, backtests, experiments, read-only limited live data.

## Strategy Developer
Strategy code/package registration, paper deploys, no live approval alone.

## Trader / Operations
Observe runtime, intervene on operational actions, no model promotion alone.

## Risk Officer
Manage risk policies, approve go-live, trigger kill switches.

## Compliance Officer
Read audit, review overrides, export records.

## Executive / Investor Viewer
Read reports only.

# 2. Sample permission mapping

|Permission               | Super Admin | Platform Admin | Quant | Strategy Dev | Ops | Risk | Compliance | Executive |
|-------------------------|-------------|----------------|-------|--------------|-----|------|------------|-----------|
|Manage users             | Y           | Y              | N     | N            | N   | N    | N          | N         |
|Manage venues/accounts.  | Y           | Y              | N     | N            | N   | N    | N          | N         |
|Run backtests            | Y           | N              | Y     | Y            | N   | N    | N          | N         |
|Register strategy version| Y           | N              | N     | Y            | N   | N    | N          | N         |
|Deploy to paper          | Y           | N              | N     | Y            | Y   | N    | N          | N         |
|Deploy to live           | Y           | N              | N     | N            | N   | Y    | N          | N         |
|Approve promotions       | Y           | N              | N     | N            | N   | Y    | Y          | N         |
|View live orders         | Y           | Y              | Y     | Y            | Y   | Y    | Y          | N         |
|Trigger kill switch      | Y           | N              | N     | N            | Y   | Y    | N          | N         |
|Edit risk policies       | Y           | N              | N     | N            | N   | Y    | N          | N         |
|View audit logs          | Y           | Y              | N     | N            | N   | Y    | Y          | N         |
|View executive reports   | Y           | Y              | Y     | Y            | Y   | Y    | Y          | Y         |




