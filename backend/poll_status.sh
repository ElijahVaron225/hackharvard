#!/bin/bash
source .env
SERIALIZE="37153d45ce264f758ad033ed68fe6a5e"

echo "Polling status for serialize: $SERIALIZE"
echo "Press Ctrl+C to stop polling"

while true; do
    echo "Checking status at $(date)..."
    RESPONSE=$(curl -s --location --request GET "https://api.kiriengine.app/api/v1/open/model/getStatus?serialize=$SERIALIZE" \
    --header "Authorization: Bearer $KIRI_ENGINE_KEY")
    
    echo "Response: $RESPONSE"
    
    # Check if status is final (1=Failed, 2=Successful, 4=Expired)
    STATUS=$(echo $RESPONSE | grep -o '"status":[0-9]*' | grep -o '[0-9]*')
    
    if [ "$STATUS" = "1" ]; then
        echo "❌ Job FAILED"
        break
    elif [ "$STATUS" = "2" ]; then
        echo "✅ Job SUCCESSFUL - Ready to download!"
        break
    elif [ "$STATUS" = "4" ]; then
        echo "⏰ Job EXPIRED"
        break
    else
        echo "⏳ Still processing (status: $STATUS), waiting 30 seconds..."
        sleep 30
    fi
done
