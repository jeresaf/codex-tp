# 1. Goal
Add a governance layer for:
- who may do what
- who must approve what
- how changes move to live
- how exceptions are granted
- how incidents are managed
- how audits are reviewed
- how compliance evidence is produced
This pack makes the platform manageable across:
- quants
- developers
- traders
- ops
- risk officers
- compliance
- auditors
- executives

# 2. Core principle
No meaningful production change should happen without traceable workflow.
The platform should operate like this:

```
Research Artifact
-> Validation
-> Approval Request
-> Risk Review
-> Compliance / Ops Review where needed
-> Deployment Approval
-> Controlled Production Action
```

Not like this:

```
Developer uploads strategy
-> goes live immediately
```

# 3. Governance domains added

## 3.1 Strategy promotion governance
Controls:
- when a strategy version is promotable
- who approves paper/live promotion
- required evidence
- rollback target

## 3.2 Deployment governance
Controls:
- deployment requests
- paper/live/shadow approvals
- account assignment approval
- runtime mode approval
- pause/resume/stop authority

## 3.3 Change management
Controls:
- config changes
- risk policy changes
- execution policy changes
- venue/account changes
- feature definition changes
- data source changes

## 3.4 Exception governance
Controls:
- temporary policy override
- approved breach suppression
- temporary live enablement
- emergency actions with retrospective review

## 3.5 Incident governance
Controls:
- incident creation
- acknowledgment
- assignee
- resolution notes
- postmortem workflow
- action items

## 3.6 Compliance and audit governance
Controls:
- audit evidence export
- resource timelines
- approval history
- who approved what and why

# 4. Role model refinement
The earlier RBAC model now needs operational meaning.

## Core roles

### Super Admin
Platform-wide control, rarely used operationally.

### Platform Admin
Users, connectors, environment config, system administration.

### Quant Researcher
Research, experiments, backtests, no live change authority alone.

### Strategy Developer
Registers strategy versions, proposes deployments, no unilateral live promotion.

### Operations / Trader
Monitors live systems, handles routine ops actions, limited operational controls.

### Risk Officer
Approves live promotions, risk policy changes, kill switches, exceptions.

### Compliance Officer
Reviews governance trail, exceptions, compliance exports, incident records.

### Executive Viewer
Read-only reporting.

### Auditor
Read-only access to governed history and evidence packs.

# 5. Maker-checker model
This should be enforced for sensitive actions.

## 5.1 Principle
The person proposing a sensitive change should not be the sole approver of that change.

## 5.2 Actions requiring maker-checker
At minimum:
- promote strategy to live
- edit live risk policies
- edit execution policies
- enable live broker account
- release kill switch on halted live scope
- approve exception override
- delete or archive critical governance records where allowed

## 5.3 First implementation rule
If `created_by == approver`, reject approval for sensitive workflow types unless emergency mode applies.

# 6. Workflow engine model
You need a generic workflow model, not separate ad hoc approval logic everywhere.

## 6.1 Workflow request types
Support:
- strategy_version_promotion
- deployment_request
- risk_policy_change
- execution_policy_change
- kill_switch_release
- exception_request
- incident_resolution_approval
- config_change_request

## 6.2 Workflow states
Use:
- draft
- submitted
- in_review
- approved
- rejected
- cancelled
- superseded
- executed
- expired

## 6.3 Workflow steps
Each workflow can have steps like:
- research review
- ops review
- risk review
- compliance review
- final approval
- execution
Not every type needs every step.

# 7. Strategy promotion workflow
This is one of the most important workflows.

## 7.1 Promotion path
Use:

```
draft
-> backtest reviewed
-> paper approved
-> shadow approved
-> limited live approved
-> full live approved
-> deprecated
-> archived
```

## 7.2 Required evidence for promotion
At minimum:
- strategy version metadata
- backtest summary
- dataset versions used
- feature versions used
- paper trading observations
- risk notes
- expected live scope
- rollback plan

