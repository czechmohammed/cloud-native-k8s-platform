#!/bin/bash

FRONTEND_IP=$(kubectl get service frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ORDERLOG_PORT=8080

echo "Simulating orders being placed through frontend..."
echo "Frontend IP: $FRONTEND_IP"

for i in {1..5}; do
  ORDER_ID="order-$(date +%s)-$i"
  
  echo "Placing order $ORDER_ID..."
  
  # Send order to OrderLog
  kubectl exec -it $(kubectl get pod -l app=orderlog -o jsonpath='{.items[0].metadata.name}') -- \
    curl -X POST http://localhost:8080/log-order \
    -H "Content-Type: application/json" \
    -d "{
      \"order_id\": \"$ORDER_ID\",
      \"user_id\": \"user-$RANDOM\",
      \"items\": [
        {\"product\": \"Product-$i\", \"quantity\": $((RANDOM % 5 + 1)), \"price\": $((RANDOM % 100 + 10)).99}
      ],
      \"total\": $((RANDOM % 200 + 50)).99,
      \"source\": \"simulated\"
    }" 2>/dev/null
  
  echo ""
  sleep 2
done

echo "Done! Checking orders..."
kubectl exec -it $(kubectl get pod -l app=orderlog -o jsonpath='{.items[0].metadata.name}') -- \
  curl -s http://localhost:8080/orders | jq '.'
