# Availability
- critical runtime services should tolerate instance failure
- no single point of failure in production data path

# Performance
- low-latency order path
- bounded event processing lag
- fast dashboard refresh for operators

# Security
- MFA
- encrypted secrets
- least privilege
- environment isolation

# Auditability
- immutable order and change records
- actor attribution
- version traceability

# Scalability
- horizontal scaling for feed consumers and strategy workers
- partitioned event streams
- independent service scaling

# Maintainability
- strict service contracts
- versioned events
- clean domain separation