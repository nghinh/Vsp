# Flutter Offline-First Architecture Guide

Building Flutter apps that work seamlessly offline and sync intelligently when online.

## Core Principles

1. **Local-First Data:** Store data locally first, sync to server second
2. **Optimistic UI:** Show changes immediately, sync in background
3. **Graceful Degradation:** App remains usable during network issues
4. **Conflict Resolution:** Handle conflicting changes intelligently

## Local Storage Options

| Solution | Best For | Size Limit | Type |
|----------|----------|------------|------|
| **SharedPreferences** | Simple flags, settings | No practical limit | Key-value |
| **Hive** | Fast NoSQL, complex objects | No limit | NoSQL |
| **Drift (sqflite)** | Relational data, relationships | No limit | SQLite wrapper |
| **ObjectBox** | Object database, high performance | No limit | Object DB |

### Recommendations

- **Small data (<100KB):** SharedPreferences
- **Medium data (<10MB):** Hive
- **Large/complex data:** Drift or ObjectBox
- **Relationships:** Drift

## Data Synchronization Strategies

### 1. Write-Through Cache

```
User makes change
├─ Update local database immediately
├─ Update UI optimistically
├─ Queue sync operation
└─ Sync to server in background
```

**When to use:** Most scenarios, user-generated content

### 2. Hybrid Sync (Push + Pull)

**Push Sync (Real-time):**
- WebSocket connection for critical updates
- Immediate notification of changes

**Pull Sync (Periodic):**
- Periodic polling for non-critical data
- Pull on app foreground
- Incremental sync (only changes since last sync)

**When to use:** Real-time collaboration, chat, live updates

### 3. Conflict Resolution

| Strategy | Description | When to Use |
|----------|-------------|-------------|
| **Last-write-wins** | Most recent change wins | Simple scenarios |
| **Operational transformation** | Merge changes intelligently | Real-time collaboration |
| **Manual resolution** | User chooses | Critical data |

## Implementation Patterns

### Offline Service Pattern

```dart
class OfflineService<T> {
  final LocalRepository<T> _local;
  final RemoteRepository<T> _remote;
  final SyncQueue _syncQueue;

  Future<void> create(T item) async {
    // 1. Generate temp ID
    final tempId = generateTempId();
    final offlineItem = item.copyWith(
      id: tempId,
      synced: false,
    );

    // 2. Save locally
    await _local.insert(offlineItem);

    // 3. Queue sync
    _syncQueue.add(SyncTask.create(offlineItem));

    // 4. Sync in background
    _syncInBackground(tempId, item);
  }

  Future<void> _syncInBackground(String tempId, T item) async {
    try {
      final serverItem = await _remote.create(item);
      await _local.update(tempId, serverItem.copyWith(synced: true));
    } catch (e) {
      await _local.markSyncError(tempId, e.toString());
    }
  }
}
```

### Optimistic UI Pattern

```dart
class OptimisticList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemProvider);

    return items.when(
      data: (data) => ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) => ItemTile(data[index]),
      ),
      loading: () => const LoadingIndicator(),
      error: (e, s) => ErrorWidget(e, retry: () => ref.refresh(itemProvider)),
    );
  }
}
```

## Network Awareness

### Detecting Connectivity

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkAwareService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChange =>
      _connectivity.onConnectivityChanged.map((result) =>
        result != ConnectivityResult.none
      );

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
```

### Connectivity-Aware UI

```dart
class ConnectivityBuilder extends StatelessWidget {
  final Widget Function(BuildContext, bool) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NetworkAwareService().onConnectivityChange,
      initialData: true,
      builder: (context, snapshot) {
        return builder(context, snapshot.data ?? true);
      },
    );
  }
}
```

## Error Handling

### Offline-Specific Errors

```dart
enum SyncError {
  noConnection,
  serverUnavailable,
  conflict,
  unauthorized,
}

class SyncException implements Exception {
  final SyncError error;
  final String? message;

  SyncException(this.error, [this.message]);
}
```

### User Feedback

```dart
void handleSyncError(BuildContext context, SyncException e) {
  switch (e.error) {
    case SyncError.noConnection:
      showSnackBar(context, 'Changes saved. Will sync when online.');
      break;
    case SyncError.serverUnavailable:
      showSnackBar(context, 'Server unavailable. Will retry later.');
      break;
    case SyncError.conflict:
      showConflictDialog(context);
      break;
    default:
      showSnackBar(context, 'Sync failed. Please try again.');
  }
}
```

## Best Practices

1. **Always cache data locally** for offline access
2. **Show cached data immediately** while fetching fresh data
3. **Queue failed operations** for retry when online
4. **Indicate sync status** visually to users
5. **Handle conflicts** gracefully
6. **Test offline scenarios** regularly

## Resources

**Packages:**
- [connectivity_plus](https://pub.dev/packages/connectivity_plus) - Network connectivity
- [hive](https://pub.dev/packages/hive) - NoSQL database
- [drift](https://pub.dev/packages/drift) - SQLite ORM

**Examples:**
- See `../examples/offline_examples.dart` for code examples
