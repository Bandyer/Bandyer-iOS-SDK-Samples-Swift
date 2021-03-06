//
//  Copyright © 2020 Bandyer. All rights reserved.
//  See LICENSE for licensing information.
//

import UIKit
import Bandyer

class ContactsViewController: UIViewController {
    
    //MARK: Constants
    private let cellIdentifier = "userCellId"
    private let optionsSegueIdentifier = "showOptionsSegue"
    
    //MARK: Outlets and subviews
    
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var callTypeControl: UISegmentedControl!
    @IBOutlet private var callOptionsBarButtonItem: UIBarButtonItem!
    @IBOutlet private var callBarButtonItem: UIBarButtonItem?
    @IBOutlet private var logoutBarButtonItem: UIBarButtonItem!
    @IBOutlet private var userBarButtonItem: UIBarButtonItem!
    
    private var toastView: UIView?
    
    private var callWindow: CallWindow?
    
    var addressBook: AddressBook?
    
    private var selectedContacts: [IndexPath] = []
    private var options: CallOptionsItem = CallOptionsItem()
    private var intent: Intent?
    
    private let callBannerController = CallBannerController()
    
    //MARK: View
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userBarButtonItem.title = UserSession.currentUser
        disableMultipleSelection(false)
        
        //When view loads we register as a client observer, in order to receive notifications about incoming calls received and client state changes.
        BandyerSDK.instance().callClient.add(observer: self, queue: .main)
        
