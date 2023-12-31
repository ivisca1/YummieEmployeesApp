//
//  UIViewControllerExtension.swift
//  RestoranUposleniciAppIsmarVisca
//
//  Created by User on 2. 7. 2023..
//

import UIKit

extension UIViewController {
    
    static var identifier : String {
        return String(describing: self)
    }
    
    static func instantiate() -> Self {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(identifier: identifier) as! Self
    }
    
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func showSpinner(activityIndicator: UIActivityIndicatorView) {
        
        activityIndicator.startAnimating()

        self.view.addSubview(activityIndicator)
            
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
            
        self.view.layoutSubviews()
    }
    
    func stopSpinner(activityIndicator: UIActivityIndicatorView) {
        
        activityIndicator.stopAnimating()
        
        activityIndicator.removeFromSuperview()
    }
}
