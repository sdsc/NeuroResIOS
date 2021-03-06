//
//  SlideMenuControllerViewController.swift
//  NeuroResIOS
//
//  Created by Charles McKay on 3/1/17.
//  Copyright © 2017 Charles McKay. All rights reserved.
//

//documentation for slide menu
//http://www.appcoda.com/sidebar-menu-swift/

import UIKit
import SwiftyJSON

protocol SlideMenuDelegate{
    func slideMenuItemSelectedAtIndex(_ index: Int32)
}

class SlideMenuController: UIViewController, UITableViewDelegate, UITableViewDataSource, WebSocketResponder{

    let BASE_URL = AppDelegate.BASE_URL
    
    /**
    *   Array to display menu options
    */
    @IBOutlet weak var usersList: UITableView!
    
    
    /**
    *   Transparent button to hide menu
    */

    @IBOutlet var btnCloseMenuOverlay: UIButton!

    /**
    *   array containing menu options
    */
    
    var arrayMenuOptions = [Dictionary<String,String>]()
    
    /**
    *   Menu button which was tapped to display the menu
    */
    var btnMenu: UIButton!
    @IBOutlet weak var zoomButton: UIButton!
    
    @IBAction func zoomClicked(_ sender: Any) {
        //var instagramHooks = "zoom://user?username=johndoe"
        //var instagramUrl = URL(string: instagramHooks)
        /*if UIApplication.shared.canOpenURL(instagramUrl! as URL)
        {
            UIApplication.shared.openURL(instagramUrl! as URL)
            
        } else {
            //redirect to safari because the user doesn't have Instagram
            
        }*/
        //https://stackoverflow.com/questions/33932303/swift-how-to-open-a-new-app-when-uibutton-is-tapped
        UIApplication.shared.openURL(URL(string: "https://uchealth.zoom.us/j/3329671357")!)
    }
    @IBOutlet weak var usernameLabel: UILabel!
    /**
    *   Delegate of the MenuVC
    */
    var delegate: SlideMenuDelegate?
    
    var unread_showing = true
    var staff_showing = true
    var users_showing = 0
    var staff_type_hiding:[String] = []
    
    
    static func getToken() -> String{
        return UserDefaults.standard.value(forKey: "user_auth_token")! as! String;
    }
    
