import Flutter
import UIKit
import GoogleMaps // 구글 지도 임포트

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String,
            !apiKey.isEmpty,
            !apiKey.contains("$(")
        {
            GMSServices.provideAPIKey(apiKey)
        } else {
            debugPrint("Google Maps API key is not configured.")
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RunLiveActivityPlugin") {
            RunLiveActivityPlugin.register(with: registrar)
        }
    }
}
