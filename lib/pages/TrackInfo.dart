import 'package:flutter/material.dart';
import '../classes/track.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gpx_editor/vars/vars.dart';
import 'dart:math' as math;

class TrackInfo extends StatefulWidget {
  final controller;
  final track;
  final width;
  final height;
  const TrackInfo(
      {super.key,
      required this.controller,
      required this.track,
      required this.width,
      required this.height});

  @override
  State<TrackInfo> createState() => _TrackInfoState();
}

class _TrackInfoState extends State<TrackInfo> {
  List<Color> gradientColors = [
    Colors.red.withOpacity(0),
    Colors.red.withOpacity(0.8),
    Colors.red.withOpacity(0.5),
    Colors.red.withOpacity(0.1),
  ];

  int numberOfTags = 5;

  String formatDistance(double length) {
    int kms = (length / 1000).floor().toInt();
    int mts = (length - (kms * 1000)).toInt();

    String plural = kms > 1 ? 's ' : ' ';

    String format = '';
    if (kms > 0) {
      format = '${kms.toString()}Km${plural}';
    }

    if (mts != 0) {
      format += ' ${mts}m';
    }

    return format;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");

    String days = duration.inDays > 0 ? '${duration.inDays} days' : '';
    String hours = duration.inHours > 0 ? '${duration.inHours} h' : '';

    String minutes = twoDigits(duration.inMinutes.remainder(60).abs()) + ' min';
    String seconds = twoDigits(duration.inSeconds.remainder(60).abs()) + 'seg';

    return "$days $hours $minutes $seconds";
  }

  List<FlSpot> getSpots() {
    List<FlSpot> chartLineSpots = [];
    List<int> xValues = widget.track!.getXChartLabels();
    List<int> yValues = widget.track!.getElevations();
    for (int i = 0; i < widget.track!.getCoordsList().length; i++) {
      chartLineSpots.add(FlSpot(xValues[i].toDouble(), yValues[i].toDouble()));
    }
    return chartLineSpots;
  }

  Widget formatLabel(value, meta) {
    if (value == meta.max) {
      return const Text('');
    } else {
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Text('${(value / 1000).toStringAsFixed(1)}km'),
      );
    }
  }

  Widget formatYLabel(value, meta) {
    if (value == meta.min || value == meta.max) {
      return const Text('');
    } else {
      return Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Text('${value.toStringAsFixed(0)}m'),
      );
    }
  }

  late double length;
  late Duration duration;
  late String speed;
  late int elevationGain;
  late int elevationLoss;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    length = widget.track!.getLength();
    duration = widget.track!.getDuration();
    speed = (length / duration.inSeconds * 3.6).toStringAsFixed(2);
    elevationGain = widget.track!.getElevationGain();
    elevationLoss = widget.track!.getElevationLoss();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Icon(Icons.straighten_outlined),
                  Text(formatDistance(length)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.hourglass_bottom_rounded),
                  Text(_formatDuration(duration))
                ],
              ),
              Column(
                children: [
                  Icon(Icons.speed),
                  Text('$speed Km/h'),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.change_history_rounded),
                  Text('$elevationGain m'),
                ],
              ),
              Column(
                children: [
                  Transform.rotate(
                      angle: math.pi,
                      child: Icon(Icons.change_history_rounded)),
                  Text('$elevationLoss m'),
                ],
              )
            ],
          ),
          SizedBox(
            width: widget.width,
            height: widget.height + 50,
            child: LineChart(LineChartData(
                minX: 0,
                maxX: widget.track!.getLength(),
                minY: widget.track.getMinElevation(),
                maxY: widget.track.getMaxElevation(),
                borderData: FlBorderData(
                  show: false,
                ),
                gridData: FlGridData(
                  show: false,
                ),
                lineTouchData: LineTouchData(
                    touchCallback:
                        (FlTouchEvent event, LineTouchResponse? response) {
                      if (response == null || response.lineBarSpots == null) {
                        return;
                      }
                      if (event is FlTapUpEvent) {
                        final spotIndex =
                            response.lineBarSpots!.first.spotIndex;
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (LineBarSpot touchedSpot) =>
                          Colors.green,
                      getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                        return lineBarsSpot.map((lineBarSpot) {
                          double node = lineBarSpot.x;
                          int idx = lineBarSpot.spotIndex;
                          String label = '${lineBarSpot.y.toString()} $node m';
                          widget.controller
                              .showNode(widget.track!.getNode(idx));
                          return LineTooltipItem(
                            label,
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    )),
                titlesData: FlTitlesData(
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    axisNameSize: 80,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) =>
                          formatYLabel(value, meta),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: (widget.track!.getLength() / numberOfTags),
                      getTitlesWidget: (value, meta) =>
                          formatLabel(value, meta),
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: getSpots(),
                    color: primaryColor,
                    barWidth: 2,
                    isCurved: false,
                    dotData: const FlDotData(
                      show: false,
                    ),
                    shadow: const Shadow(
                      color: Colors.yellow,
                      blurRadius: 2,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: gradientColors,
                      ),
                    ),
                  ),
                ])),
          ),
        ],
      ),
    );
  }
}