        //When view loads we have to setup custom view controller.
        setupBannerView()
    }
    
    private func setupBannerView() {
        callBannerController.delegate = self
        callBannerController.parentViewController = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        callBannerController.show()
        setupNotificationsCoordinator()

        tableView.backgroundColor = UIColor.customBackground
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        callBannerController.hide()
        disableNotificationsCoordinator()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        //Remember to call viewWillTransitionTo on custom view controller to update UI while rotating.
        callBannerController.viewWillTransition(to: size, withTransitionCoordinator: coordinator)
        
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    //MARK: In-app Notification

    private func setupNotificationsCoordinator() {
        BandyerSDK.instance().notificationsCoordinator?.chatListener = self
        BandyerSDK.instance().notificationsCoordinator?.fileShareListener = self
        BandyerSDK.instance().notificationsCoordinator?.start()
    }

    private func disableNotificationsCoordinator() {
        BandyerSDK.instance().notificationsCoordinator?.stop()
    }

    //MARK: Calls
    
    private func startOutgoingCall() {
        //To start an outgoing call we must create a `StartOutgoingCallIntent` object specifying who we want to call, the type of call we want to be performed, along with any call option.
        
        //Here we create the array containing the "user aliases" we want to contact.
        let aliases = selectedContacts.compactMap { (contactIndex) -> String? in
            addressBook?.contacts[contactIndex.row].alias
        }
        
        //Then we create the intent providing the aliases array (which is a required parameter) along with the type of call we want perform.
        //The record flag specifies whether we want the call to be recorded or not.
        //The maximumDuration parameter specifies how long the call can last.
        //If you provide 0, the call will be created without a maximum duration value.
        //We store the intent for later use, because we can present again the CallViewController with the same call.
        intent = StartOutgoingCallIntent(callees: aliases,
                                         options: CallOptions(callType: options.type,
                                                              recorded: options.record,
                                                              duration: options.maximumDuration))
        
        //Then we trigger a presentation of CallViewController.
        performCallViewControllerPresentation()
    }
    
    private func receiveIncomingCall(call: Call) {
        //When the client detects an incoming call it will notify its observers through this method.
        //Here we are creating an `HandleIncomingCallIntent` object, storing it for later use,
        //then we trigger a presentation of CallViewController.
        intent = HandleIncomingCallIntent(call: call)
        performCallViewControllerPresentation()
    }
    
    //MARK: Enabling / Disabling multiple selection
    
    private func enableMultipleSelection(_ animated: Bool) {
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        
        tableView.setEditing(true, animated: animated)
    }
    
    private func disableMultipleSelection(_ animated: Bool) {
        tableView.allowsMultipleSelection = false
        tableView.allowsMultipleSelectionDuringEditing = false
        
        tableView.setEditing(false, animated: animated)
    }
    
    //MARK: Enabling / Disabling chat button
    
    private func enableChatButtonOnVisibleCells() {
        let cells = tableView.visibleCells as? [ContactTableViewCell]
        
        cells?.forEach { cell in
            UIView.animate(withDuration: 0.3, animations: {
                cell.chatButton.alpha = 1
            }, completion: { _ in
                cell.chatButton.isEnabled = true
            })
        }
    }
    
    private func disableChatButtonOnVisibleCells() {
        let cells = tableView.visibleCells as? [ContactTableViewCell]
        
        cells?.forEach { cell in
            cell.chatButton.isEnabled = false
            UIView.animate(withDuration: 0.3, animations: {
                cell.chatButton.alpha = 0
            })
        }
    }
    
    //MARK: Actions
    @IBAction func callTypeValueChanged(sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            selectedContacts.removeAll()
            disableMultipleSelection(true)
            hideCallButtonFromNavigationBar(animated: true)
            enableChatButtonOnVisibleCells()
        } else {
            enableMultipleSelection(true)
            showCallButtonInNavigationBar(animated: true)
            disableChatButtonOnVisibleCells()
            callBarButtonItem?.isEnabled = false
        }
    }
    
    @IBAction func callBarButtonItemTouched(sender: UIBarButtonItem) {
        startOutgoingCall()
    }
    
    @IBAction func callOptionsBarButtonTouched(sender: UIBarButtonItem) {
        performSegue(withIdentifier: optionsSegueIdentifier, sender: self)
    }
    
    @IBAction func logoutBarButtonTouched(sender: UIBarButtonItem) {
        //When the user sign off, we also close the user session.
        //We highly recommend to close the user session when the end user signs off.
        //Failing to do so, will result in incoming calls being processed by the SDK and wrong user logged in inside our chat sdk.
        //Moreover the previously logged user will appear to the Bandyer platform as she/he is available and ready to receive calls and that user will still receive chat messages.
        
        UserSession.currentUser = nil
        BandyerSDK.instance().closeSession()
        
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: Navigation to other screens
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == optionsSegueIdentifier {
            let controller = segue.destination as? CallOptionsTableViewController
            controller?.options = options
            controller?.delegate = self
        }
    }
    
    //MARK: Present Chat ViewController
    private func presentChat(from notification: ChatNotification) {
        if presentedViewController == nil {
            presentChat(from: self, notification: notification)
        }
    }
    
    private func presentChat(from controller: UIViewController, notification: ChatNotification) {
        guard let intent = OpenChatIntent.openChat(from: notification) else {
            return
        }
        presentChat(from: self, intent: intent)
    }
    
    private func presentChat(from controller: UIViewController, intent: OpenChatIntent) {
        let channelViewController = ChannelViewController()
        channelViewController.delegate = self
        
        //Here we are configuring the channel view controller:
        // if audioButton is true, the channel view controller will show audio button on nav bar;
        // if videoButton is true, the channel view controller will show video button on nav bar;
        // if formatter is set, the default formatter will be overridden.
        // if theme is set, the default theme will be overridden.

        //Let's suppose that you want to change the tertiaryBackgroundColor only inside the ChannelViewController.
        //You can achieve this result by allocate a new instance of the theme and set the tertiaryBackgroundColor property whit the wanted value.
        let theme = Theme()
        theme.tertiaryBackgroundColor = UIColor(red: 204/255, green: 210/255, blue: 226/255, alpha: 1)

        //You can also format the way our SDK displays the user information inside the chat channel page. In this example, the user info will be preceded by an asterisk.

        let configuration = ChannelViewControllerConfiguration(audioButton: true, videoButton: true, formatter: AsteriskFormatter(), theme: theme)
        
        //Otherwise you can use other initializer.
        //let configuration = ChannelViewControllerConfiguration() //Equivalent to ChannelViewControllerConfiguration(audioButton: false, videoButton: false, formatter: nil, theme: nil)
        
        //If no configuration is provided, the default one will be used, the one with nil user info fetcher and showing both of the buttons -> ChannelViewControllerConfiguration(audioButton: true, videoButton: true, formatter: nil, theme: nil)
        channelViewController.configuration = configuration
        
        //Please make sure to set intent after configuration, otherwise the configuration will be not taking in charge.
        channelViewController.intent = intent
        
        controller.present(channelViewController, animated: true)
    }
    
    //MARK: Present Call ViewController
    
    private func performCallViewControllerPresentation() {
        guard let intent = self.intent else {
            return
        }
        
        prepareForCallViewControllerPresentation()
        
        //Here we tell the call window what it should do and we present the CallViewController if there is no another call in progress.
        //Otherwise you should manage the behaviour, for example with a UIAlert warning.
        
        callWindow?.presentCallViewController(for: intent) { [weak self] error in
            guard let error = error else { return }
            guard let self = self else { return }
            
            switch error {
            case let presentationError as CallPresentationError where presentationError.errorCode == CallPresentationErrorCode.anotherCallOnGoing.rawValue:
                self.presentAlert(title: "Warning", message: "Another call ongoing.")
            default:
                self.presentAlert(title: "Error", message: "Impossible to start a call now. Try again later.")
            }
        }
    }
    
    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "Ok", style: .default) { (_) in
            alert.dismiss(animated: true)
        }
        alert.addAction(defaultAction)
        self.present(alert, animated: true)
    }
    
    private func prepareForCallViewControllerPresentation() {
        initCallWindowIfNeeded()
        
        //Here we are configuring the CallViewController instance created from the storyboard.
        //A `CallViewControllerConfiguration` object instance is needed to customize the behaviour and appearance of the view controller.
        let config = CallViewControllerConfiguration()
        
        let filePath = Bundle.main.path(forResource: "SampleVideo_640x360_10mb", ofType: "mp4")
        
        guard let path = filePath else {
            fatalError("The fake file for the file capturer could not be found")
        }
        
        //This url points to a sample mp4 video in the app bundle used only if the application is run in the simulator.
        let url = URL(fileURLWithPath: path)
        config.fakeCapturerFileURL = url

        //Let's suppose that you want to change the navBarTitleFont only inside the CallViewController.
        //You can achieve this result by allocate a new instance of the theme and set the navBarTitleFont property whit the wanted value.
        let callTheme = Theme()
        callTheme.navBarTitleFont = UIFont.robotoBold.withSize(30)

        config.callTheme = callTheme

        //The same reasoning will let you change the accentColor only inside the Whiteboard view controller.
        let whiteboardTheme = Theme()
        whiteboardTheme.accentColor = UIColor.systemBlue

        config.whiteboardTheme = whiteboardTheme

        //You can also customize the theme only of the Whiteboard text editor view controller.
        let whiteboardTextEditorTheme = Theme()
        whiteboardTextEditorTheme.bodyFont = UIFont.robotoThin.withSize(30)

        config.whiteboardTextEditorTheme = whiteboardTextEditorTheme

        //In the next lines you can see how it's possible to customize the File Sharing view controller theme.
        let fileSharingTheme = Theme()
        //By setting a point size property of the theme you can change the point size of all the medium/large labels.
        fileSharingTheme.mediumFontPointSize = 20
        fileSharingTheme.largeFontPointSize = 40

        config.fileSharingTheme = fileSharingTheme

        //You can also format the way our SDK displays the user information inside the call page. In this example, the user info will be preceded by a percentage.
        config.callInfoTitleFormatter = PercentageFormatter()

        //Here, we set the configuration object created. You must set the view controller configuration object before the view controller
        //view is loaded, otherwise an exception is thrown.
        callWindow?.setConfiguration(config)
    }
    
    private func initCallWindowIfNeeded() {
        //Please remember to reference the call window only once in order to avoid the reset of CallViewController.
        guard callWindow == nil else { return }
        
        //Please be sure to have in memory only one instance of CallWindow, otherwise an exception will be thrown.
        let window: CallWindow
        
        if let instance = CallWindow.instance {
            window = instance
        } else {
            //This will automatically save the new instance inside CallWindow.instance.
            window = CallWindow()
        }
        
        //Remember to subscribe as the delegate of the window. The window  will notify its delegate when it has finished its job.
        window.callDelegate = self
        
        callWindow = window
    }
    
    //MARK: Hide Call ViewController
    
    private func hideCallViewController() {
        callWindow?.isHidden = true
    }
    
    //MARK: StatusBar appearance
    
    private func restoreStatusBarAppearance() {
        let rootNavigationController = navigationController as? ContactsNavigationController
        rootNavigationController?.restoreStatusBarAppearance()
    }
    
    private func setStatusBarAppearanceToLight() {
        let rootNavigationController = navigationController as? ContactsNavigationController
        rootNavigationController?.setStatusBarAppearance(.lightContent)
    }
}

