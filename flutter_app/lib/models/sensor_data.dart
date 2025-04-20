class SensorData {
  final DateTime time;
  final double gas;
  final int fire;

  SensorData({
    required this.time,
    required this.gas,
    required this.fire,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      time: DateTime.parse(json['time']),
      gas: json['gas'].toDouble(),
      fire: json['fire'],
    );
  }
}
