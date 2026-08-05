// LayerTogglePanel — VSP Mobile App
//
// Collapsible panel for toggling map layer visibility.
// Follows high-contrast dark theme tokens.

import 'package:flutter/material.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Panel widget for toggling visibility of individual map layers.
class LayerTogglePanel extends StatefulWidget {
  final Map<String, bool> visibility;
  final void Function(String layerId, bool visible) onToggle;

  LayerTogglePanel({
    super.key,
    required this.visibility,
    required this.onToggle,
  });

  @override
  State<LayerTogglePanel> createState() => _LayerTogglePanelState();
}

class _LayerTogglePanelState extends State<LayerTogglePanel> {
  bool _isExpanded = false;

  List<({String id, String label})> _allLayers(BuildContext context) => [
    (id: 'fairway', label: AppLocalizations.of(context).layerFairway),
    (id: 'green', label: AppLocalizations.of(context).layerGreen),
    (id: 'rough', label: AppLocalizations.of(context).layerRough),
    (id: 'bunker', label: AppLocalizations.of(context).layerBunker),
    (id: 'water', label: AppLocalizations.of(context).layerWater),
    (id: 'penaltyArea', label: AppLocalizations.of(context).layerPenalty),
    (id: 'ob', label: AppLocalizations.of(context).layerOb),
    (id: 'cartPath', label: AppLocalizations.of(context).layerCartPath),
    (id: 'landmark', label: AppLocalizations.of(context).layerLandmarks),
    (id: 'distanceRing100', label: '100m Ring'),
    (id: 'distanceRing150', label: '150m Ring'),
    (id: 'distanceRing200', label: '200m Ring'),
  ];

  int get _visibleCount => widget.visibility.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Layer toggle panel, $_visibleCount of ${_allLayers(context).length} layers visible',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Toggle button
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.layers,
                      size: 20,
                      color: Color(0xFFF8FAFC),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_visibleCount',
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded layer list
            if (_isExpanded) ...[
              const Divider(color: Color(0xFF334155), height: 1),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final layer in _allLayers(context))
                      _LayerToggleRow(
                        id: layer.id,
                        label: layer.label,
                        visible: widget.visibility[layer.id] ?? true,
                        onChanged: (v) => widget.onToggle(layer.id, v),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LayerToggleRow extends StatelessWidget {
  final String id;
  final String label;
  final bool visible;
  final ValueChanged<bool> onChanged;

  const _LayerToggleRow({
    required this.id,
    required this.label,
    required this.visible,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label layer, ${visible ? 'visible' : 'hidden'}',
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!visible),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: visible,
                  onChanged: (v) => onChanged(v ?? !visible),
                  activeColor: const Color(0xFFEA580C),
                  side: const BorderSide(color: Color(0xFF64748B)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: visible
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
