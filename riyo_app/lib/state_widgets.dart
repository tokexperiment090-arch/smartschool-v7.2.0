import 'package:flutter/material.dart';
import 'api_config.dart';

/// Generic loading widget (centered spinner with optional message).
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: const TextStyle(color: Colors.black54)),
            ],
          ],
        ),
      );
}

/// Generic empty-state widget.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const EmptyView({super.key, this.icon = Icons.inbox_outlined, required this.title, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Colors.black26),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              ],
            ],
          ),
        ),
      );
}

/// Generic error widget. Shows the [friendlyError] message and an optional
/// retry button. If [onRetry] is null the retry button is hidden.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconFor(error), size: 56, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                friendlyError(error),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      );

  IconData _iconFor(Object e) {
    if (e is ApiException) {
      switch (e.code) {
        case ApiError.noNetwork:
          return Icons.wifi_off;
        case ApiError.timeout:
          return Icons.timer_off_outlined;
        case ApiError.unauthorized:
          return Icons.lock_outline;
        case ApiError.forbidden:
          return Icons.block;
        case ApiError.notFound:
          return Icons.search_off;
        case ApiError.invalidResponse:
          return Icons.warning_amber_outlined;
        case ApiError.serverError:
        case ApiError.badRequest:
        case ApiError.unknown:
          return Icons.error_outline;
      }
    }
    return Icons.error_outline;
  }
}

/// Convenience: a single widget that switches between loading / error / empty /
/// real content based on the supplied [AsyncSnapshot]-like state.
class StateBody<T> extends StatelessWidget {
  final bool loading;
  final Object? error;
  final T? data;
  final bool Function(T data) isEmpty;
  final Widget Function(T data) builder;
  final String? emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final VoidCallback? onRetry;

  const StateBody({
    super.key,
    required this.loading,
    required this.error,
    required this.data,
    required this.isEmpty,
    required this.builder,
    this.onRetry,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingView();
    if (error != null) return ErrorView(error: error!, onRetry: onRetry);
    if (data == null || isEmpty(data as T)) {
      return EmptyView(
        icon: emptyIcon,
        title: emptyTitle ?? 'Nothing here yet',
        message: emptyMessage,
      );
    }
    return builder(data as T);
  }
}
