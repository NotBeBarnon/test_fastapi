FROM python:3.11-slim AS builder
COPY . /MyProject
WORKDIR /MyProject
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim

WORKDIR /MyProject

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
EXPOSE 8089
CMD ["python", "main.py"]