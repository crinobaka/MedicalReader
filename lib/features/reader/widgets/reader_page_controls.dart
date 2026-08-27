import 'package:flutter/material.dart';

/// Bottom navigation controls for the Reader page.
///
/// The row is deliberately scrollable on narrow screens. In floating mode it
/// becomes an overlay surface and does not add visual chrome intended for a
/// fixed app bar.
class ReaderPageControls extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final bool pageLoading;
  final String pageLabel;
  final String? locationLabel;
  final String? searchLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPageTap;
  final bool floating;
  final double? progress;
  final ValueChanged<double>? onProgressChanged;

  const ReaderPageControls({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.pageLoading,
    required this.pageLabel,
    this.locationLabel,
    this.searchLabel,
    this.onPrevious,
    this.onNext,
    this.onPageTap,
    this.floating = false,
    this.progress,
    this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !pageLoading;
    final width = MediaQuery.sizeOf(context).width;
    final labelWidth = (width - 128).clamp(140.0, 320.0).toDouble();
    final scheme = Theme.of(context).colorScheme;

    final content = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(8, floating ? 6 : 4, 8, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavigationButton(
            tooltip: '上一页',
            icon: Icons.chevron_left,
            enabled: enabled && canGoPrevious,
            onPressed: onPrevious,
            floating: floating,
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: '当前页码，点击跳转',
            child: Material(
              color: floating
                  ? scheme.surface.withValues(alpha: 0.88)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(floating ? 16 : 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(floating ? 16 : 12),
                onTap: enabled ? onPageTap : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: labelWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pageLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (progress != null && onProgressChanged != null) ...[
                          const SizedBox(height: 2),
                          SizedBox(
                            width: (labelWidth - 28).clamp(112.0, 280.0).toDouble(),
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              ),
                              child: Slider(
                                value: progress!.clamp(0.0, 1.0),
                                min: 0,
                                max: 1,
                                onChanged: enabled ? onProgressChanged : null,
                                semanticFormatterCallback: (value) =>
                                    '阅读进度 ${(value * 100).round()}%',
                              ),
                            ),
                          ),
                        ],
                        if (locationLabel != null)
                          Text(
                            locationLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (searchLabel != null)
                          Text(
                            searchLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _NavigationButton(
            tooltip: '下一页',
            icon: Icons.chevron_right,
            enabled: enabled && canGoNext,
            onPressed: onNext,
            floating: floating,
          ),
        ],
      ),
    );

    if (floating) {
      return SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: content,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Material(
        elevation: 1,
        child: content,
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool floating;

  const _NavigationButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.floating,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: IconButton.filledTonal(
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, size: 30),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
          style: floating
              ? IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
                )
              : null,
        ),
      ),
    );
  }
}