## 7.3 Promotion checks
Before allowing limited live:
- strategy version approved
- no unresolved critical incident on dependent systems
- live account available
- risk policies configured
- deployment scope defined
- responsible owner assigned

# 8. Deployment approval workflow
Deployment should be separate from strategy version approval.

## 8.1 Why
A strategy version may be approved generally, but a specific deployment still needs approval for:
- account
- market scope
- instrument scope
- capital budget
- runtime mode
- time window

## 8.2 Deployment workflow example

```
draft request
-> strategy owner submit
-> ops review
-> risk review
-> approve paper/shadow/live
-> runtime supervisor executes
```

## 8.3 Deployment actions requiring workflow
- create live deployment
- change capital budget on live deployment
- change instrument scope on live deployment
- change runtime mode
- restart failed live deployment after quarantine

# 9. Change management model
Production changes should be governed consistently.

## 9.1 Change categories
- strategy changes
- risk changes
- execution routing changes
- market data source changes
- feature definition changes
- config changes
- permission model changes

## 9.2 Change request fields
Store:
- change id
- change type
- requested by
- resource type
- resource id
- before snapshot
- proposed after snapshot
- reason
- impact assessment
- rollback procedure
- approvals
- execution status

## 9.3 Change execution
Approved changes should be:
- applied by workflow engine or controlled service action
- audited
- linked to resource history

# 10. Exception approval model
There will be times when controlled exceptions are needed.

## Examples
- temporarily raise max position size for a test
- temporarily suppress a warning breach
- temporarily allow a deployment restart after repeated failures
- temporarily enable trading in a blocked market under supervision

## Rules
Exceptions must always have:
- scope
- reason
- requester
- approver
- start time
- expiry time
- explicit conditions
- automatic expiry
Never allow indefinite exceptions by default.

# 11. Kill-switch governance
Triggering a kill switch may be immediate. Releasing it should be controlled.

## 11.1 Trigger rules
Can be triggered by:
- risk officer
- ops under defined rules
- automated critical rule

## 11.2 Release rules
Release should require:
- reason recorded
- checks completed
- approval by authorized role
- maker-checker on high-impact scopes

## 11.3 Release workflow

```
kill switch active
-> release request submitted
-> risk review
-> ops review if needed
-> approved
-> released
```

# 12. Incident workflow model
Incidents should not just exist as records. They need lifecycle.

## 12.1 Incident states
Use:
- open
- acknowledged
- investigating
- mitigated
- resolved
- closed
- postmortem_required
- postmortem_completed

## 12.2 Incident fields
Store:
- severity
- source
- affected scope
- detected by
- assigned owner
- timeline
- mitigation actions
- root cause summary
- recovery actions
- linked breaches/issues/workflows

## 12.3 Severity levels
- sev4 info
- sev3 minor
- sev2 major
- sev1 critical

## 12.4 Required behavior
- sev1 and sev2 require acknowledgment
- sev1 may auto-trigger kill switch or venue halt depending on policy
- resolved major incidents should require closure notes

# 13. Postmortem and corrective action workflow
For serious incidents, require a postmortem.

## Postmortem should include
- summary
- impact
- timeline
- root cause
- contributing factors
- what detection worked or failed
- what controls worked or failed
- corrective actions
- owners
- due dates

## Corrective actions
Track action items as governed tasks, not just free text.

# 14. Compliance export model
The platform should be able to produce evidence packages.

## 14.1 Export types
Support:
- strategy approval history
- deployment history
- order lifecycle history
- incident package
- breach package
- kill-switch package
- reconciliation evidence
- user activity report
- change history report

## 14.2 Export format
At first:
- JSON + CSV + PDF summary later
- zipped evidence pack later

## 14.3 Each export should include
- scope filters
- date range
- generated by
- generated at
- included record counts
- checksum if needed

