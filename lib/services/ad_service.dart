import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static const String gameId = '6078965';
  static const String bannerPlacementId = 'Banner_Android';
  static const String interstitialPlacementId = 'Interstitial_Android';

  static Future<void> init() async {
    await UnityAds.init(
      gameId: gameId,
      testMode: false,
      onComplete: () => debugPrint('Unity Ads Initialization Complete'),
      onFailed: (error, message) =>
          debugPrint('Unity Ads Initialization Failed: $error $message'),
    );
  }

  static void showInterstitialAd() {
    UnityAds.showVideoAd(
      placementId: interstitialPlacementId,
      onComplete: (placementId) => debugPrint('Video Ad Completed: $placementId'),
      onFailed: (placementId, error, message) =>
          debugPrint('Video Ad Failed: $placementId $error $message'),
      onStart: (placementId) => debugPrint('Video Ad Started: $placementId'),
      onClick: (placementId) => debugPrint('Video Ad Clicked: $placementId'),
    );
  }

  static void loadInterstitialAd() {
    UnityAds.load(
      placementId: interstitialPlacementId,
      onComplete: (placementId) => debugPrint('Load Complete: $placementId'),
      onFailed: (placementId, error, message) => debugPrint('Load Failed: $placementId $error $message'),
    );
  }
}
