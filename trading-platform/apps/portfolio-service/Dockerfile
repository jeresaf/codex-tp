FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/portfolio-service /workspace/apps/portfolio-service
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings
ENV PYTHONPATH=/workspace/packages:/workspace/apps/portfolio-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