# 15. Audit timeline by resource
A very useful enterprise feature is a unified timeline per resource.

## Resources needing timelines
- strategy version
- deployment
- order intent
- broker order
- risk policy
- kill switch
- incident
- reconciliation issue
- user

## Timeline items can include
- state changes
- approvals
- audit events
- breaches
- incidents
- comments/notes
- operator actions
This becomes a major UI and compliance feature.

# 16. Database additions

## Create sql/012_governance_workflows.sql.

```SQL
CREATE TABLE IF NOT EXISTS workflow_requests (
    id UUID PRIMARY KEY,
    workflow_type VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id UUID,
    requested_by UUID NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    reason TEXT,
    payload_json JSONB,
    expires_at TIMESTAMPTZ,
    correlation_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workflow_steps (
    id UUID PRIMARY KEY,
    workflow_request_id UUID NOT NULL REFERENCES workflow_requests(id),
    step_code VARCHAR(100) NOT NULL,
    step_order INT NOT NULL,
    reviewer_role_code VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    acted_by UUID,
    acted_at TIMESTAMPTZ,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS approvals (
    id UUID PRIMARY KEY,
    workflow_request_id UUID NOT NULL REFERENCES workflow_requests(id),
    approval_type VARCHAR(100) NOT NULL,
    actor_id UUID NOT NULL,
    decision VARCHAR(20) NOT NULL,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS exception_overrides (
    id UUID PRIMARY KEY,
    override_type VARCHAR(100) NOT NULL,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID,
    requested_by UUID NOT NULL,
    approved_by UUID,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    reason TEXT NOT NULL,
    conditions_json JSONB,
    starts_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY,
    severity VARCHAR(20) NOT NULL,
    source_service VARCHAR(100),
    incident_type VARCHAR(100) NOT NULL,
    affected_scope_type VARCHAR(50),
    affected_scope_id UUID,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    assigned_to UUID,
    acknowledged_by UUID,
    acknowledged_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    correlation_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incident_updates (
    id UUID PRIMARY KEY,
    incident_id UUID NOT NULL REFERENCES incidents(id),
    update_type VARCHAR(100) NOT NULL,
    actor_id UUID,
    note TEXT,
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS compliance_exports (
    id UUID PRIMARY KEY,
    export_type VARCHAR(100) NOT NULL,
    requested_by UUID NOT NULL,
    filters_json JSONB,
    status VARCHAR(50) NOT NULL DEFAULT 'queued',
    result_uri TEXT,
    record_count INT,
    checksum VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
```

# 17. Workflow service responsibilities
Your `workflow-service` should now be a central governance engine.

## Responsibilities
- create workflow templates
- create workflow requests
- enforce step order
- enforce reviewer roles
- enforce maker-checker rules
- record decisions
- emit workflow events
- trigger execution actions after final approval

## Events to emit
- `workflow.request.submitted`
- `workflow.step.approved`
- `workflow.step.rejected`
- `workflow.request.approved`
- `workflow.request.rejected`
- `workflow.request.executed`

# 18. Governance event topics
Add these topics:
- `workflow.request.submitted`
- `workflow.request.approved`
- `workflow.request.rejected`
- `exception.override.approved`
- `incident.opened`
- `incident.acknowledged`
- `incident.resolved`
- `compliance.export.completed`
These should feed:
- audit-service
- notification-service
- UI read models
- reporting exports

# 19. UI additions for admin
Add pages for:
- workflow inbox
- workflow detail
- approvals queue
- exceptions
- incidents
- compliance exports
- resource timelines

## Workflow inbox
Show:
- pending requests for my role
- status
- requester
- resource
- age
- severity/impact flag if available

## Workflow detail page
Show:
- request metadata
- resource snapshot
- proposed changes
- evidence attachments/links
- step-by-step approval path
- comments
- approve/reject actions

