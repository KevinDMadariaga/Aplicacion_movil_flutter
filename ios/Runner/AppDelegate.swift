import Flutter
import UIKit
import GoogleMaps // Google Maps
import Firebase // Importa Firebase
import FirebaseMessaging // Importa Firebase Messaging

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configura Firebase
    FirebaseApp.configure()

    // Configura Firebase Cloud Messaging
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self

    // Solicitar permisos de notificaciones push
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { _, _ in }
    )
    application.registerForRemoteNotifications()

    // Proporciona la clave de API de Google Maps
    GMSServices.provideAPIKey("AIzaSyDgrGYGf1Sa8xH89KTw2lvsmuhWxYuxkIU")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Registra el token del dispositivo con FCM
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}

// MARK: - Extensiones para Notificaciones
extension AppDelegate: UNUserNotificationCenterDelegate {
  // Maneja la recepción de notificaciones en primer plano
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound, .badge])
  }

  // Maneja la interacción con notificaciones
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}

extension AppDelegate: MessagingDelegate {
  // Obtiene el token FCM
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("FCM Token: \(fcmToken ?? "")")
    // Aquí puedes enviar el token al backend si es necesario
  }
}
