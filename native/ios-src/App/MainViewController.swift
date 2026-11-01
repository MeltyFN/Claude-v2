// App target only.
// Registers the dictation plugin with the app. In Main.storyboard, set the Bridge View Controller's
// Custom Class to "MainViewController" (see native/README.md, step 5).
import Capacitor
import UIKit

class MainViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(SermonDictationPlugin())
    }
}
