//
// Copyright © 2019-Present. Kaleyra S.p.a. All rights reserved.
//

import ReplayKit
import BandyerBroadcastExtension

class SampleHandler: RPBroadcastSampleHandler {

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        BroadcastExtension.instance.start(appGroupIdentifier: Constants.AppGroupIdentifier, setupInfo: setupInfo) { [weak self] error in
            self?.finishBroadcastWithError(error)
        }
    }
    
    override func broadcastPaused() {
        BroadcastExtension.instance.pause()
    }
    
    override func broadcastResumed() {
        BroadcastExtension.instance.resume()
    }
    
    override func broadcastFinished() {
        BroadcastExtension.instance.finish()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        BroadcastExtension.instance.process(sampleBuffer: sampleBuffer, ofType: sampleBufferType)
    }
}
