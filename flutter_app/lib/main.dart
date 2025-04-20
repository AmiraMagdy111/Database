import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'services/api_service.dart';
import 'models/sensor_data.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SensorMonitorPage(),
    );
  }
}

class SensorMonitorPage extends StatefulWidget {
  @override
  _SensorMonitorPageState createState() => _SensorMonitorPageState();
}

class _SensorMonitorPageState extends State<SensorMonitorPage> {
  final ApiService _apiService = ApiService(
    baseUrl:
        'http://<raspberry-pi-ip>:5000', // Replace with your Raspberry Pi's IP
  );
  List<String> _sensors = [];
  String? _selectedSensor;
  List<SensorData> _sensorData = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    try {
      final isHealthy = await _apiService.checkHealth();
      if (isHealthy) {
        _loadSensors();
      } else {
        setState(() {
          _error = 'Server is not responding';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSensors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sensors = await _apiService.getSensors();
      setState(() {
        _sensors = sensors;
        if (sensors.isNotEmpty) {
          _selectedSensor = sensors.first;
          _loadSensorData();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load sensors: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSensorData() async {
    if (_selectedSensor == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getSensorData(
        _selectedSensor!,
        startTime: _startDate,
        endTime: _endDate,
      );
      setState(() => _sensorData = data);
    } catch (e) {
      setState(() {
        _error = 'Failed to load sensor data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSensorData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sensor Monitor'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSensorData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkConnection,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedSensor,
                              isExpanded: true,
                              hint: Text('Select Sensor'),
                              items: _sensors.map((String sensor) {
                                return DropdownMenuItem<String>(
                                  value: sensor,
                                  child: Text(sensor),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedSensor = newValue;
                                  _loadSensorData();
                                });
                              },
                            ),
                          ),
                          if (_startDate != null && _endDate != null)
                            Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text(
                                '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _sensorData.isEmpty
                          ? Center(child: Text('No data available'))
                          : LineChart(
                              LineChartData(
                                gridData: FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() >= 0 &&
                                            value.toInt() <
                                                _sensorData.length) {
                                          return Text(
                                            DateFormat('HH:mm').format(
                                                _sensorData[value.toInt()]
                                                    .time),
                                            style: TextStyle(fontSize: 10),
                                          );
                                        }
                                        return Text('');
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _sensorData
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      return FlSpot(
                                        entry.key.toDouble(),
                                        entry.value.gas,
                                      );
                                    }).toList(),
                                    isCurved: true,
                                    color: Colors.blue,
                                    dotData: FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _sensorData.length,
                        itemBuilder: (context, index) {
                          final data = _sensorData[index];
                          return ListTile(
                            title: Text(
                                'Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(data.time)}'),
                            subtitle: Text(
                                'Gas: ${data.gas.toStringAsFixed(2)}, Fire: ${data.fire}'),
                            trailing: Icon(
                              data.fire == 1
                                  ? Icons.warning
                                  : Icons.check_circle,
                              color: data.fire == 1 ? Colors.red : Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
