import 'package:flutter/material.dart';

/// Bottom navigation controls for the Reader page.
///
/// The row is deliberately scrollable on narrow screens. The page/location
/// block is a real tap target rather than decorative text, so users can always
/// reach page navigation even when chapter names are long.
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
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !pageLoading;
    final width = MediaQuery.sizeOf(context).width;
    final labelWidth = (width - 128).clamp(140.0, 320.0).toDouble();

    return SafeArea(
      top: false,
      child: Material(
        elevation: 1,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavigationButton(
                tooltip: '上一页',
                icon: Icons.chevron_left,
                enabled: enabled && canGoPrevious,
                onPressed: onPrevious,
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: '当前页码，点击跳转',
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: enabled ? onPageTap : null,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: labelWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pageLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const _NavigationButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
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
        ),
      ),
    );
  }
}
