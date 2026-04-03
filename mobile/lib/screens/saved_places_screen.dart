import 'package:flutter/material.dart';
import '../main.dart';
import '../core/api.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});
  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  List<Map<String, dynamic>> _places = [];

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'home': return Icons.home_rounded;
      case 'work': return Icons.work_rounded;
      default: return Icons.place_rounded;
    }
  }

  Future<void> _loadPlaces() async {
    try {
      final data = await Api.getFavoritePlaces();
      if (!mounted) return;
      setState(() {
        _places = (data as List<dynamic>).map((p) => {
          "id": p['id']?.toString() ?? '',
          "name": p['label'] ?? p['name'] ?? 'Place',
          "address": p['address'] ?? '',
          "icon": _iconFor(p['label']?.toString().toLowerCase()),
          "type": p['label']?.toString().toLowerCase() ?? 'other',
        }).toList();
        if (_places.isEmpty) {
          _places = [
            {"id": "0", "name": "Home", "address": "Add your home address", "icon": Icons.home_rounded, "type": "home"},
            {"id": "0", "name": "Work", "address": "Add your work address", "icon": Icons.work_rounded, "type": "work"},
          ];
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _places = [
          {"id": "0", "name": "Home", "address": "Add your home address", "icon": Icons.home_rounded, "type": "home"},
          {"id": "0", "name": "Work", "address": "Add your work address", "icon": Icons.work_rounded, "type": "work"},
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FambaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        title: const Text("Saved Places"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPlaceSheet(context),
        backgroundColor: FambaColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "Add place",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _places.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _places.length,
              itemBuilder: (context, index) {
                return _buildPlaceCard(_places[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FambaColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline_rounded,
                size: 40,
                color: FambaColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "No saved places yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: FambaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Save your frequent destinations for quicker booking",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: FambaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    return Dismissible(
      key: Key(place['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: FambaColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete place?"),
            content: Text("Remove ${place['name']} from saved places?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  "Delete",
                  style: TextStyle(color: FambaColors.error),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        setState(() {
          _places.removeWhere((p) => p['id'] == place['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${place['name']} removed"),
            backgroundColor: FambaColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: "Undo",
              textColor: FambaColors.primary,
              onPressed: () {
                setState(() => _places.add(place));
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showEditPlaceSheet(context, place),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getPlaceColor(place['type']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      place['icon'] as IconData,
                      color: _getPlaceColor(place['type']),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: FambaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          place['address'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: FambaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getPlaceColor(String type) {
    switch (type) {
      case 'home':
        return FambaColors.primary;
      case 'work':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  void _showAddPlaceSheet(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String selectedType = 'other';
    IconData selectedIcon = Icons.place_rounded;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Add new place",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Type selector
                  Row(
                    children: [
                      _typeChip(
                        icon: Icons.home_rounded,
                        label: "Home",
                        selected: selectedType == 'home',
                        onTap: () => setSheetState(() {
                          selectedType = 'home';
                          selectedIcon = Icons.home_rounded;
                          if (nameController.text.isEmpty) {
                            nameController.text = "Home";
                          }
                        }),
                      ),
                      const SizedBox(width: 10),
                      _typeChip(
                        icon: Icons.work_rounded,
                        label: "Work",
                        selected: selectedType == 'work',
                        onTap: () => setSheetState(() {
                          selectedType = 'work';
                          selectedIcon = Icons.work_rounded;
                          if (nameController.text.isEmpty) {
                            nameController.text = "Work";
                          }
                        }),
                      ),
                      const SizedBox(width: 10),
                      _typeChip(
                        icon: Icons.place_rounded,
                        label: "Other",
                        selected: selectedType == 'other',
                        onTap: () => setSheetState(() {
                          selectedType = 'other';
                          selectedIcon = Icons.place_rounded;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Place name",
                      hintText: "e.g., Gym, Mom's house",
                      filled: true,
                      fillColor: FambaColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: "Address",
                      hintText: "Search or enter address",
                      filled: true,
                      fillColor: FambaColors.background,
                      prefixIcon: Icon(Icons.search_rounded, color: FambaColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty && addressController.text.isNotEmpty) {
                          setState(() {
                            _places.add({
                              "id": DateTime.now().millisecondsSinceEpoch.toString(),
                              "name": nameController.text,
                              "address": addressController.text,
                              "icon": selectedIcon,
                              "type": selectedType,
                            });
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("${nameController.text} saved!"),
                              backgroundColor: FambaColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: const Text("Save place"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditPlaceSheet(BuildContext context, Map<String, dynamic> place) {
    final nameController = TextEditingController(text: place['name']);
    final addressController = TextEditingController(text: place['address']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Edit place",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _places.removeWhere((p) => p['id'] == place['id']);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("${place['name']} deleted"),
                          backgroundColor: FambaColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    icon: Icon(Icons.delete_rounded, color: FambaColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Place name",
                  filled: true,
                  fillColor: FambaColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: "Address",
                  filled: true,
                  fillColor: FambaColors.background,
                  prefixIcon: Icon(Icons.search_rounded, color: FambaColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      final index = _places.indexWhere((p) => p['id'] == place['id']);
                      if (index != -1) {
                        _places[index]['name'] = nameController.text;
                        _places[index]['address'] = addressController.text;
                      }
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Place updated!"),
                        backgroundColor: FambaColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: const Text("Save changes"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _typeChip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? FambaColors.primary.withOpacity(0.1) : FambaColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? FambaColors.primary : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? FambaColors.primary : FambaColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? FambaColors.primary : FambaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