//MARK: Table view data source
extension ContactsViewController: UITableViewDataSource {
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        addressBook?.contacts.count ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ContactTableViewCell else {
            fatalError("Only ContactTableViewCell type is supported")
        }
        
        cell.delegate = self
        
        let contact = addressBook?.contacts[indexPath.row]

        cell.titleLabel.text = contact?.fullName
        cell.subtitleLabel.text = contact?.alias

        if tableView.allowsMultipleSelection {
            cell.chatButton.isEnabled = false
            cell.chatButton.alpha = 0
        } else {
            cell.chatButton.isEnabled = true
            cell.chatButton.alpha = 1
        }
        
        return cell
    }
}

//MARK: Table view delegate
extension ContactsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        bindSelectionOfContact(fromRowAt: indexPath)
        
        if !tableView.allowsMultipleSelection {
            startOutgoingCall()
            tableView.deselectRow(at: indexPath, animated: true)
            selectedContacts.removeAll()
        }
    }

    public func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        guard tableView.allowsMultipleSelection else {
            return indexPath
        }

        bindSelectionOfContact(fromRowAt: indexPath)

        return indexPath
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.customBackground
    }

    private func bindSelectionOfContact(fromRowAt indexPath: IndexPath) {
        if let index = selectedContacts.lastIndex(of: indexPath) {
            selectedContacts.remove(at: index)
        } else {
            selectedContacts.append(indexPath)
        }

        callBarButtonItem?.isEnabled = selectedContacts.count > 1
    }
}

