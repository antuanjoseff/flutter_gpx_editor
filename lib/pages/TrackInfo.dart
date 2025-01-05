import 'package:flutter/material.dart';
import '../classes/track.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gpx_editor/vars/vars.dart';
import 'dart:math' as math;
import '../util.dart';

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

    double minY2 = widget.track!.getMinSpeed();
    double maxY2 = widget.track!.getMaxSpeed();
    double minY = widget.track!.getMinElevation();
    double maxY = widget.track!.getMaxElevation();
    List<FlSpot> lengthSpots = [];
    List<FlSpot> elevationSpots = [];
    List<FlSpot> speedSpots = [];

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

    Widget formatLeftYLabel(value, meta) {
      if (value == meta.min || value == meta.max) {
        return const Text('');
      } else {
        double s = (value - minY) / (maxY - minY) * (maxY2 - minY2) + minY2;

        debugPrint('toni $value --   $s');
        return Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text('${s.toStringAsFixed(1)}km/h'),
        );
      }
    }

    List<FlSpot> getSpotsElevation() {
      List<FlSpot> chartLineSpots = [];
      List<int> xValues = widget.track!.getXChartLabels();
      List<int> yValues = widget.track!.getElevations();
      // List<double> y2Values = widget.track!.getSpeeds();

      for (int i = 0; i < widget.track!.getCoordsList().length; i++) {
        chartLineSpots.add(FlSpot(
          xValues[i].toDouble(),
          yValues[i].toDouble(),
          // y2Values[i].toDouble(),
        ));
      }

      elevationSpots = chartLineSpots;
      return chartLineSpots;
    }

    List<FlSpot> getSpotsSpeed() {
      List<FlSpot> chartLineSpots = [];
      List<int> xValues = widget.track!.getXChartLabels();
      List<double> yValues = widget.track!.getSpeeds();

      for (int i = 0; i < widget.track!.getSpeeds().length; i++) {
        double Y2 = yValues[i].toDouble();

        chartLineSpots.add(FlSpot(
          xValues[i].toDouble(),
          (Y2 - minY2) / (maxY2 - minY2) * (maxY - minY) + minY,
          // yValues[i].toDouble(),
        ));
      }
      speedSpots = chartLineSpots;
      return chartLineSpots;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: widget.width,
            height: widget.height,
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
                    touchSpotThreshold: 50,
                    getTouchLineStart: (_, __) => -double.infinity,
                    getTouchLineEnd: (_, __) => double.infinity,
                    getTouchedSpotIndicator:
                        (LineChartBarData barData, List<int> spotIndexes) {
                      return spotIndexes.map((spotIndex) {
                        return TouchedSpotIndicatorData(
                          const FlLine(
                            color: Colors.red,
                            strokeWidth: 1.5,
                            dashArray: [8, 2],
                          ),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: Colors.blue,
                                strokeWidth: 3,
                                strokeColor: Colors.black,
                              );
                            },
                          ),
                        );
                      }).toList();
                    },
                    touchCallback:
                        (FlTouchEvent event, LineTouchResponse? response) {
                      if (response == null || response.lineBarSpots == null) {
                        return;
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      showOnTopOfTheChartBoxArea: true,
                      getTooltipColor: (LineBarSpot touchedSpot) =>
                          Colors.green,
                      getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                        LineBarSpot lineBarSpot = lineBarsSpot[0];
                        double node = lineBarSpot.x;
                        int idx = lineBarSpot.spotIndex;
                        widget.controller.showNode(widget.track!.getNode(idx));

                        double e = elevationSpots[idx].y;
                        double val = speedSpots[idx].y;

                        double s =
                            (val - minY) / (maxY - minY) * (maxY2 - minY2) +
                                minY2;

                        String d = formatDistance(lineBarsSpot[0].x);
                        String label = '${e}m\n${s.toStringAsFixed(2)}km/h\n$d';

                        return lineBarsSpot.map((lineBarSpot) {
                          if (lineBarSpot.barIndex == 0) {
                            return LineTooltipItem(
                              '',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(
                                  text: label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                )
                              ],
                            );
                          } else {
                            // double value = (lineBarSpot.y - minY) /
                            //         (maxY - minY) *
                            //         (maxY2 - minY2) +
                            //     minY2;
                            // return LineTooltipItem(
                            //   'speed',
                            //   const TextStyle(
                            //     color: Colors.white,
                            //     fontWeight: FontWeight.bold,
                            //   ),
                            //   children: [
                            //     TextSpan(
                            //       text: '${value.toStringAsFixed(2)} km/h',
                            //       style: const TextStyle(
                            //         color: Colors.white,
                            //         fontWeight: FontWeight.w900,
                            //       ),
                            //     )
                            //   ],
                            // );
                          }
                        }).toList();
                      },
                    )),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 75,
                    // interval: (widget.track!.getLength() / numberOfTags),
                    getTitlesWidget: (value, meta) =>
                        formatLeftYLabel(value, meta),
                  )),
                  rightTitles: AxisTitles(
                    // axisNameSize: 80,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
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
                      spots: getSpotsSpeed(),
                      color: Colors.green,
                      barWidth: 2,
                      isCurved: true,
                      dotData: const FlDotData(
                        show: false,
                      )),
                  LineChartBarData(
                    spots: getSpotsElevation(),
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
