/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import AVFoundation
import GoogleInteractiveMediaAds
import UIKit

class ViewController: UIViewController, IMAAdsLoaderDelegate, IMAAdsManagerDelegate {
  static let ContentURLString =
    "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"  //NOLINT
    static let singleAd:String = "https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/single_ad_samples&ciu_szs=300x250&impl=s&gdfp_req=1&env=vp&output=vast&unviewed_position_start=1&cust_params=deployment%3Ddevsite%26sample_ct%3Dlinear&correlator="
    var AdTagURLString:String =
    "https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/single_ad_samples&ciu_szs=300x250&impl=s&gdfp_req=1&env=vp&output=vast&unviewed_position_start=1&cust_params=deployment%3Ddevsite%26sample_ct%3Dlinear&correlator="  //NOLINT
    
    

  var adsLoader: IMAAdsLoader!
  var adDisplayContainer: IMAAdDisplayContainer!
  var adsManager: IMAAdsManager!
  var contentPlayhead: IMAAVPlayerContentPlayhead?
  var playerViewController: AVPlayerViewController!
  var adBreakActive = false

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = UIColor.black
    setUpContentPlayer()
    setUpAdsLoader()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.AdTagURLString = ViewController.singleAd
    requestAds()
  }

  func setUpContentPlayer() {
    // Load AVPlayer with path to our content.
    let contentURL = URL(string: ViewController.ContentURLString)!
    let player = AVPlayer(url: contentURL)
    playerViewController = AVPlayerViewController()
    playerViewController.player = player

    // Set up our content playhead and contentComplete callback.
    contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: player)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(ViewController.contentDidFinishPlaying(_:)),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: player.currentItem)

    showContentPlayer()
  }

  func showContentPlayer() {
    self.addChild(playerViewController)
    playerViewController.view.frame = self.view.bounds
    self.view.insertSubview(playerViewController.view, at: 0)
    playerViewController.didMove(toParent: self)
  }

  func hideContentPlayer() {
    // The whole controller needs to be detached so that it doesn't capture resume
    // events from the remote and play content underneath the ad.
    playerViewController.willMove(toParent: nil)
    playerViewController.view.removeFromSuperview()
    playerViewController.removeFromParent()
  }

  func setUpAdsLoader() {
    let settings:IMASettings = IMASettings()
//    settings.autoPlayAdBreaks = false
    adsLoader = IMAAdsLoader(settings: settings)
    adsLoader.delegate = self
  }

  func requestAds() {
    // Create ad display container for ad rendering.
    adDisplayContainer = IMAAdDisplayContainer(adContainer: self.view, viewController: self)
    // Create an ad request with our ad tag, display container, and optional user context.
    let request = IMAAdsRequest(
      adTagUrl: self.AdTagURLString,
      adDisplayContainer: adDisplayContainer,
      contentPlayhead: contentPlayhead,
      userContext: nil)

    adsLoader.requestAds(with: request)
  }

  @objc func contentDidFinishPlaying(_ notification: Notification) {
    adsLoader.contentComplete()
  }

  // MARK: - UIFocusEnvironment

  override var preferredFocusEnvironments: [UIFocusEnvironment] {
    if adBreakActive, let adFocusEnvironment = adDisplayContainer?.focusEnvironment {
      // Send focus to the ad display container during an ad break.
      return [adFocusEnvironment]
    } else {
      // Send focus to the content player otherwise.
      return [playerViewController]
    }
  }

  // MARK: - IMAAdsLoaderDelegate
  func adsLoader(_ loader: IMAAdsLoader!, adsLoadedWith adsLoadedData: IMAAdsLoadedData!) {
    // Grab the instance of the IMAAdsManager and set ourselves as the delegate.
    adsManager = adsLoadedData.adsManager
    adsManager.delegate = self
    let adsRenderingSettings = IMAAdsRenderingSettings()
    adsRenderingSettings.playAdsAfterTime = 100
    adsManager?.initialize(with: adsRenderingSettings)
  }

  func adsLoader(_ loader: IMAAdsLoader!, failedWith adErrorData: IMAAdLoadingErrorData!) {
    print("Error loading ads: \(adErrorData.adError.message)")
    showContentPlayer()
    playerViewController.player?.play()
  }

  // MARK: - IMAAdsManagerDelegate

  func adsManager(_ adsManager: IMAAdsManager!, didReceive event: IMAAdEvent!) {
    print("IMAAdEvent: \(event.typeString)")
    switch event.type {
    case IMAAdEventType.LOADED:
      // Play each ad once it has been loaded.
        print("LOADED")
        adsManager.start()
    case IMAAdEventType.ICON_FALLBACK_IMAGE_CLOSED:
      // Resume playback after the user has closed the dialog.
//      adsManager.resume()
        print("ICON_FALLBACK_IMAGE_CLOSED")
    default:
      break
    }
  }

  func adsManager(_ adsManager: IMAAdsManager!, didReceive error: IMAAdError!) {
    // Fall back to playing content
    print("AdsManager error: \(error.message)")
    showContentPlayer()
    playerViewController.player?.play()
  }
    

  func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager!) {
    // Pause the content for the SDK to play ads.
    playerViewController.player?.pause()
    hideContentPlayer()
    // Trigger an update to send focus to the ad display container.
    adBreakActive = true
    setNeedsFocusUpdate()
  }

  func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager!) {
    resumeContent()
  }
  func resumeContent(){
    // Resume the content since the SDK is done playing ads (at least for now).
    showContentPlayer()
    playerViewController.player?.play()
    // Trigger an update to send focus to the content player.
    adBreakActive = false
    setNeedsFocusUpdate()
  }
}