//MARK: Call client observer
extension ContactsViewController: CallClientObserver {
    
    public func callClient(_ client: CallClient, didReceiveIncomingCall call: Call) {
        receiveIncomingCall(call: call)
    }
    
    public func callClientDidStart(_ client: CallClient) {
        view.isUserInteractionEnabled = false
        hideActivityIndicatorFromNavigationBar(animated: true)
        hideToast()
    }
    
    public func callClientDidStartReconnecting(_ client: CallClient) {
        view.isUserInteractionEnabled = false
        showActivityIndicatorInNavigationBar(animated: true)
        showToast(message: "Client is reconnecting, please wait...", color: UIColor.orange)
    }
    
    public func callClientWillResume(_ client: CallClient) {
        view.isUserInteractionEnabled = false
        showActivityIndicatorInNavigationBar(animated: true)
        showToast(message: "Client is resuming, please wait...", color: UIColor.orange)
    }
    
    public func callClientDidResume(_ client: CallClient) {
        view.isUserInteractionEnabled = true
        hideActivityIndicatorFromNavigationBar(animated: true)
        hideToast()
    }
}

//MARK: Activity indicator nav bar
extension ContactsViewController {
    
    func showActivityIndicatorInNavigationBar(animated: Bool) {
        let indicator = UIActivityIndicatorView(style: .gray)
        indicator.startAnimating()
        let item = UIBarButtonItem(customView: indicator)
        navigationItem.setRightBarButton(item, animated: animated)
    }
    
    func hideActivityIndicatorFromNavigationBar(animated: Bool) {
        guard let indicator = navigationItem.rightBarButtonItem?.customView else {
            return
        }
        
        if indicator is UIActivityIndicatorView {
            navigationItem.setRightBarButton(nil, animated: animated)
        }
    }
}

//MARK: Call button nav bar
extension ContactsViewController {
    
    func showCallButtonInNavigationBar(animated: Bool) {
        let item = UIBarButtonItem(image: UIImage(named: "phone"), style: .plain, target: self, action: #selector(callBarButtonItemTouched(sender:)))
        navigationItem.setRightBarButton(item, animated: animated)
        callBarButtonItem = item
    }
    
    func hideCallButtonFromNavigationBar(animated: Bool) {
        navigationItem.setRightBarButton(nil, animated: animated)
    }
}

//MARK: Toast
extension ContactsViewController {
    
