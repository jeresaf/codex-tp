#!/usr/bin/env bash
set -euo pipefail

# Governance, workflows, incidents, and compliance bootstrap writer.
# Run inside the existing trading-platform repo root.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  sql \
  packages/shared-governance/shared_governance \
  apps/workflow-service/app/{api/routes,db,domain} \
  apps/compliance-service/app/{api/routes,db,domain}

cat > sql/012_governance_workflows.sql <<'EOF'
CREATE TABLE IF NOT EXISTS workflows (
    id UUID PRIMARY KEY,
    workflow_code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    scope_type VARCHAR(50) NOT NULL,
    definition_json JSONB NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workflow_runs (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL REFERENCES workflows(id),
    status VARCHAR(50) NOT NULL DEFAULT 'running',
    subject_type VARCHAR(50) NOT NULL,
    subject_id UUID NOT NULL,
    context_json JSONB,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workflow_tasks (
    id UUID PRIMARY KEY,
    workflow_run_id UUID NOT NULL REFERENCES workflow_runs(id),
    task_type VARCHAR(100) NOT NULL,
    assignee_type VARCHAR(50),
    assignee_id UUID,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    input_json JSONB,
    output_json JSONB,
    due_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY,
    incident_code VARCHAR(100),
    severity VARCHAR(20) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    title VARCHAR(255) NOT NULL,
    description TEXT,
    source_type VARCHAR(50),
    source_id UUID,
    correlation_id UUID,
    detected_at TIMESTAMPTZ NOT NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incident_events (
    id UUID PRIMARY KEY,
    incident_id UUID NOT NULL REFERENCES incidents(id),
    event_type VARCHAR(100) NOT NULL,
    message TEXT,
    details_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS compliance_exports (
    id UUID PRIMARY KEY,
    export_type VARCHAR(100) NOT NULL,
    scope_type VARCHAR(50),
    scope_id UUID,
    format VARCHAR(20) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    request_json JSONB,
    result_uri TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
EOF

python - <<'PY'
from pathlib import Path
p = Path('scripts/migrate/run_all.sh')
text = p.read_text()
if 'sql/012_governance_workflows.sql' not in text:
    text = text.replace('sql/011_execution_reconciliation.sql', 'sql/011_execution_reconciliation.sql \\\n         sql/012_governance_workflows.sql')
    p.write_text(text)
PY

cat > packages/shared-governance/shared_governance/__init__.py <<'EOF'
EOF

cat > packages/shared-governance/shared_governance/workflow.py <<'EOF'
def next_tasks(definition: dict, current_state: str) -> list[dict]:
    return definition.get('transitions', {}).get(current_state, [])
EOF

create_service() {
  local svc="$1"
  mkdir -p "apps/$svc/app"
  cat > "apps/$svc/pyproject.toml" <<EOF
[project]
name = "$svc"
version = "0.1.0"
requires-python = ">=3.12"
EOF
  cat > "apps/$svc/Dockerfile" <<EOF
FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/$svc /workspace/apps/$svc
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings
ENV PYTHONPATH=/workspace/packages:/workspace/apps/$svc
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
  cat > "apps/$svc/app/config.py" <<EOF
from shared_config.settings import Settings
settings = Settings(app_name="$svc", port=8000)
EOF
  cat > "apps/$svc/app/db/session.py" <<'EOF'
from sqlalchemy.orm import Session
from shared_db.database import build_session_factory
from app.config import settings
SessionLocal = build_session_factory(settings.sqlalchemy_url)

def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF
}

create_service workflow-service
create_service compliance-service

cat > apps/workflow-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class WorkflowModel(Base):
    __tablename__ = 'workflows'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    workflow_code: Mapped[str] = mapped_column(String(100), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(String, nullable=True)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    definition_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    enabled: Mapped[bool] = mapped_column()
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class WorkflowRunModel(Base):
    __tablename__ = 'workflow_runs'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    workflow_id: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    subject_type: Mapped[str] = mapped_column(String(50), nullable=False)
    subject_id: Mapped[str] = mapped_column(String, nullable=False)
    context_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    started_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class WorkflowTaskModel(Base):
    __tablename__ = 'workflow_tasks'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    workflow_run_id: Mapped[str] = mapped_column(String, nullable=False)
    task_type: Mapped[str] = mapped_column(String(100), nullable=False)
    assignee_type: Mapped[str] = mapped_column(String(50), nullable=True)
    assignee_id: Mapped[str] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    input_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    output_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    due_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/workflow-service/app/api/routes/workflows.py <<'EOF'
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import WorkflowModel, WorkflowRunModel

router = APIRouter()

@router.post('/')
def create_workflow(payload: dict, db: Session = Depends(get_db)):
    row = WorkflowModel(id=str(uuid.uuid4()), **payload)
    db.add(row)
    db.commit()
    return {'id': row.id}

@router.post('/runs')
def start_run(payload: dict, db: Session = Depends(get_db)):
    row = WorkflowRunModel(
        id=str(uuid.uuid4()),
        workflow_id=payload['workflow_id'],
        status='running',
        subject_type=payload['subject_type'],
        subject_id=payload['subject_id'],
        context_json=payload.get('context_json'),
        started_at=datetime.now(timezone.utc),
    )
    db.add(row)
    db.commit()
    return {'id': row.id}
EOF

cat > apps/workflow-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.workflows import router as workflows_router

app = FastAPI(title='workflow-service', version='0.1.0')
app.include_router(workflows_router, prefix='/api/workflows', tags=['workflows'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok'}
EOF

cat > apps/compliance-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class ComplianceExportModel(Base):
    __tablename__ = 'compliance_exports'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    export_type: Mapped[str] = mapped_column(String(100), nullable=False)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=True)
    scope_id: Mapped[str] = mapped_column(String, nullable=True)
    format: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    request_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    result_uri: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    completed_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
EOF

cat > apps/compliance-service/app/api/routes/compliance.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import ComplianceExportModel

router = APIRouter()

@router.post('/exports')
def create_export(payload: dict, db: Session = Depends(get_db)):
    row = ComplianceExportModel(id=str(uuid.uuid4()), status='pending', **payload)
    db.add(row)
    db.commit()
    return {'id': row.id}

@router.get('/exports')
def list_exports(db: Session = Depends(get_db)):
    rows = db.query(ComplianceExportModel).order_by(ComplianceExportModel.created_at.desc()).all()
    return [{'id': x.id, 'export_type': x.export_type, 'status': x.status} for x in rows]
EOF

cat > apps/compliance-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.compliance import router as compliance_router

app = FastAPI(title='compliance-service', version='0.1.0')
app.include_router(compliance_router, prefix='/api/compliance', tags=['compliance'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok'}
EOF

python - <<'PY'
from pathlib import Path
p = Path('docker-compose.yml')
text = p.read_text()
add = '''

  workflow-service:
    build: ./apps/workflow-service
    ports: ["8019:8000"]
    depends_on: [postgres]

  compliance-service:
    build: ./apps/compliance-service
    ports: ["8020:8000"]
    depends_on: [postgres]
'''
if 'workflow-service:' not in text:
    text += add
    p.write_text(text)
PY

echo "Governance, workflows, incidents, and compliance bootstrap applied."
