// Flutter Offline-First Architecture Examples
// See also: ../references/flutter-offline-guide.md

/// Example: Offline-First Comment Service
class CommentService {
  final CommentRepository _localDb;
  final CommentApi _remoteApi;
  final SyncQueue _syncQueue;

  CommentService({
    required CommentRepository localDb,
    required CommentApi remoteApi,
    required SyncQueue syncQueue,
  })  : _localDb = localDb,
        _remoteApi = remoteApi,
        _syncQueue = syncQueue;

  Future<void> postComment(String text, String postId) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final comment = Comment(
      id: tempId,
      text: text,
      postId: postId,
      synced: false,
      timestamp: DateTime.now(),
    );

    // 1. Save locally immediately
    await _localDb.insert(comment);

    // 2. Update UI (optimistic)
    // State management will notify listeners

    // 3. Sync to server in background
    try {
      final serverComment = await _remoteApi.postComment(text, postId);
      // Replace temp ID with server ID
      await _localDb.update(
        tempId,
        serverComment.copyWith(synced: true),
      );
    } catch (error) {
      // Mark as pending sync, retry later
      await _localDb.update(
        tempId,
        comment.copyWith(syncError: error.toString()),
      );
      _syncQueue.add(
        SyncTask(type: SyncType.comment, id: tempId),
      );
    }
  }
}

/// Example: Offline UI Pattern
class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(dataProvider);

        return asyncData.when(
          data: (data) {
            if (data.isEmpty) {
              return const EmptyState(message: 'No data available');
            }
            return DataList(data: data);
          },
          loading: () => const LoadingIndicator(),
          error: (error, stack) {
            // Check if offline
            return ConnectivityBuilder(
              builder: (context, isConnected, child) {
                if (!isConnected) {
                  return OfflineError(
                    message: 'No internet connection',
                    onRetry: () => ref.refresh(dataProvider.future),
                  );
                }
                return ErrorWidget(
                  error: error,
                  onRetry: () => ref.refresh(dataProvider.future),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Helper classes and types
class Comment {
  final String id;
  final String text;
  final String postId;
  final bool synced;
  final DateTime timestamp;
  final String? syncError;

  Comment copyWith({
    String? id,
    String? text,
    String? postId,
    bool? synced,
    DateTime? timestamp,
    String? syncError,
  }) {
    return Comment(
      id: id ?? this.id,
      text: text ?? this.text,
      postId: postId ?? this.postId,
      synced: synced ?? this.synced,
      timestamp: timestamp ?? this.timestamp,
      syncError: syncError ?? this.syncError,
    );
  }
}

abstract class CommentRepository {
  Future<void> insert(Comment comment);
  Future<void> update(String id, Comment comment);
}

abstract class CommentApi {
  Future<Comment> postComment(String text, String postId);
}

class SyncTask {
  final SyncType type;
  final String id;
  SyncTask({required this.type, required this.id});
}

enum SyncType { comment }

abstract class SyncQueue {
  void add(SyncTask task);
}

// Mock providers and widgets for example
final dataProvider = FutureProvider<List<Data>>((ref) async => []);

class DataList extends StatelessWidget {
  final List<Data> data;
  const DataList({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) => Text(data[index].toString()),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class OfflineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const OfflineError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(message),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class ErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorWidget({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text('Error: $error'),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class ConnectivityBuilder extends StatelessWidget {
  final Widget Function(BuildContext, bool, Widget?) builder;
  final Widget? child;

  const ConnectivityBuilder({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    // Mock implementation
    return builder(context, true, child);
  }
}

typedef FutureProvider<T> = ProviderBase<AsyncValue<T>>;
abstract class ProviderBase<T> {}
abstract class AsyncValue<T> {
  Future<T> get future;
}
abstract class ProviderScope extends Widget {
  const ProviderScope({super.key, required Widget child});
}
class Consumer extends StatelessWidget {
  const Consumer({super.key, required this.builder});
  final Widget Function(BuildContext, WidgetRef, Widget?) builder;
  @override
  Widget build(BuildContext context) => builder(context, null, null);
}
abstract class WidgetRef {
  FutureProvider<T> watch<T>(FutureProvider<T> provider);
  Future<T> refresh<T>(Future<T> future);
}
class Data {}
typedef VoidCallback = void Function();
