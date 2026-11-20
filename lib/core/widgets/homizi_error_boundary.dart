import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Replaces Flutter's release error widget, which can paint as an empty
/// white page when a build throws.
Widget homiziErrorWidget(FlutterErrorDetails details) {
  return HomiziErrorFallback(detail: details.exceptionAsString());
}

/// Catches a build failure in [child] so one widget cannot blank the route.
class HomiziErrorBoundary extends StatefulWidget {
  const HomiziErrorBoundary({required this.child, super.key});

  final Widget child;

  @override
  State<HomiziErrorBoundary> createState() => _HomiziErrorBoundaryState();
}

class _HomiziErrorBoundaryState extends State<HomiziErrorBoundary> {
  Object? _error;

  @override
  void didUpdateWidget(covariant HomiziErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _error = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _error;
    if (failure != null) {
      return HomiziErrorFallback(
        detail: '$failure',
        onRetry: () => setState(() => _error = null),
      );
    }
    return _ErrorCatch(
      onError: (error) {
        if (!mounted || _error != null) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _error = error);
          }
        });
      },
      child: widget.child,
    );
  }
}

class _ErrorCatch extends StatelessWidget {
  const _ErrorCatch({required this.child, required this.onError});

  final Widget child;
  final ValueChanged<Object> onError;

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (error) {
      onError(error);
      return HomiziErrorFallback(detail: '$error');
    }
  }
}

class HomiziErrorFallback extends StatelessWidget {
  const HomiziErrorFallback({required this.detail, this.onRetry, super.key});

  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomiziColors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.home_repair_service_outlined,
                  color: HomiziColors.logoOrange,
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'This section hit a snag',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The rest of Homizi is still here. Try this part again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HomiziColors.inkSoft, height: 1.35),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomiziColors.logoOrange,
                      foregroundColor: HomiziColors.ink,
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
