# Contributing

## Rules
- Keep domain logic out of transport layers.
- Use shared packages for common enums, schemas, math, and contracts.
- Every sensitive mutation must be auditable.
- Every event must include correlation metadata.
- Every service must expose health and readiness endpoints.
