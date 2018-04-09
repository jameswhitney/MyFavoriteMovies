//
//  LoginViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - LoginViewController: UIViewController

class LoginViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: BorderedButton!
    @IBOutlet weak var debugTextLabel: UILabel!
    @IBOutlet weak var movieImageView: UIImageView!
        
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        configureUI()
        
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Login
    
    @IBAction func loginPressed(_ sender: AnyObject) {
        
        userDidTapView(self)
        
        if usernameTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            debugTextLabel.text = "Username or Password Empty."
        } else {
            setUIEnabled(false)
            
            // Save username and password in Constants struct
            Constants.TMDBParameterValues.Username = usernameTextField.text!
            Constants.TMDBParameterValues.Password = passwordTextField.text!
            /*
                Steps for Authentication...
                https://www.themoviedb.org/documentation/api/sessions
                
                Step 1: Create a request token
                Step 2: Ask the user for permission via the API ("login")
                Step 3: Create a session ID
                
                Extra Steps...
                Step 4: Get the user id ;)
                Step 5: Go to the next view!            
            */
            getRequestToken()
        }
    }
    
    private func completeLogin() {
        performUIUpdatesOnMain {
            self.debugTextLabel.text = ""
            self.setUIEnabled(true)
            let controller = self.storyboard!.instantiateViewController(withIdentifier: "MoviesTabBarController") as! UITabBarController
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: TheMovieDB
    
    private func getRequestToken() {
        
        /* TASK: Get a request token, then store it (appDelegate.requestToken) and login with the token */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Credentials.apiKey
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/authentication/token/new"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            // Check if an error occurs, print error and reset UI
            func displayError(_ error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login Failed: (getRequestToken)"
                }
            }
            // Check if an error was return. If so print the error
            guard (error == nil) else {
                displayError("Error found in request: \(error!)")
                return
            }
            
            // Check if statusCode is a successful 2xx code if not print error
            guard  let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Request returned value outside of 2xx.")
                return
            }
            
            // Check if any data was return. If not print error
            guard let data = data else {
                displayError("No data was returned")
                return
            }
            
            /* 5. Parse the data */
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError("Could not parse JSON: '\(data)'")
                return
            }
            
            // Did TheMovieDB return any errors. If so print them
            if let _ = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int {
                displayError("TheMovieDB returned an error. See '\(Constants.TMDBResponseKeys.StatusCode)' and '\(Constants.TMDBResponseKeys.StatusMessage) in \(parsedResult)'")
                return
            }
            
            // Check if request_token key is in parsedResult. If not print error
            guard let requestToken = parsedResult[Constants.TMDBResponseKeys.RequestToken] as? String else {
                displayError("Key '\(Constants.TMDBResponseKeys.RequestToken)' not found in '\(parsedResult)'")
                return
            }
            
            
            /* 6. Use the data! */
            self.appDelegate.requestToken = requestToken
            self.loginWithToken(self.appDelegate.requestToken!)
    
        }

        /* 7. Start the request */
        task.resume()
    }
    
    private func loginWithToken(_ requestToken: String) {
        
        /* TASK: Login, then get a session id */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Credentials.apiKey,
            Constants.TMDBParameterKeys.RequestToken: requestToken,
            Constants.TMDBParameterKeys.Username: Constants.TMDBParameterValues.Username,
            Constants.TMDBParameterKeys.Password: Constants.TMDBParameterValues.Password
            
        ]
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/authentication/token/validate_with_login"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            // if an error occurs reset UI
            func displayError(_ error: String, debugLabelText: String? = nil) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login Failed (loginWithToken)."
                }
            }
            
            // Check if an error was return. If so print the error
            guard (error == nil) else {
                displayError("Error found in request: \(error!)")
                return
            }
            // Check if statusCode is a successful 2xx code if not print error
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Response status code is not in the 2xx range.")
                return
            }

            
            // Check if data was returned if not print error
            guard let data = data else {
                displayError("No data was returned")
                return
            }
            
            // Try to parse data, catch any error and print error
            let parsedResult: [String:AnyObject]!
            
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError("Could not parse data as JSON: '\(data)'")
                return
            }
            
            // Check if TMDB returned an error. Print error if one is found
            if let _ = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int {
                displayError("TheMovieDB returned an error. See the '\(Constants.TMDBResponseKeys.StatusCode)' and '\(Constants.TMDBResponseKeys.StatusMessage)' in \(parsedResult)")
                return
            }
            
            // Is the "success" key in parsedResult? If not print error
            guard let success = parsedResult[Constants.TMDBResponseKeys.Success] as? Bool, success == true else {
                displayError("Key '\(Constants.TMDBResponseKeys.Success)' not found in \(parsedResult)")
                return
            }
            
            // Save requestToken to AppDelegate and use it to call getSessionID function
            self.getSessionID(self.appDelegate.requestToken!)
        }
        
        // Start request
        task.resume()
    }
    
    private func getSessionID(_ requestToken: String) {
        
        /* TASK: Get a session ID, then store it (appDelegate.sessionID) and get the user's id */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Credentials.apiKey,
            Constants.TMDBParameterKeys.RequestToken: requestToken
        ]
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/authentication/session/new"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            // If error occurs reset UI
            func displayError(_ error: String, debugLabelText: String? = nil) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login Failed: (getSessionID)"
                }
                
            }
            
            // Check if an error was return. If so print the error
            guard (error == nil) else {
                displayError("Error found in request: \(error!)")
                return
            }
            
            // Check if statusCode is a successful 2xx code if not print error
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Request returned a code other than 2xx")
                return
            }
            
            // Check if any data was returned
            guard let data = data else {
                displayError("No data was returned")
                return
            }
            
            /* 5. Parse the data */
            // Try to parse data, catch any error and print error
            let parsedResult: [String:AnyObject]!
            
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError("Could not parse data as JSON: '\(data)'")
                return
            }
            
            // Check if TMDB returned an error. Print error if one is found
            if let _ = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int {
                displayError("TheMovieDB returned an error. See the '\(Constants.TMDBResponseKeys.StatusCode)' and '\(Constants.TMDBResponseKeys.StatusMessage)' in \(parsedResult)")
                return
            }
            
            guard let sessionID = parsedResult[Constants.TMDBResponseKeys.SessionID] as? String else {
                displayError("Key '\(Constants.TMDBResponseKeys.SessionID)' not found in \(parsedResult)")
                return
            }
            
            /* 6. Use the data! */
            // Save sessionID in appDelegate then pass sessionID from appDelegate to getUserID
            self.appDelegate.sessionID = sessionID
            self.getUserID(self.appDelegate.sessionID!)
            
        }
        
        /* 7. Start the request */
        task.resume()
    }
    
    private func getUserID(_ sessionID: String) {
        
        /* TASK: Get the user's ID, then store it (appDelegate.userID) for future use and go to next view! */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Credentials.apiKey,
            Constants.TMDBParameterKeys.SessionID: sessionID
        ]
        
        /* 2/3. Build the URL, Configure the request */
        // Create URL to request account information
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/account"))
        
        /* 4. Make the request */
        // Create task for request
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            // Check for errors and print them. Also reset UI if error is found
            func displayError(_ error: String, debugLabelText: String? = nil) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login Failed (getUserID)"
                }
            }
            
            // Check if an error was return. If so print the error
            guard (error == nil) else {
                displayError("Error found in request: \(error!)")
                return
            }
            
            // Check if statusCode is a successful 2xx code if not print error
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Request returned a code other than 2xx")
                return
            }
            
            // Check that data was returned from request before parsing
            guard let data = data else {
                displayError("No data was returned")
                return
            }
            
            /* 5. Parse the data */
            // Try to parse data, catch any error and print error
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError("Could not parse JSON: \(data)")
                return
            }
            
            // Check if error in JSON returned from TMDB? If so print error
            if let _ = parsedResult![Constants.TMDBResponseKeys.StatusCode] as? Int {
                displayError("The Movie Database returned an error here: \(Constants.TMDBResponseKeys.StatusCode) and here: \(Constants.TMDBResponseKeys.StatusMessage) in \(parsedResult)")
                
            }
            
            // Check for "id" key in parsedResult. If key not present print error
            guard let userID = parsedResult[Constants.TMDBResponseKeys.UserID] as? Int else {
                displayError("Key '\(Constants.TMDBResponseKeys.UserID)' not found in \(parsedResult)")
                return
            }
            
            /* 6. Use the data! */
            // Get data and save it in AppDelegate
            self.appDelegate.userID = userID
            self.completeLogin()
            
            
        }
        /* 7. Start the request */
        task.resume()
    }
}