    func showToast(message: String, color: UIColor) {
        hideToast()
        
        let container = UIView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = color
        
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.black
        label.font = UIFont.boldSystemFont(ofSize: 7)
        label.text = message
        
        container.addSubview(label)
        view.addSubview(container)
        toastView = container
        
        let constraints = [label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                           label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                           container.topAnchor.constraint(equalTo: tableView.topAnchor),
                           container.leftAnchor.constraint(equalTo: view.leftAnchor),
                           container.rightAnchor.constraint(equalTo: view.rightAnchor),
                           container.heightAnchor.constraint(equalToConstant: 16)]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    func hideToast() {
        toastView?.removeFromSuperview()
    }
}

//MARK: Call options controller delegate
extension ContactsViewController: CallOptionsTableViewControllerDelegate {
    func controllerDidUpdateOptions(_ controller: CallOptionsTableViewController) {
        options = controller.options
    }
}

//MARK: Call window delegate
extension ContactsViewController: CallWindowDelegate {
    func callWindowDidFinish(_ window: CallWindow) {
        hideCallViewController()
    }
    
    func callWindow(_ window: CallWindow, openChatWith intent: OpenChatIntent) {
        hideCallViewController()
        presentChat(from: self, intent: intent)
    }
}

//MARK: Channel view controller delegate
extension ContactsViewController: ChannelViewControllerDelegate {
    func channelViewControllerDidFinish(_ controller: ChannelViewController) {
        controller.dismiss(animated: true)
    }
    
    func channelViewController(_ controller: ChannelViewController, didTapAudioCallWith users: [String]) {
        dismiss(channelViewController: controller, presentCallViewControllerWith: users, type: .audioUpgradable)
    }
    
    func channelViewController(_ controller: ChannelViewController, didTapVideoCallWith users: [String]) {
        dismiss(channelViewController: controller, presentCallViewControllerWith: users, type: .audioVideo)
    }
    
    private func dismiss(channelViewController: ChannelViewController, presentCallViewControllerWith callees: [String], type: CallType) {
        let presentedChannelVC = presentedViewController as? ChannelViewController
        
        if presentedChannelVC != nil {
            channelViewController.dismiss(animated: true) { [weak self] in
                self?.intent = StartOutgoingCallIntent(callees: callees, options: CallOptions(callType: type))
                self?.performCallViewControllerPresentation()
            }
            return
        }
        
        intent = StartOutgoingCallIntent(callees: callees, options: CallOptions(callType: type))
        performCallViewControllerPresentation()
    }
}

//MARK: Call Banner Controller delegate
extension ContactsViewController: CallBannerControllerDelegate {
    func callBannerControllerDidTouchBanner(_ controller: CallBannerController) {
        //Please remember to override the current call intent with the one saved inside call window.
        intent = callWindow?.intent
        performCallViewControllerPresentation()
    }
    
    func callBannerControllerWillHideBanner(_ controller: CallBannerController) {
        restoreStatusBarAppearance()
    }
    
    func callBannerControllerWillShowBanner(_ controller: CallBannerController) {
        setStatusBarAppearanceToLight()
    }
}

//MARK: Contact table view cell delegate
extension ContactsViewController: ContactTableViewCellDelegate {
    
    func contactTableViewCell(_ cell: ContactTableViewCell, didTouch chatButton: UIButton, withCounterpart aliasId: String) {
        let intent = OpenChatIntent.openChat(with: aliasId)
        presentChat(from: self, intent: intent)
    }
}


//MARK: In App file share notification touch listener delegate
extension ContactsViewController: InAppChatNotificationTouchListener {
    func onTouch(_ notification: ChatNotification) {
        if let callWindow = self.callWindow, !callWindow.isHidden {
            callWindow.isHidden = true
        }

        if presentedViewController is ChannelViewController {
            presentedViewController?.dismiss(animated: true) { [weak self] in
                self?.presentChat(from: notification)
            }
        } else {
            presentChat(from: notification)
        }
    }
}

//MARK: In App file share notification touch listener delegate
extension ContactsViewController: InAppFileShareNotificationTouchListener {
    func onTouch(_ notification: FileShareNotification) {
        callWindow?.presentCallViewController(for: OpenDownloadsIntent())
    }
}
