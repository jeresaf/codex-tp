FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/order-service /workspace/apps/order-service
COPY sql /workspace/sql
COPY seeds /workspace/seeds
COPY scripts /workspace/scripts
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings passlib[bcrypt] email-validator httpx pyjwt
ENV PYTHONPATH=/workspace/packages:/workspace/apps/order-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
