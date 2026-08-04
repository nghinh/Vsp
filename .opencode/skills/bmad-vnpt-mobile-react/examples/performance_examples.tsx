// React Native Performance Optimization Examples
// See also: ../references/react-native-performance.md

import React, { useMemo, useCallback, memo } from 'react';
import { FlatList, StyleSheet, View, Text } from 'react-native';

// ✅ Good: Memoized component
export const ItemCard = memo(({ item, onPress }: ItemCardProps) => {
  return (
    <View style={styles.card}>
      <Text>{item.name}</Text>
    </View>
  );
});

interface ItemCardProps {
  item: { id: string; name: string };
  onPress: (id: string) => void;
}

// ✅ Good: FlatList with virtualization
export function OptimizedList({ items, onPress }: OptimizedListProps) {
  return (
    <FlatList
      data={items}
      renderItem={({ item }) => <ItemCard item={item} onPress={onPress} />}
      keyExtractor={(item) => item.id}
      initialNumToRender={10}
      maxToRenderPerBatch={10}
      windowSize={5}
      removeClippedSubviews={true}
    />
  );
}

interface OptimizedListProps {
  items: Array<{ id: string; name: string }>;
  onPress: (id: string) => void;
}

// ❌ Bad: ScrollView renders all items
export function NonOptimizedList({ items, onPress }: OptimizedListProps) {
  return (
    <View>
      {items.map((item) => (
        <ItemCard key={item.id} item={item} onPress={onPress} />
      ))}
    </View>
  );
}

// ✅ Good: Memoized expensive computation
export function SortedList({ items }: { items: Array<{ name: string }> }) {
  const sortedItems = useMemo(
    () => [...items].sort((a, b) => a.name.localeCompare(b.name)),
    [items]
  );

  return (
    <FlatList
      data={sortedItems}
      renderItem={({ item }) => <Text>{item.name}</Text>}
      keyExtractor={(item, index) => index.toString()}
    />
  );
}

// ✅ Good: Memoized callback
export function ButtonWithCallback({ onPress }: { onPress: () => void }) {
  const handlePress = useCallback(() => {
    onPress();
  }, [onPress]);

  return (
    <View style={styles.button} onTouchEnd={handlePress}>
      <Text>Press me</Text>
    </View>
  );
}

// ✅ Good: Memoized styles
const styles = StyleSheet.create({
  card: {
    padding: 16,
    margin: 8,
    backgroundColor: 'white',
    borderRadius: 8,
  },
  button: {
    padding: 12,
    backgroundColor: '#007AFF',
    borderRadius: 6,
  },
});
