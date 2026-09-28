# ───────────────────────────────────────────────────────────────
# CP2 — Dockerfile production-ready (multi-stage, non-root, gọn)
# ───────────────────────────────────────────────────────────────

# Stage 1: builder — cài dependency vào venv riêng
FROM python:3.11-slim AS builder

WORKDIR /app

# COPY requirements.txt trước source để tận dụng Docker layer cache:
# sửa code không phải cài lại thư viện
COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# Stage 2: runtime — chỉ mang venv + code, không mang compiler/pip cache
FROM python:3.11-slim

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Tạo user thường — container chạy root = lỗ hổng leo thang quyền
RUN useradd --create-home appuser

COPY . .

USER appuser

EXPOSE 8000

# Cloud tự gán cổng qua biến PORT — không cố định 8000.
# Dùng python urllib thay vì curl để khỏi cài thêm package vào image
ENV PORT=8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import os,urllib.request;urllib.request.urlopen(f'http://localhost:{os.environ.get(\"PORT\",\"8000\")}/health', timeout=4)"]

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
