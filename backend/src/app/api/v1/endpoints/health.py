from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def healthz():
    return {"status": "ok"}
