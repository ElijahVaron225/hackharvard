# FastAPI Minimal Backend

## Quickstart
1. Copy env:
   ```bash
   cp .env.example .env
   ```

2. Install deps:
   ```bash
   pip install -r backend/requirements.txt
   ```

3. Run the server (from `backend/src`):
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

4. Open [http://localhost:8000/docs](http://localhost:8000/docs)

## Project layout

```
backend/
  requirements.txt
  .env(.example)
  src/app/...
```

Add new endpoints by creating files under `app/api/v1/endpoints/` and wiring them in `app/api/v1/router.py`.