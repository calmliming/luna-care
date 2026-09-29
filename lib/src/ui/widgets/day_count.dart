import 'package:flutter/material.dart';

import '../../theme.dart';

/// A number of days, "29 天", with the number in the display face.
class DayCount extends StatelessWidget {
  const DayCount(this.days, {super.key, this.size = 24, this.color});

  final int days;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final unit = DefaultTextStyle.of(context).style.copyWith(color: color);
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$days', style: numeralStyle(context, size, color: unit.color)),
          const SizedBox(width: 4),
          Text('天', style: unit),
        ],
      ),
    );
  }
}
