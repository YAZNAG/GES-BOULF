import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Histogramme simple (7 derniers jours) dessiné avec des widgets Flutter.
class BarChart extends StatefulWidget {
  const BarChart({super.key, required this.values, required this.labels, this.height = 170, this.highlightLast = true});

  final List<double> values;
  final List<String> labels;
  final double height;
  final bool highlightLast;

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    final sel = _selected ?? (widget.highlightLast && values.isNotEmpty ? values.length - 1 : null);
    return Column(children: [
      SizedBox(
        height: 22,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            sel == null ? '' : '${widget.labels[sel]} · ${money(values[sel])}',
            key: ValueKey(sel),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: widget.height,
        child: Stack(children: [
          // Lignes de repère.
          Positioned.fill(
            bottom: 22,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (_) => Container(height: 1, color: AppColors.border.withValues(alpha: 0.7))),
            ),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    LayoutBuilder(builder: (context, c) {
                      final h = (widget.height - 30) * (max <= 0 ? 0 : values[i] / max);
                      final active = i == sel;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: h < 4 ? 4 : h),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Container(
                          height: v,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: active
                                  ? const [AppColors.primaryDark, AppColors.primary]
                                  : [AppColors.primary.withValues(alpha: 0.18), AppColors.primary.withValues(alpha: 0.32)],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 16,
                      child: Text(
                        widget.labels[i],
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: i == sel ? FontWeight.w800 : FontWeight.w500,
                          color: i == sel ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    ]);
  }
}
