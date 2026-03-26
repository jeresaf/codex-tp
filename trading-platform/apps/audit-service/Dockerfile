FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/audit-service /workspace/apps/audit-service
COPY sql /workspace/sql
COPY seeds /workspace/seeds
COPY scripts /workspace/scripts
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings passlib[bcrypt] email-validator httpx pyjwt
ENV PYTHONPATH=/workspace/packages:/workspace/apps/audit-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