// MARK: - LoginViewController: UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
            movieImageView.isHidden = true
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
            movieImageView.isHidden = false
        }
    }
    
    @objc func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    @objc func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    private func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(usernameTextField)
        resignIfFirstResponder(passwordTextField)
    }
}

// MARK: - LoginViewController (Configure UI)

private extension LoginViewController {
    
    func setUIEnabled(_ enabled: Bool) {
        usernameTextField.isEnabled = enabled
        passwordTextField.isEnabled = enabled
        loginButton.isEnabled = enabled
        debugTextLabel.text = ""
        debugTextLabel.isEnabled = enabled
        
        // adjust login button alpha
        if enabled {
            loginButton.alpha = 1.0
        } else {
            loginButton.alpha = 0.5
        }
    }
    
    func configureUI() {
        
        // configure background gradient
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [Constants.UI.LoginColorTop, Constants.UI.LoginColorBottom]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.frame
        view.layer.insertSublayer(backgroundGradient, at: 0)
        
        configureTextField(usernameTextField)
        configureTextField(passwordTextField)
    }
    
    func configureTextField(_ textField: UITextField) {
        let textFieldPaddingViewFrame = CGRect(x: 0.0, y: 0.0, width: 13.0, height: 0.0)
        let textFieldPaddingView = UIView(frame: textFieldPaddingViewFrame)
        textField.leftView = textFieldPaddingView
        textField.leftViewMode = .always
        textField.backgroundColor = Constants.UI.GreyColor
        textField.textColor = Constants.UI.BlueColor
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder!, attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])
        textField.tintColor = Constants.UI.BlueColor
        textField.delegate = self
    }
}

// MARK: - LoginViewController (Notifications)

private extension LoginViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
