import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';

class PatientStatisticsPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String patientEmail;

  const PatientStatisticsPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
  });

  @override
  State<PatientStatisticsPage> createState() => _PatientStatisticsPageState();
}

class _PatientStatisticsPageState extends State<PatientStatisticsPage> {
  List<FlSpot> data = [];
  List<String> timeLabels = []; // ⏰ Store time keys (12:50, 12:51…)
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  void _fetchStatistics() async {
    DatabaseReference statsRef = FirebaseDatabase.instance
        .ref("statistics/${widget.patientEmail.replaceAll('.', '_')}/temperatureLogs");

    statsRef.once().then((snapshot) {
      final logs = snapshot.snapshot.value as Map?;
      if (logs != null) {
        final List<FlSpot> spots = [];
        final List<String> labels = [];
        int index = 0;

        // ✅ Sort keys so times appear in order
        final sortedKeys = logs.keys.toList()..sort();

        for (var key in sortedKeys) {
          final entry = logs[key] as Map?;
          final value = (entry?["value"] as num?)?.toDouble();
          if (value != null) {
            spots.add(FlSpot(index.toDouble(), value));
            labels.add(key.toString()); // save the time string
            index++;
          }
        }

        setState(() {
          data = spots;
          timeLabels = labels;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double avg = 0, highest = 0, lowest = 0;
    if (data.isNotEmpty) {
      avg = data.map((e) => e.y).reduce((a, b) => a + b) / data.length;
      highest = data.map((e) => e.y).reduce(max);
      lowest = data.map((e) => e.y).reduce(min);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Statistics - ${widget.patientName}'),
        backgroundColor: Colors.blueAccent,
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : data.isEmpty
          ? const Center(child: Text("No temperature data available"))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Graph
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Temperature Logs",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: data.length.toDouble() - 1,
                          minY: data.map((e) => e.y).reduce(min) - 5,
                          maxY: data.map((e) => e.y).reduce(max) + 5,
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.toInt();
                                  if (idx >= 0 &&
                                      idx < timeLabels.length) {
                                    return Text(timeLabels[idx],
                                        style: const TextStyle(
                                            fontSize: 10));
                                  }
                                  return const SizedBox.shrink();
                                },
                                interval: 1,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, interval: 5),
                            ),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: data,
                              isCurved: true,
                              color: Colors.blueAccent,
                              barWidth: 4,
                              isStrokeCapRound: true,
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withOpacity(0.3),
                              ),
                              dotData: FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard("Average", avg.toStringAsFixed(1)),
                _buildStatCard("Highest", highest.toStringAsFixed(1)),
                _buildStatCard("Lowest", lowest.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 100,
        child: Column(
          children: [
            Text(
              title,
              style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
