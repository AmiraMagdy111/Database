import pyodbc
import time
from datetime import datetime
import json
import os
from contextlib import contextmanager

class DataProcessor:
    def __init__(self, server='localhost', database='SensorData', username='sa', password='your_password'):
        self.connection_string = (
            f'DRIVER={{ODBC Driver 17 for SQL Server}};'
            f'SERVER={server};'
            f'DATABASE={database};'
            f'UID={username};'
            f'PWD={password};'
            'TrustServerCertificate=yes;'  # For development only
            'Connection Timeout=30;'
        )
        self.conn = None
        self.cursor = None
        self.connect_db()
        self.create_tables()

    @contextmanager
    def get_connection(self):
        """Context manager for database connections"""
        conn = None
        try:
            conn = pyodbc.connect(self.connection_string)
            yield conn
        except pyodbc.Error as e:
            print(f"Database connection error: {str(e)}")
            raise
        finally:
            if conn:
                conn.close()

    def connect_db(self):
        """Connect to SQL Server database with retry logic"""
        max_retries = 3
        retry_delay = 5  # seconds

        for attempt in range(max_retries):
            try:
                self.conn = pyodbc.connect(self.connection_string)
                self.cursor = self.conn.cursor()
                print("Successfully connected to SQL Server")
                return
            except pyodbc.Error as e:
                print(f"Connection attempt {attempt + 1} failed: {str(e)}")
                if attempt < max_retries - 1:
                    print(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    raise Exception(f"Failed to connect to SQL Server after {max_retries} attempts")

    def create_tables(self):
        """Create tables for each sensor ID if they don't exist"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                
                # Create sensor_ids table
                cursor.execute('''
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'sensor_ids')
                    CREATE TABLE sensor_ids (
                        id NVARCHAR(50) PRIMARY KEY,
                        created_at DATETIME DEFAULT GETDATE()
                    )
                ''')
                
                # Create a stored procedure for creating sensor tables
                cursor.execute('''
                    IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_CreateSensorTable')
                    EXEC('
                    CREATE PROCEDURE sp_CreateSensorTable
                        @sensor_id NVARCHAR(50)
                    AS
                    BEGIN
                        DECLARE @table_name NVARCHAR(100) = ''sensor_'' + @sensor_id
                        DECLARE @sql NVARCHAR(MAX)
                        
                        IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = @table_name)
                        BEGIN
                            SET @sql = ''
                                CREATE TABLE '' + @table_name + '' (
                                    id INT IDENTITY(1,1) PRIMARY KEY,
                                    time DATETIME DEFAULT GETDATE(),
                                    gas FLOAT,
                                    fire INT,
                                    created_at DATETIME DEFAULT GETDATE()
                                )
                            ''
                            EXEC sp_executesql @sql
                        END
                    END
                    ')
                ''')
                
                conn.commit()
        except Exception as e:
            print(f"Error creating tables: {str(e)}")
            raise

    def create_sensor_table(self, sensor_id):
        """Create a table for a specific sensor ID"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                
                # Add sensor_id to sensor_ids table if not exists
                cursor.execute('''
                    IF NOT EXISTS (SELECT 1 FROM sensor_ids WHERE id = ?)
                    INSERT INTO sensor_ids (id) VALUES (?)
                ''', (sensor_id, sensor_id))
                
                # Create sensor table using stored procedure
                cursor.execute('EXEC sp_CreateSensorTable ?', (sensor_id,))
                
                conn.commit()
        except Exception as e:
            print(f"Error creating sensor table: {str(e)}")
            raise

    def process_data_file(self, file_path):
        """Read data from file and store in appropriate tables"""
        try:
            with open(file_path, 'r') as file:
                for line in file:
                    try:
                        data = json.loads(line.strip())
                        sensor_id = data.get('id')
                        if sensor_id:
                            self.create_sensor_table(sensor_id)
                            self.insert_data(sensor_id, data)
                    except json.JSONDecodeError:
                        print(f"Invalid JSON line: {line}")
                        continue
        except FileNotFoundError:
            print(f"File not found: {file_path}")
        except Exception as e:
            print(f"Error processing file: {str(e)}")
            raise

    def insert_data(self, sensor_id, data):
        """Insert data into the appropriate sensor table"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                table_name = f"sensor_{sensor_id}"
                cursor.execute(f'''
                    INSERT INTO {table_name} (gas, fire)
                    VALUES (?, ?)
                ''', (data.get('gas'), data.get('fire')))
                conn.commit()
        except Exception as e:
            print(f"Error inserting data: {str(e)}")
            raise

    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()

if __name__ == "__main__":
    # Example usage
    processor = DataProcessor(
        server='localhost',  # Replace with your SQL Server instance
        database='SensorData',
        username='sa',       # Replace with your SQL Server username
        password='your_password'  # Replace with your SQL Server password
    )
    try:
        # Replace with your actual data file path
        processor.process_data_file('sensor_data.txt')
    finally:
        processor.close() 