# 20. UI additions for ops
Add pages for:
- active incidents
- incident detail
- active exceptions
- pending operational approvals
- kill-switch release requests
- deployment approval queue
This gives operations a real control center.

# 21. Strategy promotion UI flow
A practical admin flow should be:
1. open strategy version
2. view evidence
3. click “request paper promotion”
4. workflow created
5. reviewer approves
6. status changes to paper-approved
7. later request shadow or live promotion
At each step, the user should see:
- who approved
- when
- comment
- linked evidence

# 22. Deployment approval UI flow
A practical deployment flow:
1. create deployment draft
2. set account, capital budget, instrument scope
3. submit approval request
4. ops review
5. risk review
6. approved deployment appears as executable
7. runtime supervisor starts it
8. deployment history records action

# 23. Compliance export workflow
A practical flow:
1. user requests export
2. request is recorded
3. export job runs
4. result stored
5. export appears in downloads/history
6. audit trail records who generated it
Good first export examples:
- all live deployments approved in last 30 days
- all kill-switch actions in date range
- order lifecycle for one strategy deployment
- all incident records for one account

# 24. Resource timeline projection model
You should build timeline projections instead of recalculating everything from raw tables every time.

## Suggested projection table
A generic timeline table with:
- resource_type
- resource_id
- event_type
- actor_id
- timestamp
- summary
- detail_json
- correlation_id
Then UI can render fast unified timelines.

# 25. Manual test scenarios
You should intentionally test governance flows.

## Scenario 1: maker-checker block
User submits sensitive workflow and tries to self-approve.
Expected:
- approval rejected by workflow rules

## Scenario 2: strategy live promotion
Create request with incomplete evidence.
Expected:
- workflow cannot move forward or reviewers reject

## Scenario 3: incident acknowledgment
Open sev2 incident.
Expected:
- appears in incident queue
- acknowledgment recorded
- assigned owner visible

## Scenario 4: exception expiry
Create temporary override.
Expected:
- active until expiry
- automatically becomes inactive after expiry

## Scenario 5: kill-switch release approval
Attempt release without proper role.
Expected:
- blocked
- audit recorded

# 26. Guardrails for this stage
Implement these rules now:
- no live promotion without workflow approval
- no sensitive approval by same actor who submitted
- all exception overrides must expire
- all incident state changes must be audited
- all workflow decisions must store comments where appropriate
- all compliance exports must be attributable to a requester
- all governance-sensitive UI actions must be backed by server-side checks

# 27. Suggested implementation order

## Stage 1
- add DB tables
- add workflow-service basic request/step models
- add approval APIs

## Stage 2
- implement maker-checker checks
- implement strategy promotion workflow
- implement deployment approval workflow

## Stage 3
- add incidents and updates
- add incident UI
- add exception overrides

## Stage 4
- add compliance export jobs
- add resource timeline projections
- add workflow inbox UI

## Stage 5
- integrate workflow execution into runtime/deployment actions
- add kill-switch release governance
- add postmortem-required flow for major incidents

# 28. What this unlocks
After this pack, the platform gains:
- team-safe operation
- traceable approvals
- proper separation of duties
- enterprise readiness for audits
- managed incident handling
- controlled live changes
- better operator accountability
This is what makes the platform governable in an organization.

# 29. What should come next
The next correct step is:

## Volume 13: observability, telemetry, SRE, and platform operations pack
That should add:
- metrics and alerts
- distributed tracing
- structured logs
- platform health dashboards
- consumer lag monitoring
- outbox backlog monitoring
- feed health dashboards
- deployment/runtime telemetry
- SLOs and runbooks
- backup/restore and disaster recovery readiness
That is the layer that makes the whole platform operationally supportable at scale.

This is the layer that determines whether your system can **run continuously, safely, and at scale**. At this stage, the platform is already powerful—but without observability and operational discipline, failures will be invisible, slow to diagnose, or catastrophic.
This pack turns your system into something that can be **monitored, debugged, and operated like a real production platform**.
