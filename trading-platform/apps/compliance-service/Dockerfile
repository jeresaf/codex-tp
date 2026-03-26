FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/compliance-service /workspace/apps/compliance-service
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings
ENV PYTHONPATH=/workspace/packages:/workspace/apps/compliance-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
