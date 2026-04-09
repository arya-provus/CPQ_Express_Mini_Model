public with sharing class AddOnController {

    /**
     * Creates a new Add-On.
     */
    @AuraEnabled
    public static Id createAddOn(String name, Decimal price, String description) {
        try {
            AddOnService service = new AddOnService();
            return service.createAddOn(name, price, description);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Entry point for LWC to update an existing Add-On.
     */
    @AuraEnabled
    public static void updateAddOn(Id addonId, String name, Decimal price, String description) {
        try {
            AddOnService service = new AddOnService();
            service.updateAddOn(addonId, name, price, description);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Gets all active add-ons.
     */
    @AuraEnabled(cacheable=true)
    public static List<Add_On__c> getActiveAddOns() {
        try {
            AddOnService service = new AddOnService();
            return service.getActiveAddOns();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Gets all add-ons.
     */
    @AuraEnabled(cacheable=true)
    public static List<Add_On__c> getAllAddOns() {
        try {
            AddOnService service = new AddOnService();
            return service.getAllAddOns();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Deletes an add-on.
     */
    @AuraEnabled
    public static void deleteAddOn(Id addonId) {
        try {
            AddOnService service = new AddOnService();
            service.deleteAddOn(addonId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * Deletes multiple add-ons by ID.
     */
    @AuraEnabled
    public static void deleteAddOns(List<Id> addonIds) {
        try {
            AddOnService service = new AddOnService();
            service.deleteAddOns(addonIds);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
