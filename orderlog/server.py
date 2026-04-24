import os
import json
import redis
from datetime import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

# Connect to Redis
REDIS_HOST = os.environ.get('REDIS_ADDR', 'redis-cart:6379').split(':')[0]
REDIS_PORT = int(os.environ.get('REDIS_ADDR', 'redis-cart:6379').split(':')[1])

redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/log-order', methods=['POST'])
def log_order():
    try:
        order_data = request.get_json()
        order_id = order_data.get('order_id', 'unknown')
        
        # Add timestamp
        order_data['timestamp'] = datetime.utcnow().isoformat()
        
        # Store in Redis with key: order:<order_id>
        redis_key = f"order:{order_id}"
        redis_client.set(redis_key, json.dumps(order_data))
        
        # Also add to a list of all orders
        redis_client.lpush("orders:all", order_id)
        
        print(f"Logged order: {order_id}")
        return jsonify({"status": "logged", "order_id": order_id}), 200
        
    except Exception as e:
        print(f"Error logging order: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/orders', methods=['GET'])
def get_orders():
    try:
        # Get last 10 order IDs
        order_ids = redis_client.lrange("orders:all", 0, 9)
        
        orders = []
        for order_id in order_ids:
            order_data = redis_client.get(f"order:{order_id}")
            if order_data:
                orders.append(json.loads(order_data))
        
        return jsonify({"orders": orders, "count": len(orders)}), 200
        
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
