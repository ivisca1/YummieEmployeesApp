//
//  RequestReviewViewController.swift
//  RestoranUposleniciAppIsmarVisca
//
//  Created by User on 14. 7. 2023..
//

import UIKit
import MessageUI

class RequestReviewViewController: UIViewController {

    @IBOutlet weak var rejectButton: UIButton!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var phoneNumberLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var nameSurnameLabel: UILabel!
    @IBOutlet weak var detailsView: UIView!
    
    var request : Request!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MyVariables.foodManager.delegate = self

        nameSurnameLabel.text = "\(request.name) \(request.surname)"
        emailLabel.text = request.email
        addressLabel.text = request.address
        phoneNumberLabel.text = request.phoneNumber
        
        acceptButton.layer.cornerRadius = 15
        rejectButton.layer.cornerRadius = 15
        
        detailsView.layer.cornerRadius = 20
    }
    
    override func viewWillAppear(_ animated: Bool) {
        MyVariables.foodManager.delegate = self
    }
    
    @IBAction func rejectButtonPressed(_ sender: UIButton) {
        sender.alpha = 0.7
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            sender.alpha = 1
        }
        if MFMailComposeViewController.canSendMail() {
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = self

            composeVC.setToRecipients([emailLabel.text!])
            composeVC.setSubject("Odgovor na zahtjev za kreiranje profila")
            composeVC.setMessageBody("Vaš zahtjev nije prihvaćen.", isHTML: false)

            self.present(composeVC, animated: true, completion: nil)

        } else {
            print("Cannot send mail")
        }
        showSpinner(activityIndicator: MyVariables.activityIndicator)
        MyVariables.foodManager.rejectRequest(email: request.email)
    }
    
    @IBAction func acceptButtonPressed(_ sender: UIButton) {
        sender.alpha = 0.7
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            sender.alpha = 1
        }
        if MFMailComposeViewController.canSendMail() {
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = self

            composeVC.setToRecipients([emailLabel.text!])
            composeVC.setSubject("Odgovor na zahtjev za kreiranje profila")
            composeVC.setMessageBody("Vaš zahtjev je prihvaćen.", isHTML: false)

            self.present(composeVC, animated: true, completion: nil)

        } else {
            print("Cannot send mail")
        }
        showSpinner(activityIndicator: MyVariables.activityIndicator)
        MyVariables.foodManager.acceptRequest(request: request)
    }
    
}

extension RequestReviewViewController : FoodManagerDelegate {
    func didRejectRequest(_ foodManager: FoodManager) {
        stopSpinner(activityIndicator: MyVariables.activityIndicator)
        MyVariables.shouldRefreshEmployees = true
        navigationController!.view.makeToast("Uspješno odbijen zahtjev!", duration: 2.0, position: .bottom)
        navigationController!.popViewController(animated: true)
    }
    
    func didAcceptRequest(_ foodManager: FoodManager) {
        stopSpinner(activityIndicator: MyVariables.activityIndicator)
        MyVariables.shouldRefreshEmployees = true
        MyVariables.foodManager.logOutLogIn()
        navigationController!.view.makeToast("Uspješno prihvaćen zahtjev!", duration: 2.0, position: .bottom)
        navigationController!.popViewController(animated: true)
    }
    
    func didFetchReservations(_ foodManager: FoodManager) {}
    func didUpdateUser(_ foodManager: FoodManager) {}
    func didFetchOtherEmployees(_ foodManager: FoodManager) {}
    func didTakeOrder(_ foodManager: FoodManager) {}
    func didDeliverOrder(_ foodManager: FoodManager) {}
    func didFindUserForOrder(_ foodManager: FoodManager, user: User?) {}
    func didDownloadUpdatePicture(_ foodManager: FoodManager) {}
    func didFetchOrders(_ foodManager: FoodManager) {}
    func didLogOutUser(_ foodManager: FoodManager) {}
    func didSignInUser(_ foodManager: FoodManager, user: User?) {}
    func didFailWithError(error: String) {}
}

extension RequestReviewViewController : MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
