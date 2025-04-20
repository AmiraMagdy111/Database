# Raspberry Pi Sensor Data Processor

This application reads sensor data from a file and stores it in an SQLite database. It also provides a REST API to access the data.

## Setup

1. Install Python 3.x if not already installed
2. Install required packages:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

1. Place your sensor data file in the project directory
2. Run the data processor:
   ```bash
   python src/data_processor.py
   ```
3. Start the API server:
   ```bash
   python src/api.py
   ```

The API will be available at `http://<raspberry-pi-ip>:5000`

## API Endpoints

- `GET /api/sensors` - Get list of all sensor IDs
- `GET /api/sensor/<sensor_id>` - Get data for a specific sensor

## Data Format

The input file should contain JSON data in the following format:
```json
{"id": "sensor1", "gas": 0.5, "fire": 0}
```

## Database Structure

- Each sensor has its own table named `sensor_<id>`
- Tables contain columns: time (TIMESTAMP), gas (REAL), fire (INTEGER) 