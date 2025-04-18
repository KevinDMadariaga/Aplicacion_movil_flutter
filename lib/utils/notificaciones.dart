import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificacionLocal {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> mostrarNotificacion({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'canal_llegada_id',
      'Canal de Llegada',
      channelDescription: 'Notifica cuando el conductor esté cerca',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _plugin.show(id, titulo, cuerpo, platformDetails);
  }
}
