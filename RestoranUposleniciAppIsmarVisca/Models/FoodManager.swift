//
//  FoodManager.swift
//  RestoranUposleniciAppIsmarVisca
//
//  Created by User on 1. 7. 2023..
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

protocol FoodManagerDelegate {
    func didFetchReservations(_ foodManager: FoodManager)
    func didRejectRequest(_ foodManager: FoodManager)
    func didAcceptRequest(_ foodManager: FoodManager)
    func didFetchOtherEmployees(_ foodManager: FoodManager)
    func didTakeOrder(_ foodManager: FoodManager)
    func didDeliverOrder(_ foodManager: FoodManager)
    func didFindUserForOrder(_ foodManager: FoodManager, user: User?)
    func didUpdateUser(_ foodManager: FoodManager)
    func didDownloadUpdatePicture(_ foodManager: FoodManager)
    func didFetchOrders(_ foodManager: FoodManager)
    func didLogOutUser(_ foodManager: FoodManager)
    func didSignInUser(_ foodManager: FoodManager, user: User?)
    func didFailWithError(error: String)
}

class FoodManager {
    
    let db = Firestore.firestore()
    
    let storage = Storage.storage()
    
    var delegate : FoodManagerDelegate?
    
    var user : User?
    
    var waitingOrders = [Order]()
    
    var takenOrders = [Order]()
    
    var finishedOrders = [Order]()
    
    var food = [FoodDish]()
    
    var didFetchFoodAlready = false
    
    var image = UIImage(named: "defaultProfilePicture")
    
    var userOrder : User?
    
    var deliveryManOrder : User?
    
    var otherEmployees = [User]()
    
    var userRequests = [Request]()
    
    var reservations = [Reservation]()
    
    var finishedOrdersForUser = [Order]()
    
    var takenOrdersForUser = [Order]()
    
