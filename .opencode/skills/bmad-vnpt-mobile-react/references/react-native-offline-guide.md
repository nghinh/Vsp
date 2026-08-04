# React Native Offline-First Architecture Guide

Building React Native apps that work seamlessly offline and sync intelligently when online.

## Core Principles

1. **Local-First Data:** Store data locally first, sync to server second
2. **Optimistic UI:** Show changes immediately, sync in background
3. **Graceful Degradation:** App remains usable during network issues
4. **Conflict Resolution:** Handle conflicting changes intelligently

## Local Storage Options

| Solution | Best For | Size Limit | Type |
|----------|----------|------------|------|
| **AsyncStorage** | Simple data, preferences | 6MB | Key-value |
| **MMKV** | Fast key-value, large data | No practical limit | Key-value |
| **Realm** | Complex objects, relationships | No limit | Object database |
| **WatermelonDB** | Relational data, reactive | No limit | SQLite-based |
| **SQLite** | Raw SQL, complex queries | No limit | SQL database |

### Recommendations

- **Small data (<100KB):** AsyncStorage
- **Fast key-value:** MMKV
- **Complex relationships:** Realm or WatermelonDB
- **SQL needs:** SQLite (react-native-quick-sqlite)

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
| **CRDT** | Conflict-free replicated data types | Distributed systems |
| **Manual resolution** | User chooses | Critical data |

## Implementation Patterns

### Offline Service Pattern (with TanStack Query)

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query';
import NetInfo from '@react-native-community/netinfo';

class CommentService {
  private localDb: LocalCommentRepository;
  private remoteApi: CommentApi;
  private syncQueue: SyncQueue;

  async postComment(text: string, postId: string) {
    const tempId = `temp_${Date.now()}`;
    const comment: Comment = {
      id: tempId,
      text,
      postId,
      synced: false,
      timestamp: Date.now(),
    };

    // 1. Save locally immediately
    await this.localDb.insert(comment);

    // 2. Sync in background if online
    const isConnected = await NetInfo.fetch().then(
      (state) => state.isConnected
    );

    if (isConnected) {
      this.syncInBackground(tempId, text, postId);
    } else {
      // Queue for later sync
      await this.syncQueue.add({
        type: 'postComment',
        data: { tempId, text, postId },
      });
    }
  }

  private async syncInBackground(tempId: string, text: string, postId: string) {
    try {
      const serverComment = await this.remoteApi.postComment(text, postId);
      await this.localDb.update(tempId, { ...serverComment, synced: true });
    } catch (error) {
      await this.localDb.update(tempId, { synced: false, syncError: error.message });
    }
  }
}
```

### Optimistic UI Hook

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query';

function usePostComment() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ text, postId }: { text: string; postId: string }) => {
      return CommentService.postComment(text, postId);
    },

    // Optimistic update
    onMutate: async (variables) => {
      // Cancel ongoing queries
      await queryClient.cancelQueries({ queryKey: ['comments', variables.postId] });

      // Snapshot previous value
      const previousComments = queryClient.getQueryData<Comment[]>(['comments', variables.postId]);

      // Optimistically update
      const tempComment: Comment = {
        id: `temp_${Date.now()}`,
        text: variables.text,
        postId: variables.postId,
        synced: false,
        timestamp: Date.now(),
      };

      queryClient.setQueryData<Comment[]>(['comments', variables.postId], (old = []) => [
        ...old,
        tempComment,
      ]);

      return { previousComments };
    },

    // Rollback on error
    onError: (err, variables, context) => {
      queryClient.setQueryData(['comments', variables.postId], context?.previousComments);
    },

    // Refetch on success
    onSettled: (data, error, variables) => {
      queryClient.invalidateQueries({ queryKey: ['comments', variables.postId] });
    },
  });
}
```

### Network-Aware Components

