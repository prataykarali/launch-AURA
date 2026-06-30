import 'package:flutter/material.dart';

class MetricStat extends StatelessWidget {
  final String l, v;
  final Color c;
  const MetricStat(this.l, this.v, this.c, {super.key});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 18,
        fontWeight: FontWeight.w800)),
    Text(l, style: TextStyle(color: Colors.white.withOpacity(0.3),
        fontSize: 9)),
  ]));
}
