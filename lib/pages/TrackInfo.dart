import 'package:flutter/material.dart';
import '../classes/track.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gpx_editor/vars/vars.dart';

class TrackInfo extends StatefulWidget {
  final track;
  const TrackInfo({
    super.key,
    required this.track,
  });

  @override
  State<TrackInfo> createState() => _TrackInfoState();
}

class _TrackInfoState extends State<TrackInfo> {
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
      return Text('${(value / 1000).toStringAsFixed(1)}km');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track stats'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 800,
            height: 400,
            child: LineChart(LineChartData(
                minX: 0,
                maxX: widget.track!.getLength(),
                minY: widget.track.getMinElevation(),
                maxY: widget.track.getMaxElevation(),
                titlesData: FlTitlesData(
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) => formatLabel(value, meta),
                  )),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: getSpots(),
                    color: primaryColor,
                    barWidth: 2,
                    isCurved: true,
                  ),
                ])),
          ),
          Text('Track length'),
          Text(formatDistance(widget.track!.getLength())),
          Text('Track Duration'),
          Text(_formatDuration(widget.track!.getDuration()))
        ],
      ),
    );
  }
}