    func fetchFood() {
        self.db.collection("food").getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    if !self.didFetchFoodAlready {
                        for document in querySnapshot!.documents {
                            self.food.append(FoodDish(image: document.data()["image"] as! String, name: document.data()["name"] as! String, price: document.data()["price"] as! String))
                        }
                        self.didFetchFoodAlready = true
                    }
                    if self.user != nil {
                        self.fetchOrders()
                    }
                }
        }
    }
    
    func createUser(userToCreate : User, password: String) {
        self.db.collection("requests").whereField("email", isEqualTo: userToCreate.email)
            .getDocuments() { (querySnapshot, err) in
                if err == nil {
                    if (querySnapshot?.documents.count)! > 0 {
                        let errorMsg = "Već ste poslali zahtjev za kreiranje profila!"
                        self.delegate?.didFailWithError(error: errorMsg)
                    }
                    else {
                        self.db.collection("users").whereField("email", isEqualTo: userToCreate.email)
                            .getDocuments() { (querySnapshot, err) in
                                if err == nil {
                                    if (querySnapshot?.documents.count)! == 0 {
                                        self.createNewRequest(userToCreate, password: password, false, false)
                                    }
                                    else {
                                        let foundUser = querySnapshot?.documents[0]
                                        let isEmployee = foundUser?.data()["isEmployee"] as! Bool
                                        let isCustomer = foundUser?.data()["isCustomer"] as! Bool
                                        if isCustomer && !isEmployee {
                                            self.createNewRequest(userToCreate, password: password, true, false)
                                        } else {
                                            let errorMsg = "Profil sa ovim email-om već postoji!"
                                            self.delegate?.didFailWithError(error: errorMsg)
                                        }
                                    }
                                }
                        }
                    }
                }
        }
    }
    
    private func createNewRequest(_ userToCreate: User, password: String, _ isCustomer: Bool, _ isEmployee: Bool) {
        self.db.collection("requests").document(userToCreate.email).setData([
            "name": userToCreate.name,
            "surname": userToCreate.surname,
            "email": userToCreate.email,
            "address": userToCreate.address,
            "phoneNumber": userToCreate.phoneNumber,
            "orderNumber": 0,
            "isCustomer": isCustomer,
            "isEmployee": isEmployee,
            "isAdmin": false,
            "password": password,
            "status": "Neaktivan"
        ]) { err in
            if let err = err {
                print("Error writing document: \(err)")
            } else {
                print("Document successfully written!")
                self.delegate?.didSignInUser(self, user: userToCreate)
            }
        }
    }
    
    func logInUser(email: String, password: String) {
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password,completion: { result, error in
            if error != nil {
                let errCode = AuthErrorCode(_nsError: error! as NSError)
                var errorMsg = ""
                switch errCode.code {
                case .userNotFound:
                    errorMsg = "Korisnik nije pronađen. Prvo kreirajte profil!"
                case .wrongPassword:
                    errorMsg = "Šifra neispravna!"
                default:
                    errorMsg = "Neuspješan Log In!"
                }
                self.delegate?.didFailWithError(error: errorMsg)
            }
            else {
                self.db.collection("users").whereField("email", isEqualTo: email)
                    .getDocuments() { (querySnapshot, err) in
                        if let err = err {
                            print("Error getting documents: \(err)")
                        } else {
                            let foundUser = querySnapshot?.documents[0]
                            let isEmployee = foundUser?.data()["isEmployee"] as! Bool
                            if isEmployee {
                                self.user = User(name: foundUser?.data()["name"] as! String, surname: foundUser?.data()["surname"] as! String, phoneNumber: foundUser?.data()["phoneNumber"] as! String, email: foundUser?.data()["email"] as! String, address: foundUser?.data()["address"] as! String, orderNumber: foundUser?.data()["orderNumber"] as! Int, isCustomer: foundUser?.data()["isCustomer"] as! Bool, isEmployee: foundUser?.data()["isEmployee"] as! Bool, isAdmin: foundUser?.data()["isAdmin"] as! Bool, status: foundUser?.data()["status"] as! String)
                                self.updateStatus("Aktivan", option: 1)
                            } else {
                                let errorMsg = "Korisnik nije pronađen. Prvo kreirajte profil!"
                                self.delegate?.didFailWithError(error: errorMsg)
                            }
                        }
                }
            }
        })
    }
    
    func logOutUser() {
        do {
            try FirebaseAuth.Auth.auth().signOut()
            updateStatus("Neaktivan", option: 0)
        } catch {
            print("An error occurred")
        }
    }
    
    func isAnyoneSignedIn() {
        if FirebaseAuth.Auth.auth().currentUser != nil {
            self.db.collection("users").whereField("email", isEqualTo: FirebaseAuth.Auth.auth().currentUser!.email!)
                .getDocuments() { (querySnapshot, err) in
                    if let err = err {
                        print("Error getting documents: \(err)")
                    } else {
                        let foundUser = querySnapshot?.documents[0]
                        self.user = User(name: foundUser?.data()["name"] as! String, surname: foundUser?.data()["surname"] as! String, phoneNumber: foundUser?.data()["phoneNumber"] as! String, email: foundUser?.data()["email"] as! String, address: foundUser?.data()["address"] as! String, orderNumber: foundUser?.data()["orderNumber"] as! Int, isCustomer: foundUser?.data()["isCustomer"] as! Bool, isEmployee: foundUser?.data()["isEmployee"] as! Bool, isAdmin: foundUser?.data()["isAdmin"] as! Bool, status: foundUser?.data()["status"] as! String)
                        self.fetchFood()
                        self.fetchOtherUsersStatus(false)
                    }
            }
        } else {
            self.delegate?.didSignInUser(self, user: nil)
        }
    }
    
    func fetchOrders() {
        waitingOrders.removeAll()
        takenOrders.removeAll()
        finishedOrders.removeAll()
        self.db.collection("orders").whereField("ordered", isEqualTo: true)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    for document in querySnapshot!.documents {
                        let deliveryMan = document.data()["deliveryMan"] as! String
                        let delivered = document.data()["delivered"] as! Bool
                        if deliveryMan.isEmpty {
                            var food = [FoodDish]()
                            let foodNames = document.data()["food"] as! [String]
                            for foodName in foodNames {
                                food.append(self.food.first(where: { $0.name == foodName })!)
                            }
                            self.waitingOrders.append(Order(address: document.data()["address"] as! String, email: document.data()["email"] as! String, deliveryMan: document.data()["deliveryMan"] as! String, ordered: document.data()["ordered"] as! Bool, delivered: document.data()["delivered"] as! Bool, orderNumber: document.data()["orderNumber"] as! Int, food: food))
                        } else if delivered {
                            var food = [FoodDish]()
                            let foodNames = document.data()["food"] as! [String]
                            for foodName in foodNames {
                                food.append(self.food.first(where: { $0.name == foodName })!)
                            }
                            self.finishedOrders.append(Order(address: document.data()["address"] as! String, email: document.data()["email"] as! String, deliveryMan: document.data()["deliveryMan"] as! String, ordered: document.data()["ordered"] as! Bool, delivered: document.data()["delivered"] as! Bool, orderNumber: document.data()["orderNumber"] as! Int, food: food))
                        } else if deliveryMan == self.user!.email {
                            var food = [FoodDish]()
                            let foodNames = document.data()["food"] as! [String]
                            for foodName in foodNames {
                                food.append(self.food.first(where: { $0.name == foodName })!)
                            }
                            self.takenOrders.append(Order(address: document.data()["address"] as! String, email: document.data()["email"] as! String, deliveryMan: document.data()["deliveryMan"] as! String, ordered: document.data()["ordered"] as! Bool, delivered: document.data()["delivered"] as! Bool, orderNumber: document.data()["orderNumber"] as! Int, food: food))
                        }
                    }
                    self.delegate?.didFetchOrders(self)
                }
        }
    }
    
    func updateUser(name: String, surname: String, phoneNumber: String, address: String) {
        user = User(name: name, surname: surname, phoneNumber: phoneNumber, email: user!.email, address: address, orderNumber: user!.orderNumber, isCustomer: user!.isCustomer, isEmployee: user!.isEmployee, isAdmin: user!.isAdmin, status: user!.status)
        db.collection("users").whereField("email", isEqualTo: user!.email).getDocuments { (result, error) in
            if error == nil{
                let foundUser = self.db.collection("users").document(self.user!.email)
                foundUser.getDocument { (document, error) in
                    if let document = document, document.exists {
                        foundUser.updateData([
                            "name": name,
                            "surname": surname,
                            "phoneNumber": phoneNumber,
                            "address": address
                        ]) { err in
                            if let err = err {
                                print("Error updating document: \(err)")
                            } else {
                                print("Document successfully updated")
                                self.delegate?.didUpdateUser(self)
                            }
                        }
                    } else {
                        print("Document does not exist")
                    }
                }
            }
        }
    }
    
    func uploadProfilePicture(image: UIImage) {
        self.image = image
        let storageRef = storage.reference().child("\(user!.email).png")
        let imgData = image.pngData()
        let metaData = StorageMetadata()
        metaData.contentType = "image/png"
        storageRef.putData(imgData!, metadata: metaData) { (metadata, error) in
            if error == nil{
                self.delegate?.didDownloadUpdatePicture(self)
            } else {
                print("error in save image")
            }
        }
    }
    
    func uploadDefaultProfilePictureWhenSignUp(_ image: UIImage, _ user2: User) {
        self.image = image
        let storageRef = storage.reference().child("\(user!.email).png")
        let imgData = image.pngData()
        let metaData = StorageMetadata()
        metaData.contentType = "image/png"
        storageRef.putData(imgData!, metadata: metaData) { (metadata, error) in
            if error == nil{
                self.delegate?.didSignInUser(self, user: user2)
            } else {
                print("error in save image")
            }
        }
    }
    
    func getProfilePicture() {
        let storageRef = storage.reference().child("\(user!.email).png")
        storageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
            if error == nil {
                let image = UIImage(data: data!)
                self.image = image!
                self.delegate?.didDownloadUpdatePicture(self)
            }
        }
    }
    
    func findUserForOrder(_ email : String) {
        self.db.collection("users").whereField("email", isEqualTo: email)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    let foundUser = querySnapshot?.documents[0]
                    self.userOrder = User(name: foundUser?.data()["name"] as! String, surname: foundUser?.data()["surname"] as! String, phoneNumber: foundUser?.data()["phoneNumber"] as! String, email: foundUser?.data()["email"] as! String, address: foundUser?.data()["address"] as! String, orderNumber: foundUser?.data()["orderNumber"] as! Int, isCustomer: foundUser?.data()["isCustomer"] as! Bool, isEmployee: foundUser?.data()["isEmployee"] as! Bool, isAdmin: foundUser?.data()["isAdmin"] as! Bool, status: foundUser?.data()["status"] as! String)
                    self.delegate?.didFindUserForOrder(self, user: self.userOrder!)
                }
        }
    }
    
    func deliverOrder() {
        db.collection("orders").whereField("email", isEqualTo: userOrder!.email).whereField("orderNumber", isEqualTo: userOrder!.orderNumber).getDocuments { (result, error) in
            if error == nil{
                let foundOrder = self.db.collection("orders").document("\(self.userOrder!.email)\(self.userOrder!.orderNumber)")
                foundOrder.getDocument { (document, error) in
                    if let document = document, document.exists {
                        foundOrder.updateData([
                            "delivered": true
                        ]) { err in
                            if let err = err {
                                print("Error updating document: \(err)")
                            } else {
                                print("Document successfully updated")
                                self.delegate?.didDeliverOrder(self)
                            }
                        }
                    } else {
                        print("Document does not exist")
                    }
                }
            }
        }
    }
    
    func takeOrder() {
        db.collection("orders").whereField("email", isEqualTo: userOrder!.email).whereField("orderNumber", isEqualTo: userOrder!.orderNumber).getDocuments { (result, error) in
            if error == nil{
                let foundOrder = self.db.collection("orders").document("\(self.userOrder!.email)\(self.userOrder!.orderNumber)")
                foundOrder.getDocument { (document, error) in
                    if let document = document, document.exists {
                        foundOrder.updateData([
                            "deliveryMan": self.user!.email
                        ]) { err in
                            if let err = err {
                                print("Error updating document: \(err)")
                            } else {
                                print("Document successfully updated")
                                self.delegate?.didTakeOrder(self)
                            }
                        }
                    } else {
                        print("Document does not exist")
                    }
                }
            }
        }
    }
    
    func fetchOtherUsersStatus(_ shouldFetchRequests : Bool) {
        otherEmployees.removeAll()
        self.db.collection("users").whereField("isEmployee", isEqualTo: true).getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    for document in querySnapshot!.documents {
                        let foundUserEmail = document.data()["email"] as! String
                        if foundUserEmail == self.user?.email {
                            continue
                        }
                        self.otherEmployees.append(User(name: document.data()["name"] as! String, surname: document.data()["surname"] as! String, phoneNumber: document.data()["phoneNumber"] as! String, email: document.data()["email"] as! String, address: document.data()["address"] as! String, orderNumber: document.data()["orderNumber"] as! Int, isCustomer: document.data()["isCustomer"] as! Bool, isEmployee: document.data()["isEmployee"] as! Bool, isAdmin: document.data()["isAdmin"] as! Bool, status: document.data()["status"] as! String))
                    }
                    if shouldFetchRequests {
                        self.getProfileCreationRequests()
                    } else {
                        self.delegate?.didFetchOtherEmployees(self)
                    }
                }
        }
    }
    
    func changeStatus(_ status: String) {
        updateStatus(status, option: 2)
    }
    
    private func updateStatus(_ status: String, option: Int) {
        db.collection("users").whereField("email", isEqualTo: user!.email).getDocuments { (result, error) in
            if error == nil{
                let foundUser = self.db.collection("users").document("\(self.user!.email)")
                foundUser.getDocument { (document, error) in
                    if let document = document, document.exists {
                        foundUser.updateData([
                            "status": status
                        ]) { err in
                            if let err = err {
                                print("Error updating document: \(err)")
                            } else {
                                print("Document successfully updated")
                                if option == 0 {
                                    self.user = nil
                                    self.delegate?.didLogOutUser(self)
                                } else if option == 1 {
                                    self.delegate?.didSignInUser(self, user: self.user!)
                                }
                            }
                        }
                    } else {
                        print("Document does not exist")
                    }
                }
            }
        }
    }
    
    func getProfileCreationRequests() {
        userRequests.removeAll()
        self.db.collection("requests").getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    for document in querySnapshot!.documents {
                        let foundEmail = document.data()["email"] as! String
                        if foundEmail != "proba123@gmail.com" {
                            self.userRequests.append(Request(name: document.data()["name"] as! String, surname: document.data()["surname"] as! String, phoneNumber: document.data()["phoneNumber"] as! String, email: document.data()["email"] as! String, address: document.data()["address"] as! String, orderNumber: document.data()["orderNumber"] as! Int, isCustomer: document.data()["isCustomer"] as! Bool, isEmployee: document.data()["isEmployee"] as! Bool, isAdmin: document.data()["isAdmin"] as! Bool, status: document.data()["status"] as! String, password: document.data()["password"] as! String))
                        }
                    }
                    self.delegate?.didFetchOtherEmployees(self)
                }
        }
    }
    
    func findDeliveryManForOrder(_ email : String) {
        self.db.collection("users").whereField("email", isEqualTo: email)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    let foundUser = querySnapshot?.documents[0]
                    self.deliveryManOrder = User(name: foundUser?.data()["name"] as! String, surname: foundUser?.data()["surname"] as! String, phoneNumber: foundUser?.data()["phoneNumber"] as! String, email: foundUser?.data()["email"] as! String, address: foundUser?.data()["address"] as! String, orderNumber: foundUser?.data()["orderNumber"] as! Int, isCustomer: foundUser?.data()["isCustomer"] as! Bool, isEmployee: foundUser?.data()["isEmployee"] as! Bool, isAdmin: foundUser?.data()["isAdmin"] as! Bool, status: foundUser?.data()["status"] as! String)
                    self.delegate?.didDeliverOrder(self)
                }
        }
    }
    
    func rejectRequest(email: String) {
        db.collection("requests").document(email).delete() { err in
            if let err = err {
                print("Error removing document: \(err)")
            } else {
                print("Document successfully removed!")
                self.delegate?.didRejectRequest(self)
            }
        }
    }
    
    func acceptRequest(request: Request) {
        FirebaseAuth.Auth.auth().createUser(withEmail: request.email, password: request.password, completion: { result, error in
            if error != nil {
                let errCode = AuthErrorCode(_nsError: error! as NSError)
                switch errCode.code {
                case .accountExistsWithDifferentCredential, .credentialAlreadyInUse, .emailAlreadyInUse:
                    self.updateUserRole(email: request.email)
                default:
                    break
                }
            }
            else {
                self.db.collection("users").document(request.email).setData([
                    "name": request.name,
                    "surname": request.surname,
                    "email": request.email,
                    "address": request.address,
                    "phoneNumber": request.phoneNumber,
                    "orderNumber": 0,
                    "isCustomer": true,
                    "isEmployee": true,
                    "isAdmin": false,
                    "status": "Neaktivan"
                ]) { err in
                    if let err = err {
                        print("Error writing document: \(err)")
                    } else {
                        print("Document successfully written!")
                        self.db.collection("requests").document(request.email).delete() { err in
                            if let err = err {
                                print("Error removing document: \(err)")
                            } else {
                                print("Document successfully removed!")
                                self.delegate?.didAcceptRequest(self)
                            }
                        }
                    }
                }
            }
        })
    }
    
    private func updateUserRole(email: String) {
        db.collection("users").whereField("email", isEqualTo: email).getDocuments { (result, error) in
            if error == nil{
                let foundUser = self.db.collection("users").document("\(email)")
                foundUser.getDocument { (document, error) in
                    if let document = document, document.exists {
                        foundUser.updateData([
                            "isEmployee": true
                        ]) { err in
                            if let err = err {
                                print("Error updating document: \(err)")
                            } else {
                                print("Document successfully updated")
                                self.db.collection("requests").document(email).delete() { err in
                                    if let err = err {
                                        print("Error removing document: \(err)")
                                    } else {
                                        print("Document successfully removed!")
                                        self.delegate?.didAcceptRequest(self)
                                    }
                                }
                            }
                        }
                    } else {
                        print("Document does not exist")
                    }
                }
            }
        }
    }
    
    func logOutLogIn() {
        do {
            try FirebaseAuth.Auth.auth().signOut()
            FirebaseAuth.Auth.auth().signIn(withEmail: user!.email, password: "issmar123")
        } catch {
            print("error")
        }
    }
    
    func fetchReservations() {
        reservations.removeAll()
        self.db.collection("reservations").getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    for document in querySnapshot!.documents {
                        self.reservations.append(Reservation(day: document.data()["day"] as! Int, month: document.data()["month"] as! Int, year: document.data()["year"] as! Int, hours: document.data()["hours"] as! Int, numberOfPeople: document.data()["numberOfPeople"] as! Int, email: document.data()["email"] as! String, comment: document.data()["comment"] as! String))
                    }
                    self.reservations.sort(by: {
                        if $0.year == $1.year {
                            if $0.month == $1.month {
                                if $0.day == $1.day {
                                    return $0.hours < $1.hours
                                } else {
                                    return $0.day < $1.day
                                }
                            } else {
                                return $0.month < $1.month
                            }
                        } else {
                            return $0.year < $1.year
                        }
                    })
                    self.delegate?.didFetchReservations(self)
                }
        }
    }
    
    func fetchOrdersForUse(user: User) {
        takenOrdersForUser.removeAll()
        finishedOrdersForUser.removeAll()
        self.db.collection("orders").whereField("ordered", isEqualTo: true).whereField("deliveryMan", isEqualTo: user.email)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    for document in querySnapshot!.documents {
                        let delivered = document.data()["delivered"] as! Bool
                        if delivered {
                            var food = [FoodDish]()
                            let foodNames = document.data()["food"] as! [String]
                            for foodName in foodNames {
                                food.append(self.food.first(where: { $0.name == foodName })!)
                            }
                            self.finishedOrdersForUser.append(Order(address: document.data()["address"] as! String, email: document.data()["email"] as! String, deliveryMan: document.data()["deliveryMan"] as! String, ordered: document.data()["ordered"] as! Bool, delivered: document.data()["delivered"] as! Bool, orderNumber: document.data()["orderNumber"] as! Int, food: food))
                        } else {
                            var food = [FoodDish]()
                            let foodNames = document.data()["food"] as! [String]
                            for foodName in foodNames {
                                food.append(self.food.first(where: { $0.name == foodName })!)
                            }
                            self.takenOrdersForUser.append(Order(address: document.data()["address"] as! String, email: document.data()["email"] as! String, deliveryMan: document.data()["deliveryMan"] as! String, ordered: document.data()["ordered"] as! Bool, delivered: document.data()["delivered"] as! Bool, orderNumber: document.data()["orderNumber"] as! Int, food: food))
                        }
                    }
                    self.delegate?.didFetchOrders(self)
                }
        }
    }
}
