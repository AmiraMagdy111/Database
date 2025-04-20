from flask import Flask, jsonify, request
from flask_cors import CORS
from data_processor import DataProcessor
import pyodbc
from datetime import datetime, timedelta
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Initialize the data processor with your SQL Server credentials
try:
    processor = DataProcessor(
        server='localhost',  # Replace with your SQL Server instance
        database='SensorData',
        username='sa',       # Replace with your SQL Server username
        password='your_password'  # Replace with your SQL Server password
    )
    logger.info("Successfully initialized DataProcessor")
except Exception as e:
    logger.error(f"Failed to initialize DataProcessor: {str(e)}")
    raise

@app.errorhandler(Exception)
def handle_error(e):
    """Global error handler"""
    logger.error(f"An error occurred: {str(e)}")
    return jsonify({"error": "An internal server error occurred"}), 500

@app.route('/api/sensors', methods=['GET'])
def get_sensors():
    """Get list of all sensor IDs"""
    try:
        with processor.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM sensor_ids ORDER BY created_at DESC")
            sensors = [row[0] for row in cursor.fetchall()]
            return jsonify({"sensors": sensors})
    except pyodbc.Error as e:
        logger.error(f"Database error in get_sensors: {str(e)}")
        return jsonify({"error": "Database error occurred"}), 500
    except Exception as e:
        logger.error(f"Error in get_sensors: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/sensor/<sensor_id>', methods=['GET'])
def get_sensor_data(sensor_id):
    """Get data for a specific sensor"""
    try:
        with processor.get_connection() as conn:
            cursor = conn.cursor()
            
            # First check if sensor exists
            cursor.execute("SELECT id FROM sensor_ids WHERE id = ?", (sensor_id,))
            if not cursor.fetchone():
                return jsonify({"error": f"Sensor {sensor_id} not found"}), 404

            # Get time range from query parameters
            start_time = request.args.get('start_time')
            end_time = request.args.get('end_time')
            
            table_name = f"sensor_{sensor_id}"
            query = f"SELECT time, gas, fire FROM {table_name}"
            params = []
            
            if start_time and end_time:
                query += " WHERE time BETWEEN ? AND ?"
                params.extend([start_time, end_time])
            elif start_time:
                query += " WHERE time >= ?"
                params.append(start_time)
            elif end_time:
                query += " WHERE time <= ?"
                params.append(end_time)
                
            query += " ORDER BY time DESC LIMIT 100"
            
            cursor.execute(query, params)
            data = [{"time": row[0].isoformat(), "gas": row[1], "fire": row[2]} for row in cursor.fetchall()]
            return jsonify({"sensor_id": sensor_id, "data": data})
    except pyodbc.Error as e:
        logger.error(f"Database error in get_sensor_data: {str(e)}")
        return jsonify({"error": "Database error occurred"}), 500
    except Exception as e:
        logger.error(f"Error in get_sensor_data: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        with processor.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            return jsonify({"status": "healthy"})
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({"status": "unhealthy", "error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) 