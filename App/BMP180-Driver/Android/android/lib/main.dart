import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

class SensorData {
  final DateTime time;
  final double temperature;
  final double pressure;

  SensorData(this.time, this.temperature, this.pressure);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SensorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _loading = false;

  final List<SensorData> _history = [];

  double? temperature;
  double? pressure;
  String? prediction;
  DateTime? lastUpdated;

  Timer? _timer;

  String _extractSubdomain(String input) {
    String s = input.replaceAll(RegExp(r'^https?://'), '');
    if (s.contains('.ngrok-free.app')) {
      s = s.split('.ngrok-free.app')[0];
    }
    if (s.endsWith('/sensor')) {
      s = s.replaceAll(RegExp(r'/sensor$'), '');
    }
    return s;
  }

  Future<bool> fetchData(String variablePart) async {
    final subdomain = _extractSubdomain(variablePart);
    final urlString = 'https://$subdomain.ngrok-free.app/sensor';
    final url = Uri.parse(urlString);

    print('>>> Fetching from: $urlString');

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        setState(() {
          _error = 'Server trả về lỗi: ${res.statusCode}';
        });
        return false;
      }

      final jsonData = json.decode(res.body);
      if (jsonData['input'] == null ||
          jsonData['input']['temperature'] == null ||
          jsonData['input']['pressure'] == null ||
          jsonData['prediction'] == null) {
        setState(() {
          _error = 'Dữ liệu không hợp lệ';
        });
        return false;
      }

      final temp = (jsonData['input']['temperature'] as num).toDouble();
      final pres = (jsonData['input']['pressure'] as num).toDouble();
      final pred = jsonData['prediction'].toString();
      final now = DateTime.now();

      setState(() {
        _error = null;
        temperature = temp;
        pressure = pres;
        prediction = pred;
        lastUpdated = now;

        _history.insert(0, SensorData(now, temp, pres));
        if (_history.length > 10) _history.removeLast();
      });

      return true;
    } catch (e) {
      print('*** Exception khi fetchData: $e');
      setState(() {
        _error = 'Lỗi kết nối hoặc dữ liệu không hợp lệ';
      });
      return false;
    }
  }

  void startFetching(String rawInput) {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });

    fetchData(rawInput).then((success) {
      setState(() {
        _loading = false;
      });
      if (!success) return;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        fetchData(rawInput);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<SensorData> get chartHistory => _history.reversed.toList();

  List<FlSpot> get tempSpots => chartHistory
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.temperature))
      .toList();

  List<FlSpot> get presSpots => chartHistory
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.pressure))
      .toList();

  String formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  Widget buildChart(List<FlSpot> spots, String title, String unit) {
    if (spots.isEmpty) {
      return Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'Chưa có dữ liệu',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (var s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    final intervalY = (maxY - minY) / 3;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(enabled: true),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index < 0 || index >= chartHistory.length) {
                            return const SizedBox.shrink();
                          }
                          final dt = chartHistory[index].time;
                          final label =
                              '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                          return Text(label,
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: intervalY,
                        reservedSize: 40, 
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: (chartHistory.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: unit == '°C' ? Colors.red : Colors.blue,
                      isCurved: true,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHistoryColumn() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Text('Lịch sử 10 lần mới nhất',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDateTime(item.time),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                            'Nhiệt độ: ${item.temperature.toStringAsFixed(1)} °C'),
                        Text(
                            'Áp suất: ${item.pressure.toStringAsFixed(2)} hPa'),
                        const Divider(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lastUpdated != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Cập nhật: ${formatDateTime(lastUpdated!)}    Result: $prediction',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          buildChart(tempSpots, 'Nhiệt độ (°C)', '°C'),
          buildChart(presSpots, 'Áp suất (hPa)', 'hPa'),
          buildHistoryColumn(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Data Viewer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText:
                    'Nhập link đầy đủ hoặc phần biến động (ví dụ a5dc-2401-...-6eb)',
                hintText: 'Ví dụ: a5dc-2401-d800-f8b0-f0d6-bd2-e147-9b4f-b6eb',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isEmpty) {
                  setState(() {
                    _error = 'Vui lòng nhập giá trị';
                  });
                  return;
                }
                setState(() {
                  _error = null;
                });
                startFetching(trimmed);
              },
            ),
            const SizedBox(height: 12),
            if (_loading) const CircularProgressIndicator(),
            const SizedBox(height: 12),
            if (temperature != null && pressure != null && prediction != null)
              Expanded(child: buildMainContent()),
          ],
        ),
      ),
    );
  }
}
