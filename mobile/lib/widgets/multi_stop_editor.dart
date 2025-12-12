import 'package:flutter/material.dart';
import '../main.dart';

class Waypoint {
  String address;
  double? lat;
  double? lng;
  int order;

  Waypoint({
    required this.address,
    this.lat,
    this.lng,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'lat': lat,
        'lng': lng,
        'order': order,
      };
}

class MultiStopEditor extends StatefulWidget {
  final List<Waypoint> waypoints;
  final Function(List<Waypoint>) onChanged;
  final int maxStops;

  const MultiStopEditor({
    super.key,
    required this.waypoints,
    required this.onChanged,
    this.maxStops = 3,
  });

  @override
  State<MultiStopEditor> createState() => _MultiStopEditorState();
}

class _MultiStopEditorState extends State<MultiStopEditor> {
  late List<Waypoint> _stops;
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _stops = List.from(widget.waypoints);
    for (var stop in _stops) {
      _controllers.add(TextEditingController(text: stop.address));
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addStop() {
    if (_stops.length >= widget.maxStops) return;
    
    setState(() {
      final newStop = Waypoint(address: '', order: _stops.length);
      _stops.add(newStop);
      _controllers.add(TextEditingController());
    });
    widget.onChanged(_stops);
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      _controllers[index].dispose();
      _controllers.removeAt(index);
      // Reorder
      for (int i = 0; i < _stops.length; i++) {
        _stops[i].order = i;
      }
    });
    widget.onChanged(_stops);
  }

  void _updateStop(int index, String address) {
    _stops[index].address = address;
    widget.onChanged(_stops);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Stops',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_stops.length}/${widget.maxStops} stops',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to ${widget.maxStops} stops along your route (+\$0.50 each)',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Stops list
          ..._stops.asMap().entries.map((e) => _stopField(e.key)),

          // Add stop button
          if (_stops.length < widget.maxStops)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: _addStop,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FambaColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FambaColors.primary.withOpacity(0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: FambaColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Add stop',
                        style: TextStyle(
                          color: FambaColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _stops.isEmpty ? 'No stops' : 'Done (${_stops.length} stops)',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Stop indicator
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (index < _stops.length - 1)
                Container(
                  width: 2,
                  height: 20,
                  color: Colors.grey.shade300,
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Input field
          Expanded(
            child: TextField(
              controller: _controllers[index],
              onChanged: (v) => _updateStop(index, v),
              decoration: InputDecoration(
                hintText: 'Stop ${index + 1} address',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeStop(index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Compact display of stops
class StopsDisplay extends StatelessWidget {
  final List<Waypoint> stops;
  final VoidCallback? onTap;

  const StopsDisplay({
    super.key,
    required this.stops,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FambaColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_location_alt_outlined,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Add stops',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.route,
              size: 16,
              color: Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              '${stops.length} stop${stops.length > 1 ? 's' : ''} (+\$${(stops.length * 0.5).toStringAsFixed(2)})',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

