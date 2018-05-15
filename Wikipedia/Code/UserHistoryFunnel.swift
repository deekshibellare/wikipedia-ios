// https://meta.wikimedia.org/wiki/Schema:MobileWikiAppiOSUserHistory

@objc(UserHistoryFunnel)
class UserHistoryFunnel: EventLoggingFunnel, EventLoggingStandardEventDataProviding {
    private let dataStore: MWKDataStore
    
    @objc init(dataStore: MWKDataStore) {
        self.dataStore = dataStore
        super.init(schema: "MobileWikiAppiOSUserHistory", version: 17990229)
    }
    
    private func event() throws -> Dictionary<String, Any> {
        let isAnon = !WMFAuthenticationManager.sharedInstance.isLoggedIn
        let primaryLanguage = MWKLanguageLinkController.sharedInstance().appLanguage?.languageCode ?? "en"
        let readingListCount = try dataStore.viewContext.allReadingListsCount()
        let savedArticlesCount = try dataStore.viewContext.allSavedArticlesCount()
        let isSyncEnabled = dataStore.readingListsController.isSyncEnabled
        let isDefaultListEnabled = dataStore.readingListsController.isDefaultListEnabled
        
        let standardEvent = standardEventData
        let newEvent: [String: Any] = [ "measure_readinglist_listcount": readingListCount, "measure_readinglist_itemcount": savedArticlesCount, "readinglist_sync": isSyncEnabled, "readinglist_showdefault": isDefaultListEnabled, "primary_language": primaryLanguage, "is_anon": isAnon]
        let event = standardEvent.merging(newEvent, uniquingKeysWith: { (first, _) in first })
        return event
    }
    
    override func logged(_ eventData: [AnyHashable: Any]) {
        guard let eventData = eventData as? [String: Any] else {
            return
        }
        UserDefaults.wmf_userDefaults().wmf_lastLoggedUserHistorySnapshot = eventData
    }
    
    @objc public func logSnapshot() {
        guard let latestSnapshot = UserDefaults.wmf_userDefaults().wmf_lastLoggedUserHistorySnapshot, let newSnapshot = try? event() else {
            assertionFailure("User History snapshots must have values")
            return
        }
        
        guard !newSnapshot.wmf_isEqualTo(latestSnapshot, excluding: Array(standardEventData.keys)) else {
            DDLogDebug("User History snapshots are identical; logging new User History snapshot aborted")
            return
        }
        
        DDLogDebug("User History snapshots are different; logging new User History snapshot")
        log()
    }
    
    private func log() {
        do {
            try log(event())
        } catch let error {
            DDLogError("Error logging User History snapshot: \(error)")
        }
    }
    
    @objc public func logStartingSnapshot() {
        log()
    }
}