    static func getName() -> String{
        return UserDefaults.standard.value(forKey: "username")! as! String;
    }
    
    
    /**
     * Function to get list of users
     * Parameters: url:String - address of endpoint for API call
     */
    static func getUsers(token: String, myName: String, completion: @escaping (_ : [String], _ : [String:Int], _ : [String:[String]]) -> Void ) {
        
        var users:[String] = []
        var emailToId:[String:Int] = [:]
        var staff:[String:[String]] = [:]
        
        let userGroup = DispatchGroup()
        var request = URLRequest(url: URL(string: AppDelegate.BASE_URL + "users_list")!)
        request.httpMethod = "POST"
        request.addValue(token, forHTTPHeaderField: "auth")
        userGroup.enter()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("error=\(String(describing: error))")
                userGroup.leave()
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode) in getting users")
                print("response = \(String(describing: response))")
                userGroup.leave()
                return
            }
            
            
            
            let parsedData = ChatController.dataToJSON(data)
            SlideMenuController.CacheUsers(parsedData.rawString()!)
            
            (users, emailToId, staff) = parseJSONToInfo(parsedData)
           
            userGroup.leave()
        }
        task.resume()
        userGroup.wait()
        DispatchQueue.main.async {
            if users.isEmpty{
                (users, emailToId, staff) = LoadUserCache()
            }
            completion(users, emailToId, staff)
        }
    }
    
    static func CacheUsers(_ stringEncoding: String){
        UserDefaults.standard.set(stringEncoding, forKey: AppDelegate.CACHE_USERS_LIST)
    }
    
    static func LoadUserCache() -> ([String], [String:Int], [String:[String]]){
        let userCacheString = UserDefaults.standard.value(forKey: AppDelegate.CACHE_USERS_LIST)! as! String;
        let parsedJson = JSON.init(parseJSON: userCacheString)
        
        return parseJSONToInfo(parsedJson)
    }
    
    static func parseJSONToInfo(_ parsedData : JSON) -> ([String], [String:Int], [String:[String]]){
        
        var users:[String] = []
        var emailToId:[String:Int] = [:]
        var staff:[String:[String]] = [:]
        
        for i in 0 ... (parsedData.array?.count)! - 1 {
            
            let json = parsedData.array?[i]
            let name = json?["email"].string
            
            let id_s = json?["user_id"].string
            let id = Int(id_s!)
            users.append(name!)
            emailToId[name!] = (id! as Int)
            let userType = json?["user_type"].string
            if(userType == nil){
                continue //probably a dev user, and i don't want to display this
            }
            if staff[userType!] != nil {
                staff[userType!]!.append(name!)
            }
            else{
                staff[userType!] = [name!]
            }
        }
        
        return (users, emailToId, staff)
    }
    
    
    static func getUnread(token: String, myName: String, _ lookup :[Int:String], completion: @escaping (_ : [Int:Int], Bool) -> Void ) {
        
        var unreads:[Int:Int] = [:]
        var badToken = false
        
        let userGroup = DispatchGroup()
        var request = URLRequest(url: URL(string: AppDelegate.BASE_URL + "conversation_data")!)
        request.httpMethod = "POST"
        request.addValue(token, forHTTPHeaderField: "auth")
        userGroup.enter()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("error=\(String(describing: error))")
                userGroup.leave()
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(String(describing: response))")
                badToken = true
                userGroup.leave()
                return
            }
            
            let jsonString = String(data: data, encoding: String.Encoding.utf8) as! String
            let json = JSON.init(parseJSON : jsonString as String)
                
            for(_, detail) in json{
                if(detail["last_seen"] != JSON.null){
                    for user_id in detail["members"].array!{
                        if(lookup[user_id.int!] == nil){
                            continue
                        }
                        if(lookup[user_id.int!]?.uppercased() != myName.uppercased()){
                            unreads[user_id.int!] = detail["unseen_count"].int!
                        }
                    }
                }
            }
            userGroup.leave()
        }
        task.resume()
        userGroup.wait()
        DispatchQueue.main.async {
            completion(unreads, badToken)
        }
        
        
    }
    
    
    
    var emailToId:[String:Int] = [:]
    var idToEmail:[Int:String] = [:]
    var users:[String] = []
    var staff:[String:[String]] = [:]
    var unread:[String] = []
    var unreadCount:[String:Int] = [:]
    var staffKeys:[String] = []
    
    @IBOutlet weak var userTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if(UserDefaults.standard.string(forKey: "user_auth_token") == nil){
            return
        }
        
        let swipeleft = UISwipeGestureRecognizer(target: self, action: #selector(self.respondToSwipeGesture))
        swipeleft.direction = UISwipeGestureRecognizerDirection.left
        self.userTableView.addGestureRecognizer(swipeleft)
        
        let myName = SlideMenuController.getName()
        
        usernameLabel.text = myName
        
        // Get users
        SlideMenuController.getUsers(token: SlideMenuController.getToken(), myName: myName) { (users_ret: [String], userIDs_ret: [String:Int], staff_ret: [String:[String]]) in
            for user in users_ret{
                if user != myName{
                    self.users.append(user)
                }
            }
            for (staff_type, staff_list) in staff_ret {
                var section = [String]()
                for staff_name in staff_list{
                    if staff_name != myName {
                        section.append(staff_name)
                    }
                }
                self.staff[staff_type] = section
            }
            self.emailToId = userIDs_ret
            
            for(email, id) in userIDs_ret{
                self.idToEmail[id] = email
            }
            
            self.staffKeys = Array(self.staff.keys)
            
            
            for staff_type_name in self.staffKeys{
                self.staff_type_hiding.append(staff_type_name)
            }
            
            self.refreshUnreads()

        }
        
        userTableView.rowHeight = UITableViewAutomaticDimension
        userTableView.estimatedRowHeight = 1
        
    }
    
    func refreshUnreads(){
        SlideMenuController.getUnread(token: SlideMenuController.getToken(), myName: SlideMenuController.getName(), self.idToEmail) { (unreads_ret : [Int:Int], loginError: Bool) in
            
            if(loginError){
                /*DispatchQueue.main.async {
                 self.performSegue(withIdentifier: "noLoginTokenSegue", sender: nil)
                 }*/
                return
            }
            
            self.unread.removeAll()
            self.unreadCount.removeAll()
            
            for(user_id, unread_count) in unreads_ret{
                let email = self.idToEmail[user_id]!
                self.unread.append(email)
                self.unreadCount[email] = unread_count
            }
            self.userTableView.reloadData()
            //self.connectSocket()
        }
    }
    
    @objc func respondToSwipeGesture(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case UISwipeGestureRecognizerDirection.left:
                if self.slideMenuShowing() {
                    self.revealViewController().revealToggle(self.revealViewController())
                }
            default:
                break
            }
        }
    }
    
    func slideMenuShowing() -> Bool{
        return self.revealViewController().frontViewPosition.rawValue == ChatController.MENU_MODE
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        self.ws.close()
        if segue.identifier == "staffNameSelect" || segue.identifier == "directNameSelect" {
            UIView.animate(withDuration: 0.3, animations: { () -> Void in
                self.view.frame = CGRect(x: -UIScreen.main.bounds.size.width, y: 0, width: UIScreen.main.bounds.size.width,height: UIScreen.main.bounds.size.height)
                self.view.layoutIfNeeded()
                self.view.backgroundColor = UIColor.clear
            }, completion: { (finished) -> Void in
                self.view.removeFromSuperview()
                self.removeFromParentViewController()
            })
        
        }
    }
    

    
    
    @IBAction func onCloseMenuClick(_ button:UIButton!){
        btnMenu.tag = 0
        if (self.delegate != nil) {
            var index = Int32(button.tag)
            if(button == self.btnCloseMenuOverlay){
                index = -1
            }
            delegate?.slideMenuItemSelectedAtIndex(index)
        }
        
        UIView.animate(withDuration: 0.3, animations: { () -> Void in
            self.view.frame = CGRect(x: -UIScreen.main.bounds.size.width, y: 0, width: UIScreen.main.bounds.size.width,height: UIScreen.main.bounds.size.height)
            self.view.layoutIfNeeded()
            self.view.backgroundColor = UIColor.clear
        }, completion: { (finished) -> Void in
            self.view.removeFromSuperview()
            self.removeFromParentViewController()
        })

    }
    
    var configured = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !configured{
            usersList.delegate = self
            usersList.dataSource = self
        }
        configured = true
        refreshUnreads()
        connectSocket()
    }
    
    //MARK: UITableViewDelegate and Datasource Methods
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getRowCount()
    }
    func getRowCount() -> Int{
        var unread_section = unread.count
        if(unread.count > 0){
            unread_section += 1
            if(!unread_showing){
                unread_section -= unread.count
            }
        }
        var row_count = 0;
        
        //row_count += unread_section
        var staff_section = 1 //for staff 'big' header
        if(staff_showing){
            staff_section += staff.count // keys of the staff. i dont add these because the headers are also 'hidden'
            staff_section += getStaffCount()
        }
        
        var private_count = 1 //for users 'big' header
        if(users_showing != 0){
            private_count += users_showing
            private_count += 1 //for the last row of label 'more'
        }
        
        row_count += unread_section
        row_count += staff_section
        row_count += private_count
        
        return row_count
    }
    
    func getStaffCount() -> Int{
        var staff_subsection = 0;
        if(staff_showing){
            for(staff_type_name, staff_names) in staff{
                if(!staff_type_hiding.contains(staff_type_name)){
                    staff_subsection += staff_names.count
                }
            }
        }
        
        return staff_subsection
    }
    
    func unreadHeader(indexPath: IndexPath) -> Bool{
        return unread.count > 0 && indexPath.row == 0
    }
    
    func unreadCell(indexPath: IndexPath) -> Bool{
        if(!unread_showing || unreadCount.count == 0){
            return false
        }
        return indexPath.row - 1 < unread.count
    }
    
    func staffHeader(indexPath: IndexPath) -> Bool{
        let row = indexPath.row
        if(unread.count == 0){
            return row == 0
        }else if(!unread_showing){
            return row == 1
        }
        return row == unread.count + 1;
    }

    func usersHeader(indexPath: IndexPath) -> Bool{
        var row = indexPath.row
        if(unread.count != 0){
            row -= 1 // for the 'Not Read' header
            if(unread_showing){
                row -= (unread.count)
            }
        }
        
        row -= 1 //for the staff 'big' header
        if(staff_showing){
            row -= (staff.count)
        }
        row -= getStaffCount()//will return 0 if staff isn't showing
        return row == 0
    }
    
    func staffTypeCell(indexPath: IndexPath) -> Bool{
        if(!staff_showing){
            return false
        }
        var row = indexPath.row
        if(unread.count != 0){
            row -= 1 // for the 'Not Read' header
            if(unread_showing){
                row -= (unread.count)
            }
        }

        row -= 1 //for Staff entirety section
        
        if(staff.count > 0){
            for i in 0 ... staff.count - 1{
                if(row == 0){
                    return true;
                }
                row -= 1
                if(!staff_type_hiding.contains(staffKeys[i])){
                    row -= (staff[staffKeys[i]]?.count)!
                }
            }
        }
        return false
    }
    func isAtBottom(_ tableView: UITableView) -> Bool{
        return tableView.contentOffset.y >= (tableView.contentSize.height - tableView.frame.size.height)
    }
        
    func staffNameCell(indexPath: IndexPath) -> Bool{
        if(!staff_showing){
            return false
        }
        var row = indexPath.row
        if(unread.count != 0){
            row -= 1 // for the 'Not Read' header
            if(unread_showing){
                row -= (unread.count)
            }
        }

        
        row -= 1
        
        var size = 0
        if(staff.count > 0){
            for i in 0 ... (staff.count - 1) {
                row -= 1
                if(staff_type_hiding.contains(staffKeys[i])){
                    size = 0
                }else{
                    size = (staff[staffKeys[i]]?.count)!
                }
            
                if(row >= 0 && row < size){
                    return true
                }
            
                if(!staff_type_hiding.contains(staffKeys[i])){
                    row -= size
                }
            }
        }
        return false
    }
    
    
    
    func header(indexPath: IndexPath) -> Bool{
        return unreadHeader(indexPath: indexPath) || staffHeader(indexPath: indexPath) || usersHeader(indexPath: indexPath)
    }
    
    //the ... show more people button
    func moreCell(indexPath: IndexPath) -> Bool{
        if(users_showing == 0){
            return false
        }
        var unread_section = 0
        if(unread.count != 0){
            unread_section += 1 // for the 'Not Read' header
            if(unread_showing){
                unread_section += (unread.count)
            }
        }

        
        var total_count = 0
        
        total_count += unread_section
        total_count += 1 //for staff big header
        if(staff_showing){
            total_count += staff.count
            total_count += getStaffCount()
        }
        
        total_count += 1 //for users big header
        
        total_count += users_showing
        
        
        return total_count == indexPath.row
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if(unreadHeader(indexPath: indexPath)){
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChatHeaderCell", for: indexPath) as! ChatHeaderCell
            
            cell.titleText.text = "Unread"
            cell.expander.image = getExpanderImage(status: unread_showing)
            
            return cell
        }else if(unreadCell(indexPath: indexPath)){ //for title text
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChatDescripCell", for: indexPath) as! ChatDescripCell
            
            cell.name.text = unread[indexPath.row - 1]
            if(isOffline(cell.name.text!)){
                cell.statusIco.image = UIImage(named: "offline")
            }else{
                cell.statusIco.image = UIImage(named: "online")
            }
            let unreadCount = self.unreadCount[cell.name.text!]!
            cell.unreadCount.isHidden = unreadCount == 0
            cell.unreadCount.text = String(describing: unreadCount)
            return cell
        }else if(staffHeader(indexPath: indexPath)){
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChatHeaderCell", for: indexPath) as! ChatHeaderCell
            
            cell.titleText.text = "Staff"
            cell.expander.image = getExpanderImage(status: staff_showing)
            
            return cell
        
        }else if(staffTypeCell(indexPath: indexPath)){
            let cell = tableView.dequeueReusableCell(withIdentifier: "StaffDescripCell", for: indexPath) as! StaffDescripCell
            
            var staffCell = indexPath.row
            if(unread.count > 0){
                staffCell -= unread.count + 1
            }
            staffCell -= 1 //staff header
            
            for i in 0 ... staff.count - 1{
                if(staffCell == 0){
                    cell.name.text = staffKeys[i]
                    cell.expander.image = getExpanderImage(status: !staff_type_hiding.contains(staffKeys[i]))
                    return cell
                }
                staffCell -= 1//
                if(!staff_type_hiding.contains(staffKeys[i])){//showing
                    staffCell -= (staff[staffKeys[i]]?.count)!
                }
            }
            
            return cell
        }else if(staffNameCell(indexPath: indexPath)){
            let cell = tableView.dequeueReusableCell(withIdentifier: "StaffNameDescripCell", for: indexPath) as! StaffNameDescripCell
            cell.name.text = getStaffTextName(indexPath: indexPath)
            if(isOffline(cell.name.text!)){
                cell.statusico.image = UIImage(named: "offline")
            }else{
                cell.statusico.image = UIImage(named: "online")
            }
            return cell
        }else if(usersHeader(indexPath: indexPath)){
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChatHeaderCell", for: indexPath) as! ChatHeaderCell
            
            cell.titleText.text = "Recents"
            cell.expander.image = getExpanderImage(status: users_showing == 0)
            
            return cell
        }else if(moreCell(indexPath: indexPath)){
            return tableView.dequeueReusableCell(withIdentifier: "MoreDescripCell", for: indexPath) as! MoreDescripCell        
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChatDescripCell", for: indexPath) as! ChatDescripCell
            
            cell.name.text = getDirectUserName(indexPath: indexPath)
            if(isOffline(cell.name.text!)){
                cell.statusIco.image = UIImage(named: "offline")
            }else{
                cell.statusIco.image = UIImage(named: "online")
            }
            cell.unreadCount.isHidden = true
        
            return cell
        }
    }
    
    func getExpanderImage(status: Bool) -> UIImage{
        var imageName:String = "contract"
        if(status){
            imageName = "expand"
        }
        return UIImage(named: imageName)!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(unreadHeader(indexPath: indexPath)){
            unread_showing = !unread_showing
        }else if(staffHeader(indexPath: indexPath)){
            staff_showing = !staff_showing
        }else if(staffTypeCell(indexPath: indexPath)){
            var staffCell = indexPath.row
            if(unread.count > 0){
                staffCell -= unread.count + 1
            }
            staffCell -= 1 //staff header
            
            for i in 0 ... staff.count - 1{
                let type_name = staffKeys[i]
                if(staffCell == 0){
                    if(staff_type_hiding.contains(type_name)){
                        let index = staff_type_hiding.index(of: type_name)
                        staff_type_hiding.remove(at: index!)
                    }else{
                        staff_type_hiding.append(type_name)
                    }
                    break
                }
                staffCell -= 1
                if(!staff_type_hiding.contains(type_name)){
                    staffCell -= (staff[staffKeys[i]]?.count)!
                }
            }
            print(self.staff.count)
            print(self.staff_type_hiding.count)
            tableView.reloadData()
            if(self.staff.count == self.staff_type_hiding.count && self.isAtBottom(tableView)){
                scrollToTop()
            }
            return
        }else if(usersHeader(indexPath: indexPath)){ //clicking on private header
            if(users_showing == 0){
                users_showing = 5
            }else{
                users_showing = 0
            }
        }else if(staffNameCell(indexPath: indexPath)){
            setConversationMembers(name: getStaffTextName(indexPath: indexPath))
        }else if(moreCell(indexPath: indexPath)){
            users_showing = min(users_showing + 5, users.count)
            tableView.reloadData()
            scrollToBottom()
            return
        }else if(unreadCell(indexPath: indexPath)){
            let clickedUnread = unread[indexPath.row - 1]
            self.unread.remove(at: indexPath.row - 1)
            self.unreadCount.removeValue(forKey: clickedUnread)
            setConversationMembers(name: clickedUnread)
        }else if(!moreCell(indexPath: indexPath)){
            setConversationMembers(name: getDirectUserName(indexPath: indexPath))
        }else{
            
            return
        }
        
        tableView.reloadData()
        
        //push to bottom
        
    }
    
    func scrollToTop(){
        DispatchQueue.global(qos: .background).async {
            let indexPath = IndexPath(row: 0, section: 0)
            DispatchQueue.main.async(){
                self.userTableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
            }
        }
    }
    
    func scrollToBottom(){
        DispatchQueue.global(qos: .background).async {
            let indexPath = IndexPath(row: self.getRowCount()-1, section: 0)
            DispatchQueue.main.async(){
                self.userTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    func getStaffTextName(indexPath: IndexPath) -> String{
        var row = indexPath.row
        if(unread.count != 0){
            row -= 1 // for the 'Not Read' header
            if(unread_showing){
                row -= (unread.count)
            }
        }
        
        row -= 1 //big staff header
        
        var size = 0
        for i in 0 ... (staff.count - 1) {
            row -= 1
            let staff_type_name = staffKeys[i]
            if(staff_type_hiding.contains(staff_type_name)){
                size = 0
            }else{
                size = (staff[staff_type_name]?.count)!
            }
            if(row >= 0 && row < size){
                return (staff[staff_type_name]?[row])!
            }
            row -= size
            
        }
        return ""
    }
    
    func getDirectUserName(indexPath: IndexPath) -> String{
        var row = indexPath.row//for the 'Not
        
        if(unread.count != 0){
            row -= 1 // for the 'Not Read' header
            if(unread_showing){
                row -= (unread.count)
            }
        }
        
        
        row -= 2 //for users and staff 'big' headers
        if(staff_showing){
            row -= (staff.count) //for staff section
            row -= getStaffCount() //for all the staff
        }
        
        return users[row]

    }
    
    func setConversationMembers(name: String){
        SlideMenuController.setConversationMembers(id:emailToId[name]!)
    }
    
    static func setConversationMembers(id: Int){
        UserDefaults.standard.set([id], forKey: "conversationMembers")
    }
    
    static func setConversationMembersGroup(id: [Int]){
        UserDefaults.standard.set(id, forKey: "conversationMembers")
    }
    
    func uicolorFromHex(rgbValue:UInt32)->UIColor{
        let red = CGFloat((rgbValue & 0xFF0000) >> 16)/256.0
        let green = CGFloat((rgbValue & 0xFF00) >> 8)/256.0
        let blue = CGFloat(rgbValue & 0xFF)/256.0
        
        return UIColor(red:red, green:green, blue:blue, alpha:1.0)
    }
    
    func isOffline(_ name: String) -> Bool{
        let userID_i = emailToId[name]
        if(userID_i == nil){
            return true
        }
        return SlideMenuController.isOffline(userID_i!)
    }
    
    static func isOffline(_ user_id_i: Int) -> Bool{
        let foundUsers = UserDefaults.standard.array(forKey: "onlineUsers")
        if(foundUsers == nil){
            return true
        }
        let onlineUsers = (foundUsers!).map { Int($0 as! String)! }
        
        return !onlineUsers.contains(user_id_i)
    }
    
    var ws = WebSocket(AppDelegate.SOCKET_URL)
    
    func assignWebSocket() {
        ws.close();
        ws = WebSocket(AppDelegate.SOCKET_URL);
    }
    
    func addOnlineUser(json: JSON) {
        /*
         In this section, you don't need to use UserDefaults(aka shared memory).  You can take out this code, look at isOffline for the implementation, and do the following:
        -Add a variable that is a list of integers
         -whenever an online user is added, update that list, and call reload data
         */
        let offline = String(describing: json["onlineUser"].int! as Int)
        var onlineUsers = (UserDefaults.standard.array(forKey: "onlineUsers")!).map { $0 as! String }
        onlineUsers.append(offline)
        
        let defaults = UserDefaults.standard
        defaults.set(onlineUsers, forKey: "onlineUsers")
        
        self.usersList.reloadData()
    }
    
    func removeOnlineUser(json: JSON) {
        let offline = String(describing: json["offlineUser"].int! as Int)
        var onlineUsers = (UserDefaults.standard.array(forKey: "onlineUsers")!).map { $0 as! String }
        onlineUsers = onlineUsers.filter(){$0 != offline}
        
        let defaults = UserDefaults.standard
        defaults.set(onlineUsers, forKey: "onlineUsers")
        
        
        self.usersList.reloadData()
    }
    
    func saveUsers(json : JSON){
        let array = json["activeUsers"].arrayValue.map({$0.stringValue})
        let defaults = UserDefaults.standard
        defaults.set(array, forKey: "onlineUsers")
        
        self.usersList.reloadData()
    }
    
    func wipeThread(_ thread: Int) {
        self.refreshUnreads()
    }
    
    func updateCache(_ userID: Int, _ text: String, _ date: Date) {
        //stub
    }
    
    func onMessageReceive(_ convID: Int, _ userID: Int, _ text: String, _ date: Date, _ pushDown: Bool) {
        let email = self.idToEmail[userID]!
        
        if(unread.contains(email)){
            unreadCount[email] = unreadCount[email]! + 1
        }else{
            unread.append(email)
            unreadCount[email] = 1
        }
        
        self.usersList.reloadData()
    }
    
    func getMessages(_ convID: String) {
        //stub
    }
}
