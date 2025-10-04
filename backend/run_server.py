#!/usr/bin/env python3
import sys
import os
from pathlib import Path

# Add src to Python path
backend_dir = Path(__file__).parent
src_dir = backend_dir / "src"
sys.path.insert(0, str(src_dir))

# Import and run
if __name__ == "__main__":
    import uvicorn
    from app.main import app
    
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0", 
        port=8000,
        reload=True,
        reload_dirs=[str(backend_dir)]
    )
