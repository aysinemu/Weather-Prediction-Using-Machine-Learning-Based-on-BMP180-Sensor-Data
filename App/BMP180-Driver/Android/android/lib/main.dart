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

  Future<bool> fetchData(String variablePart) async {
    final url = Uri.parse('https://$variablePart.ngrok-free.app/sensor');

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
      setState(() {
        _error = 'Lỗi kết nối hoặc dữ liệu không hợp lệ';
      });
      return false;
    }
  }

  void startFetching(String variablePart) {
    _timer?.cancel();

    _loading = true;
    fetchData(variablePart).then((success) {
      setState(() {
        _loading = false;
      });

      if (!success) {
        return;
      }

      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        fetchData(variablePart);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<FlSpot> get tempSpots {
    return _history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.temperature))
        .toList()
        .reversed
        .toList();
  }

  List<FlSpot> get presSpots {
    return _history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.pressure))
        .toList()
        .reversed
        .toList();
  }

  String formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  Widget buildChart(List<FlSpot> spots, String title, String unit) {
    return SizedBox(
      width: 300,
      height: 200,
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
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
                            if (index < 0 || index >= _history.length) {
                              return const SizedBox.shrink();
                            }
                            final dt = _history[index].time;
                            final label = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                            return Text(label, style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, interval: 5),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    minX: 0,
                    maxX: (_history.length - 1).toDouble(),
                    minY: spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 5,
                    maxY: spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 5,
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
      ),
    );
  }

  Widget buildHistoryColumn() {
    return SizedBox(
      width: 150,
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              const Text('Lịch sử 10 lần mới nhất',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
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
                          Text('Nhiệt độ: ${item.temperature.toStringAsFixed(1)} °C'),
                          Text('Áp suất: ${item.pressure.toStringAsFixed(1)} hPa'),
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
      ),
    );
  }

  Widget buildMainContent() {
    return Column(
      children: [
        if (lastUpdated != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Cập nhật: ${formatDateTime(lastUpdated!)}    Result: $prediction',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildChart(tempSpots, 'Nhiệt độ (°C)', '°C'),
            buildChart(presSpots, 'Áp suất (hPa)', 'hPa'),
            buildHistoryColumn(),
          ],
        ),
      ],
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
                labelText: 'Nhập phần biến động trong link (ví dụ bcb3-171-243-48-148)',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.trim().isEmpty) {
                  setState(() {
                    _error = 'Vui lòng nhập biến động trong link';
                  });
                  return;
                }
                _error = null;
                startFetching(value.trim());
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

// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'dart:async';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Demo Biểu đồ',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const SensorChartScreen(),
//     );
//   }
// }

// class SensorData {
//   final DateTime time;
//   final double temperature;
//   final double pressure;

//   SensorData(this.time, this.temperature, this.pressure);
// }

// class SensorChartScreen extends StatefulWidget {
//   const SensorChartScreen({super.key});

//   @override
//   State<SensorChartScreen> createState() => _SensorChartScreenState();
// }

// class _SensorChartScreenState extends State<SensorChartScreen> {
//   List<SensorData> dataList = [];

//   Timer? timer;

//   @override
//   void initState() {
//     super.initState();
//     timer = Timer.periodic(const Duration(seconds: 2), (timer) {
//       final now = DateTime.now();
//       final temp = 20 + (5 * (timer.tick % 6)); // temp biến đổi giả lập
//       final press = 1000 + (3 * (timer.tick % 4)); // áp suất giả lập
//       setState(() {
//         dataList.add(SensorData(now, temp.toDouble(), press.toDouble()));
//         if (dataList.length > 30) {
//           dataList.removeAt(0); // Giữ tối đa 30 data để nhẹ app
//         }
//       });
//     });
//   }

//   @override
//   void dispose() {
//     timer?.cancel();
//     super.dispose();
//   }

//   List<FlSpot> getTempSpots() {
//     return dataList.asMap().entries.map((entry) {
//       return FlSpot(entry.key.toDouble(), entry.value.temperature);
//     }).toList();
//   }

//   List<FlSpot> getPressSpots() {
//     return dataList.asMap().entries.map((entry) {
//       return FlSpot(entry.key.toDouble(), entry.value.pressure);
//     }).toList();
//   }

//   Widget buildLineChart(List<FlSpot> spots, String title, Color color, double minY, double maxY) {
//     return Card(
//       elevation: 3,
//       child: Padding(
//         padding: const EdgeInsets.all(8),
//         child: Column(
//           children: [
//             Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
//             SizedBox(
//               height: 150,
//               child: LineChart(
//                 LineChartData(
//                   minY: minY,
//                   maxY: maxY,
//                   titlesData: FlTitlesData(
//                     bottomTitles: AxisTitles(
//                       sideTitles: SideTitles(showTitles: false),
//                     ),
//                     leftTitles: AxisTitles(
//                       sideTitles: SideTitles(showTitles: true),
//                     ),
//                     rightTitles: AxisTitles(
//                       sideTitles: SideTitles(showTitles: false),
//                     ),
//                     topTitles: AxisTitles(
//                       sideTitles: SideTitles(showTitles: false),
//                     ),
//                   ),
//                   gridData: FlGridData(show: true),
//                   borderData: FlBorderData(show: true),
//                   lineBarsData: [
//                     LineChartBarData(
//                       spots: spots,
//                       isCurved: true,
//                       color: color,
//                       barWidth: 3,
//                       dotData: FlDotData(show: false),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildHistoryColumn(String title, List<String> entries) {
//     return Expanded(
//       child: Card(
//         elevation: 3,
//         child: Padding(
//           padding: const EdgeInsets.all(8),
//           child: Column(
//             children: [
//               Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
//               const Divider(),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: entries.length,
//                   itemBuilder: (context, index) {
//                     return Text(entries[index]);
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final tempHistory = dataList
//         .reversed
//         .take(10)
//         .map((e) => "${e.time.hour}:${e.time.minute}:${e.time.second} - ${e.temperature} °C")
//         .toList();

//     final pressHistory = dataList
//         .reversed
//         .take(10)
//         .map((e) => "${e.time.hour}:${e.time.minute}:${e.time.second} - ${e.pressure} hPa")
//         .toList();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Biểu đồ Nhiệt độ & Áp suất'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           children: [
//             Text(
//               "Ngày giờ hiện tại: ${DateTime.now()}",
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             Expanded(
//               flex: 3,
//               child: Row(
//                 children: [
//                   Expanded(child: buildLineChart(getTempSpots(), "Nhiệt độ (°C)", Colors.red, 0, 40)),
//                   const SizedBox(width: 10),
//                   Expanded(child: buildLineChart(getPressSpots(), "Áp suất (hPa)", Colors.blue, 900, 1100)),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 8),
//             Expanded(
//               flex: 2,
//               child: Row(
//                 children: [
//                   buildHistoryColumn("Lịch sử nhiệt độ", tempHistory),
//                   const SizedBox(width: 10),
//                   buildHistoryColumn("Lịch sử áp suất", pressHistory),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
