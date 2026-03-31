import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:famba_driver/core/driver_state.dart';
import 'package:famba_driver/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RideRequest.fromJson', () {
    test('parses expected fields', () {
      final r = RideRequest.fromJson({
        'id': 'r1',
        'rider_name': 'Alex',
        'pickup_text': 'A',
        'drop_text': 'B',
        'fare_usd': 10.0,
        'distance_km': 3.5,
        'eta_min': 7,
        'pickup_lat': 1.0,
        'pickup_lng': 2.0,
        'drop_lat': 3.0,
        'drop_lng': 4.0,
      });
      expect(r.id, 'r1');
      expect(r.riderName, 'Alex');
      expect(r.pickup, 'A');
      expect(r.dropoff, 'B');
      expect(r.fare, 10.0);
      expect(r.distance, 3.5);
      expect(r.etaMinutes, 7);
      expect(r.pickupLat, 1.0);
      expect(r.pickupLng, 2.0);
      expect(r.dropLat, 3.0);
      expect(r.dropLng, 4.0);
    });
  });

  group('DeliveryRequest.fromJson', () {
    test('parses expected fields', () {
      final d = DeliveryRequest.fromJson({
        'id': 'd1',
        'restaurant_name': 'Cafe',
        'restaurant_address': 'Street 1',
        'customer_name': 'Sam',
        'delivery_address': 'Street 2',
        'total': 25.0,
        'restaurant_lat': 5.0,
        'restaurant_lng': 6.0,
        'delivery_lat': 7.0,
        'delivery_lng': 8.0,
        'items': [
          {'name': 'x', 'qty': 1},
        ],
      });
      expect(d.orderId, 'd1');
      expect(d.restaurantName, 'Cafe');
      expect(d.restaurantAddress, 'Street 1');
      expect(d.customerName, 'Sam');
      expect(d.deliveryAddress, 'Street 2');
      expect(d.totalAmount, 25.0);
      expect(d.itemCount, 1);
      expect(d.items.length, 1);
      expect(d.restaurantLat, 5.0);
      expect(d.restaurantLng, 6.0);
      expect(d.deliveryLat, 7.0);
      expect(d.deliveryLng, 8.0);
    });
  });

  group('DriverState — status', () {
    late DriverState state;

    setUp(() => state = DriverState());

    test('goOnline / goOffline / getters', () {
      expect(state.status, DriverStatus.offline);
      expect(state.isOnline, false);
      expect(state.isBusy, false);

      state.goOnline();
      expect(state.status, DriverStatus.online);
      expect(state.isOnline, true);
      expect(state.isOnTrip, false);
      expect(state.isOnDelivery, false);

      state.goOffline();
      expect(state.status, DriverStatus.offline);
      expect(state.isOnline, false);
    });

    test('toggleOnline toggles between offline and online only', () {
      state.toggleOnline();
      expect(state.status, DriverStatus.online);
      state.toggleOnline();
      expect(state.status, DriverStatus.offline);

      state.goOnline();
      state.receiveRequest(_sampleRide());
      state.acceptRide();
      expect(state.status, DriverStatus.onTrip);
      state.toggleOnline();
      expect(state.status, DriverStatus.onTrip);
    });
  });

  group('DriverState — auth', () {
    late DriverState state;

    setUp(() => state = DriverState());

    test('setAuth sets fields and isLoggedIn', () {
      expect(state.isLoggedIn, false);
      state.setAuth(
        driverId: 'd1',
        name: 'Driver One',
        phone: '+123',
        accessToken: 'tok',
      );
      expect(state.isLoggedIn, true);
      expect(state.driverId, 'd1');
      expect(state.driverName, 'Driver One');
      expect(state.phone, '+123');
      expect(state.accessToken, 'tok');
    });

    test('logout clears auth and resets ride/delivery state', () {
      state.setAuth(
        driverId: 'd1',
        name: 'N',
        phone: 'p',
        accessToken: 't',
      );
      state.goOnline();
      state.receiveRequest(_sampleRide());
      state.acceptRide();

      state.logout();
      expect(state.isLoggedIn, false);
      expect(state.driverId, isNull);
      expect(state.accessToken, isNull);
      expect(state.status, DriverStatus.offline);
      expect(state.activeRide, isNull);
      expect(state.currentRequest, isNull);
      expect(state.rideStatus, 'idle');
      expect(state.deliveryStatus, 'idle');
    });
  });

  group('DriverState — ride lifecycle', () {
    late DriverState state;

    setUp(() => state = DriverState());

    test('receiveRequest → acceptRide → arrivedAtPickup → startRide → completeRide', () {
      final req = _sampleRide();
      state.receiveRequest(req);
      expect(state.currentRequest, isNotNull);
      expect(state.currentRequest!.id, req.id);
      expect(state.activeRide, isNull);

      state.acceptRide();
      expect(state.currentRequest, isNull);
      expect(state.activeRide, isNotNull);
      expect(state.status, DriverStatus.onTrip);
      expect(state.rideStatus, 'accepted');

      state.arrivedAtPickup();
      expect(state.rideStatus, 'arrived');

      state.startRide();
      expect(state.rideStatus, 'riding');

      final fare = state.activeRide!.fare;
      state.completeRide();
      expect(state.activeRide, isNull);
      expect(state.status, DriverStatus.online);
      expect(state.rideStatus, 'idle');
      expect(state.todayTrips, 1);
      expect(state.todayEarnings, closeTo(fare * 0.85, 0.001));
      expect(state.completedTrips.length, 1);
      expect(state.completedTrips.first['rider'], req.riderName);
    });

    test('declineRide clears pending request', () {
      state.receiveRequest(_sampleRide());
      state.declineRide();
      expect(state.currentRequest, isNull);
    });

    test('cancelRide clears active ride', () {
      state.receiveRequest(_sampleRide());
      state.acceptRide();
      state.cancelRide();
      expect(state.activeRide, isNull);
      expect(state.status, DriverStatus.online);
      expect(state.rideStatus, 'idle');
    });
  });

  group('DriverState — delivery lifecycle', () {
    late DriverState state;

    setUp(() => state = DriverState());

    test('receiveDeliveryRequest → accept → restaurant → pickup → delivering → complete', () {
      final del = _sampleDelivery();
      state.receiveDeliveryRequest(del);
      expect(state.currentDeliveryRequest, isNotNull);
      expect(state.activeDelivery, isNull);

      state.acceptDelivery();
      expect(state.currentDeliveryRequest, isNull);
      expect(state.activeDelivery, isNotNull);
      expect(state.status, DriverStatus.onDelivery);
      expect(state.deliveryStatus, 'accepted');

      state.arrivedAtRestaurant();
      expect(state.deliveryStatus, 'at_restaurant');

      state.pickedUpOrder();
      expect(state.deliveryStatus, 'picked_up');

      state.startDelivering();
      expect(state.deliveryStatus, 'delivering');

      final total = state.activeDelivery!.totalAmount;
      state.completeDelivery();
      expect(state.activeDelivery, isNull);
      expect(state.status, DriverStatus.online);
      expect(state.deliveryStatus, 'idle');
      expect(state.todayDeliveries, 1);
      expect(state.todayEarnings, closeTo(total * 0.15, 0.001));
    });

    test('declineDelivery clears pending delivery request', () {
      state.receiveDeliveryRequest(_sampleDelivery());
      state.declineDelivery();
      expect(state.currentDeliveryRequest, isNull);
    });

    test('cancelDelivery clears active delivery', () {
      state.receiveDeliveryRequest(_sampleDelivery());
      state.acceptDelivery();
      state.cancelDelivery();
      expect(state.activeDelivery, isNull);
      expect(state.status, DriverStatus.online);
      expect(state.deliveryStatus, 'idle');
    });
  });

  group('DriverState — earnings, rating, location', () {
    late DriverState state;

    setUp(() => state = DriverState());

    test('updateRating', () {
      state.updateRating(4.2);
      expect(state.rating, 4.2);
    });

    test('updateEarnings', () {
      state.updateEarnings(120.5, 4);
      expect(state.todayEarnings, 120.5);
      expect(state.todayTrips, 4);
    });

    test('updateLocation', () {
      state.updateLocation(-18.0, 32.0);
      expect(state.lat, -18.0);
      expect(state.lng, 32.0);
    });
  });

  group('Widget tests', () {
    Widget wrapApp() => ChangeNotifierProvider<DriverState>(
          create: (_) => DriverState(),
          child: const FambaDriverApp(),
        );

    testWidgets('app boots — renders without crashing, finds famba on splash', (tester) async {
      await tester.pumpWidget(wrapApp());
      await tester.pump();
      expect(find.text('famba'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Splash schedules a 2.2s timer; advance time so the test does not end with a pending timer.
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
    });

    testWidgets('after splash, navigates to login', (tester) async {
      await tester.pumpWidget(wrapApp());
      await tester.pump();
      expect(find.text('famba'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();

      expect(find.text('Earn on every ride'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
    });
  });
}

RideRequest _sampleRide() => RideRequest.fromJson({
      'id': 'ride-1',
      'rider_name': 'Rider',
      'pickup_text': 'P',
      'drop_text': 'D',
      'fare_usd': 20.0,
      'distance_km': 2.0,
      'eta_min': 5,
    });

DeliveryRequest _sampleDelivery() => DeliveryRequest.fromJson({
      'id': 'ord-1',
      'restaurant_name': 'R',
      'total': 100.0,
      'items': [],
    });
