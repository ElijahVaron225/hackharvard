#!/bin/bash
source .env

SERIALIZE="37153d45ce264f758ad033ed68fe6a5e"
MODEL_URL="https://kiri-enterprise.s3.us-east-2.amazonaws.com/37153d45ce264f758ad033ed68fe6a5e/output/37153d45ce264f758ad033ed68fe6a5e.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20251005T022232Z&X-Amz-SignedHeaders=host&X-Amz-Expires=3600&X-Amz-Credential=AKIA2XTZMUSZZH6GTSV5%2F20251005%2Fus-east-2%2Fs3%2Faws4_request&X-Amz-Signature=a41b9a39add6a7bc452697c2e43870c030b75c82977f296ecaf0c348ed1242bb"

echo "Downloading model zip..."
curl -o "${SERIALIZE}.zip" "$MODEL_URL"

echo "Extracting USDZ from zip..."
unzip -j "${SERIALIZE}.zip" "*.usdz" -d .

# Find the extracted USDZ file
USDZ_FILE=$(ls *.usdz | head -1)
echo "Found USDZ file: $USDZ_FILE"

if [ -n "$USDZ_FILE" ]; then
    echo "USDZ file extracted successfully: $USDZ_FILE"
    echo "File size: $(ls -lh $USDZ_FILE | awk '{print $5}')"
else
    echo "No USDZ file found in the zip!"
    exit 1
fi

echo "Cleaning up zip file..."
rm "${SERIALIZE}.zip"

echo "✅ USDZ file ready for upload to Supabase!"
echo "File: $USDZ_FILE"
