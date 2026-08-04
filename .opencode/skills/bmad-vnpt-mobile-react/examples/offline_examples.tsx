// React Native Offline-First Architecture Examples
// See also: ../references/react-native-offline-guide.md

import React, { useState, useEffect } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import NetInfo from '@react-native-community/netinfo';

// ===== Offline Service =====

interface Comment {
  id: string;
  text: string;
  postId: string;
  synced: boolean;
  timestamp: number;
}

class CommentService {
  async postComment(text: string, postId: string): Promise<void> {
    const tempId = `temp_${Date.now()}`;
    const comment: Comment = {
      id: tempId,
      text,
      postId,
      synced: false,
      timestamp: Date.now(),
    };

    // 1. Save locally immediately
    await this.saveToLocal(comment);

    // 2. Sync in background if online
    const isConnected = await this.checkConnectivity();
    if (isConnected) {
      this.syncInBackground(tempId, text, postId);
    } else {
      // Queue for later sync
      await this.queueSync({ type: 'postComment', data: { tempId, text, postId } });
    }
  }

  private async saveToLocal(comment: Comment): Promise<void> {
    // Implementation depends on storage choice
    // AsyncStorage, MMKV, Realm, etc.
  }

  private async checkConnectivity(): Promise<boolean> {
    const state = await NetInfo.fetch();
    return state.isConnected ?? false;
  }

  private async syncInBackground(tempId: string, text: string, postId: string): Promise<void> {
    try {
      const serverComment = await this.apiPostComment(text, postId);
      await this.updateLocal(tempId, { ...serverComment, synced: true });
    } catch (error) {
      await this.updateLocal(tempId, { synced: false, syncError: (error as Error).message });
    }
  }

  private async apiPostComment(text: string, postId: string): Promise<Comment> {
    // API call implementation
    return { id: '1', text, postId, synced: true, timestamp: Date.now() };
  }

  private async updateLocal(id: string, updates: Partial<Comment>): Promise<void> {
    // Update local storage
  }

  private async queueSync(task: SyncTask): Promise<void> {
    // Add to sync queue
  }
}

interface SyncTask {
  type: string;
  data: unknown;
}

// ===== Optimistic UI Hook =====

export function usePostComment() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ text, postId }: { text: string; postId: string }) => {
      const service = new CommentService();
      return service.postComment(text, postId);
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

// ===== Network-Aware Component =====

export function useNetworkStatus(): boolean {
  const [isConnected, setIsConnected] = useState(true);

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener((state) => {
      setIsConnected(state.isConnected ?? false);
    });

    return () => unsubscribe();
  }, []);

  return isConnected;
}

export function NetworkAwareComponent() {
  const isConnected = useNetworkStatus();
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['data'],
    queryFn: fetchData,
  });

  if (isLoading) return <LoadingSpinner />;

  if (error && !isConnected) {
    return <OfflineError onRetry={() => refetch()} />;
  }

  if (error) {
    return <ErrorComponent error={error} onRetry={() => refetch()} />;
  }

  return <DataList data={data} />;
}

// ===== Sync Manager =====

class SyncManager {
  start(): void {
    // Sync when connection is restored
    NetInfo.addEventListener((state) => {
      if (state.isConnected) {
        this.processQueue();
      }
    });

    // Sync when app comes to foreground
    AppState.addEventListener('change', (nextAppState) => {
      if (nextAppState === 'active') {
        this.syncAll();
      }
    });
  }

  private async processQueue(): Promise<void> {
    // Process pending sync tasks
  }

  private async syncAll(): Promise<void> {
    // Sync all pending data
  }
}

// ===== Helper Components =====

function LoadingSpinner(): JSX.Element {
  return <ActivityIndicator size="large" color="#007AFF" />;
}

function OfflineError({ onRetry }: { onRetry: () => void }): JSX.Element {
  return (
    <View>
      <Text>No internet connection</Text>
      <Button title="Retry" onPress={onRetry} />
    </View>
  );
}

function ErrorComponent({ error, onRetry }: { error: unknown; onRetry: () => void }): JSX.Element {
  return (
    <View>
      <Text>Error: {(error as Error).message}</Text>
      <Button title="Retry" onPress={onRetry} />
    </View>
  );
}

function DataList({ data }: { data: unknown[] }): JSX.Element {
  return (
    <FlatList
      data={data}
      renderItem={({ item }) => <Text>{JSON.stringify(item)}</Text>}
      keyExtractor={(item, index) => index.toString()}
    />
  );
}

// ===== Types & Utilities =====

import { FlatList, ActivityIndicator, View, Text, TouchableOpacity } from 'react-native';
import { AppState } from 'react-native';
import { useQuery } from '@tanstack/react-query';

interface ButtonProps {
  title: string;
  onPress: () => void;
}

function Button({ title, onPress }: ButtonProps): JSX.Element {
  return (
    <TouchableOpacity onPress={onPress}>
      <Text>{title}</Text>
    </TouchableOpacity>
  );
}

async function fetchData(): Promise<unknown[]> {
  return [];
}
