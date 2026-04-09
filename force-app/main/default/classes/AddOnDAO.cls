public with sharing class AddOnDAO {
    
    /**
     * Queries all active Add-Ons.
     * @return List of Add_On__c records.
     */
    public List<Add_On__c> getActiveAddOns() {
        return [
            SELECT Id, Name, Price__c, Description__c, IsActive__c, Cost__c
            FROM Add_On__c
            WHERE IsActive__c = true
            ORDER BY Name ASC
        ];
    }

    /**
     * Queries all Add-Ons.
     * @return List of Add_On__c records.
     */
    public List<Add_On__c> getAllAddOns() {
        return [
            SELECT Id, Name, Price__c, Description__c, IsActive__c, Cost__c
            FROM Add_On__c
            ORDER BY Name ASC
        ];
    }

    /**
     * Inserts an Add_On__c record.
     * @param addon The Add_On__c record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult insertAddOn(Add_On__c addon) {
        return Database.insert(addon, true);
    }

    /**
     * Updates an Add_On__c record.
     * @param addon The Add_On__c record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult updateAddOn(Add_On__c addon) {
        return Database.update(addon, true);
    }

    /**
     * Deletes an Add_On__c record.
     * @param addonId The Id of the record to delete.
     * @return Database.DeleteResult.
     */
    public Database.DeleteResult deleteAddOn(Id addonId) {
        Add_On__c addon = new Add_On__c(Id = addonId);
        return Database.delete(addon, true);
    }

    /**
     * Deletes multiple Add-ons.
     * @param addonIds List of Add-on IDs.
     */
    public void deleteAddOns(List<Id> addonIds) {
        if (addonIds != null && !addonIds.isEmpty()) {
            delete [SELECT Id FROM Add_On__c WHERE Id IN :addonIds];
        }
    }
}
