public with sharing class AddOnService {
    private static AddOnDAO dao = new AddOnDAO();

    /**
     * Creates a new Add-On.
     * @param name Add-on name.
     * @param price The price.
     * @param description Description text.
     * @return The Id of the new record.
     */
    public Id createAddOn(String name, Decimal price, String description) {
        if (String.isBlank(name)) {
            throw new IllegalArgumentException('Add-On name is required.');
        }
        if (price == null || price < 0) {
            throw new IllegalArgumentException('A valid positive price is required.');
        }

        Add_On__c addon = new Add_On__c(
            Name = name,
            Price__c = price,
            Description__c = description,
            IsActive__c = true
        );

        Database.SaveResult result = dao.insertAddOn(addon);
        if (result.isSuccess()) {
            return result.getId();
        } else {
            throw new AuraHandledException('Error creating add-on: ' + getErrors(result));
        }
    }

    /**
     * Updates an existing Add-On.
     */
    public void updateAddOn(Id addonId, String name, Decimal price, String description) {
        if (addonId == null) {
            throw new IllegalArgumentException('Add-On Id is required for updates.');
        }

        Add_On__c addon = new Add_On__c(
            Id = addonId,
            Name = name,
            Price__c = price,
            Description__c = description
        );

        Database.SaveResult result = dao.updateAddOn(addon);
        if (!result.isSuccess()) {
            throw new AuraHandledException('Error updating add-on: ' + getErrors(result));
        }
    }

    /**
     * Fetches all active add-ons.
     * @return List of Add_On__c records.
     */
    public List<Add_On__c> getActiveAddOns() {
        return dao.getActiveAddOns();
    }

    /**
     * Fetches all add-ons.
     * @return List of Add_On__c records.
     */
    public List<Add_On__c> getAllAddOns() {
        return dao.getAllAddOns();
    }

    /**
     * Deletes an add-on.
     * @param addonId The Id to delete.
     */
    public void deleteAddOn(Id addonId) {
        if (addonId == null) {
            throw new IllegalArgumentException('Add-On Id is required.');
        }
        dao.deleteAddOn(addonId);
    }

    /**
     * Deletes multiple add-ons.
     */
    public void deleteAddOns(List<Id> addonIds) {
        dao.deleteAddOns(addonIds);
    }

    private String getErrors(Database.SaveResult result) {
        String errors = '';
        for (Database.Error err : result.getErrors()) {
            errors += err.getMessage() + ' ';
        }
        return errors;
    }
}
