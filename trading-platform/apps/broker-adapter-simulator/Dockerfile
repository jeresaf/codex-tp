FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/broker-adapter-simulator /workspace/apps/broker-adapter-simulator
COPY sql /workspace/sql
COPY seeds /workspace/seeds
COPY scripts /workspace/scripts
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings passlib[bcrypt] email-validator httpx pyjwt
ENV PYTHONPATH=/workspace/packages:/workspace/apps/broker-adapter-simulator
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
