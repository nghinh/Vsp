// Flutter Performance Optimization Examples
// See also: ../references/flutter-performance.md

/// Good: Compile-time constant
const goodText = Text('Hello');

/// Bad: Rebuilt every render
final badText = Text('Hello');

/// Good: Virtualized list for long data
class VirtualizedListExample extends StatelessWidget {
  final List<Item> items;

  const VirtualizedListExample({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => ItemCard(items[index]),
    );
  }
}

/// Bad: All items built at once
class NonVirtualizedListExample extends StatelessWidget {
  final List<Item> items;

  const NonVirtualizedListExample({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) => ItemCard(item)).toList(),
    );
  }
}

/// Good: Use RepaintBoundary for expensive widgets
class ExpensiveWidgetExample extends StatelessWidget {
  const ExpensiveWidgetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ExpensiveWidget(),
    );
  }
}

/// Good: Use keys to preserve state and avoid rebuilds
class ListWithKeysExample extends StatelessWidget {
  final List<Item> items;

  const ListWithKeysExample({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ItemCard(
          key: ValueKey(items[index].id), // Preserve state
          item: items[index],
        );
      },
    );
  }
}

// Helper classes for examples
class Item {
  final String id;
  Item({required this.id});
}

class ItemCard extends StatelessWidget {
  final Item item;
  const ItemCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(child: Text(item.id));
  }
}

class ExpensiveWidget extends StatelessWidget {
  const ExpensiveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      color: Colors.blue,
    );
  }
}
