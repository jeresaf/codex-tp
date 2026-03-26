FROM python:3.12-slim
WORKDIR /workspace
COPY . /workspace
RUN pip install --no-cache-dir fastapi uvicorn
ENV PYTHONPATH=/workspace/packages:/workspace/apps/ml-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
