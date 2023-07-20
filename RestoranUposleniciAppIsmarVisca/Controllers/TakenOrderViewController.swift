//
//  TakenOrderViewController.swift
//  RestoranUposleniciAppIsmarVisca
//
//  Created by User on 12. 7. 2023..
//

import UIKit
import Toast

class TakenOrderViewController: UIViewController {

    @IBOutlet weak var detailsView: UIView!
    @IBOutlet weak var finishOrderButton: UIButton!
    @IBOutlet weak var totalPriceLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var phoneNumberLabel: UILabel!
    @IBOutlet weak var nameSurnameLabel: UILabel!
    @IBOutlet weak var orderTableView: UITableView!
    
    var order : Order!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MyVariables.foodManager.delegate = self
        
        finishOrderButton.layer.cornerRadius = 15
        
        detailsView.clipsToBounds = true
        detailsView.layer.cornerRadius = 70
        detailsView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        
        MyVariables.foodManager.findUserForOrder(order.email)

        registerCells()
    }
    
    
    @IBAction func finishOrderPressed(_ sender: UIButton) {
        MyVariables.foodManager.deliverOrder()
    }
    
    private func registerCells() {
        orderTableView.register(UINib(nibName: FoodDishViewCell.identifier, bundle: nil), forCellReuseIdentifier: FoodDishViewCell.identifier)
    }
}

extension TakenOrderViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return order.food.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = orderTableView.dequeueReusableCell(withIdentifier: FoodDishViewCell.identifier) as! FoodDishViewCell
        cell.setup(food: MyVariables.foodManager.food.first(where: { $0.name == order.food[indexPath.row].name })!)
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.clear
        cell.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.clear
        cell.selectedBackgroundView = backgroundView
    }
}

extension TakenOrderViewController : FoodManagerDelegate {
    
    func didFindUserForOrder(_ foodManager: FoodManager, user: User?) {
        addressLabel.text = user!.address
        nameSurnameLabel.text = "\(user!.name) \(user!.surname)"
        phoneNumberLabel.text = user!.phoneNumber
        var totalPrice = 0
        for dish in order.food {
            totalPrice = totalPrice + (Int(dish.price.digits) ?? 0)
        }
        totalPriceLabel.text = "\(totalPrice) KM"
    }
    
    func didDeliverOrder(_ foodManager: FoodManager) {
        MyVariables.shouldRefreshOrders = true
        navigationController!.view.makeToast("Uspješno završena narudžba", duration: 2.0, position: .bottom)
        navigationController!.popViewController(animated: true)
    }
    
    func didFetchReservations(_ foodManager: FoodManager) {}
    func didRejectRequest(_ foodManager: FoodManager) {}
    func didAcceptRequest(_ foodManager: FoodManager) {}
    func didFetchOtherEmployees(_ foodManager: FoodManager) {}
    func didTakeOrder(_ foodManager: FoodManager) {}
    func didUpdateUser(_ foodManager: FoodManager) {}
    func didDownloadUpdatePicture(_ foodManager: FoodManager) {}
    func didFetchOrders(_ foodManager: FoodManager) {}
    func didLogOutUser(_ foodManager: FoodManager) {}
    func didSignInUser(_ foodManager: FoodManager, user: User?) {}
    func didFailWithError(error: String) {}
}