```typescript
import NetInfo from '@react-native-community/netinfo';

export function useNetworkStatus() {
  const [isConnected, setIsConnected] = useState(true);

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener((state) => {
      setIsConnected(state.isConnected ?? false);
    });

    return () => unsubscribe();
  }, []);

  return isConnected;
}

// Usage
function DataScreen() {
  const isConnected = useNetworkStatus();
  const { data, isLoading, error } = useQuery({
    queryKey: ['data'],
    queryFn: fetchData,
  });

  if (isLoading) return <LoadingSpinner />;

  if (error && !isConnected) {
    return <OfflineError onRetry={() => refetch()} />;
  }

  if (error) {
    return <Error error={error} onRetry={() => refetch()} />;
  }

  return <DataList data={data} />;
}
```

## TanStack Query Offline Configuration

```typescript
// queryClient.ts
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Stale time determines how long data is considered fresh
      staleTime: 5 * 60 * 1000, // 5 minutes

      // Cache time determines how long data is kept in cache
      gcTime: 10 * 60 * 1000, // 10 minutes

      // Retry configuration
      retry: (failureCount, error) => {
        // Don't retry on 4xx errors
        if (error instanceof Error && error.message.includes('400')) {
          return false;
        }
        return failureCount < 3;
      },

      // Retry delay with exponential backoff
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
    },

    mutations: {
      // Retry mutations
      retry: 1,
    },
  },
});
```

## Background Sync

### NetInfo Sync Trigger

```typescript
import NetInfo from '@react-native-community/netinfo';

class SyncManager {
  private syncQueue: SyncQueue;

  start() {
    // Sync when connection is restored
    NetInfo.addEventListener((state) => {
      if (state.isConnected) {
        this.processQueue();
      }
    });
  }

  private async processQueue() {
    const pendingItems = await this.syncQueue.getAll();

    for (const item of pendingItems) {
      try {
        await this.syncItem(item);
        await this.syncQueue.remove(item.id);
      } catch (error) {
        // Keep in queue for retry
        console.error('Sync failed:', error);
      }
    }
  }

  private async syncItem(item: SyncTask) {
    switch (item.type) {
      case 'postComment':
        await CommentService.postComment(item.data.text, item.data.postId);
        break;
      // ... other sync types
    }
  }
}
```

### AppState Sync

```typescript
import { AppState } from 'react-native';

class SyncManager {
  start() {
    AppState.addEventListener('change', (nextAppState) => {
      if (nextAppState === 'active') {
        // Sync when app comes to foreground
        this.syncAll();
      }
    });
  }

  private async syncAll() {
    // Sync all pending data
    const isConnected = await NetInfo.fetch().then((s) => s.isConnected);

    if (isConnected) {
      await this.processQueue();
    }
  }
}
```

## Error Handling

### Offline-Specific Errors

```typescript
enum SyncError {
  NoConnection = 'NO_CONNECTION',
  ServerUnavailable = 'SERVER_UNAVAILABLE',
  Conflict = 'CONFLICT',
  Unauthorized = 'UNAUTHORIZED',
}

class SyncException extends Error {
  constructor(
    public code: SyncError,
    message: string,
    public retryable: boolean = true
  ) {
    super(message);
    this.name = 'SyncException';
  }
}

// Usage
throw new SyncException(SyncError.NoConnection, 'No internet connection', true);
```

### User Feedback

```typescript
function handleSyncError(error: Error) {
  if (error instanceof SyncException) {
    switch (error.code) {
      case SyncError.NoConnection:
        showSnackBar('Changes saved. Will sync when online.');
        break;
      case SyncError.ServerUnavailable:
        showSnackBar('Server unavailable. Will retry later.');
        break;
      case SyncError.Conflict:
        showConflictDialog();
        break;
      default:
        showSnackBar('Sync failed. Please try again.');
    }
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
7. **Use TanStack Query** for server state management
8. **Use MMKV or Realm** for local storage (not AsyncStorage for large data)

---

## Resources

**Packages:**
- [@tanstack/react-query](https://tanstack.com/query/latest) - Server state management
- [@react-native-community/netinfo](https://github.com/react-native-netinfo/react-native-netinfo) - Network detection
- [react-native-mmkv](https://github.com/mrousavy/react-native-mmkv) - Fast storage
- [realm](https://www.mongodb.com/realm) - Object database
- [@nozbe/watermelondb](https://github.com/Nozbe/WatermelonDB) - Reactive database

**Examples:**
- See `../examples/offline_examples.tsx`
