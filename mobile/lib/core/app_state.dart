import 'package:flutter/foundation.dart';
class AppState extends ChangeNotifier {
  String riderName = "Tanatswa";
  String? activeJobId;
  void setJob(String id) { activeJobId = id; notifyListeners(); }
}
