@isTest
private class AddOnServiceTest {

    @isTest
    static void testCreateAddOnPositive() {
        Test.startTest();
        Id addonId = AddOnController.createAddOn('Premium Support', 500.00, 'Premium support package');
        Test.stopTest();

        Assert.isNotNull(addonId, 'Add-On should be created.');
        Add_On__c addon = [SELECT Name, Price__c, Description__c, IsActive__c FROM Add_On__c WHERE Id = :addonId];
        Assert.areEqual('Premium Support', addon.Name);
        Assert.areEqual(500.00, addon.Price__c);
        Assert.isTrue(addon.IsActive__c);
    }

    @isTest
    static void testCreateAddOnNegative() {
        Test.startTest();
        try {
            AddOnController.createAddOn('', -10.00, '');
            Assert.fail('Should have failed for blank name.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Add-On name is required.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetActiveAddOns() {
        AddOnController.createAddOn('Active Add-On', 100.00, 'Test');

        Test.startTest();
        List<Add_On__c> addons = AddOnController.getActiveAddOns();
        Test.stopTest();

        Assert.isTrue(addons.size() >= 1, 'Should return at least one active add-on.');
    }

    @isTest
    static void testGetAllAddOns() {
        AddOnController.createAddOn('All Add-On', 100.00, 'Test');

        Test.startTest();
        List<Add_On__c> addons = AddOnController.getAllAddOns();
        Test.stopTest();

        Assert.isTrue(addons.size() >= 1, 'Should return at least one add-on.');
    }

    @isTest
    static void testDeleteAddOn() {
        Id addonId = AddOnController.createAddOn('Delete Me', 50.00, 'Will be deleted');

        Test.startTest();
        AddOnController.deleteAddOn(addonId);
        Test.stopTest();

        List<Add_On__c> remaining = [SELECT Id FROM Add_On__c WHERE Id = :addonId];
        Assert.areEqual(0, remaining.size(), 'Add-On should be deleted.');
    }

    @isTest
    static void testBulkCreateAddOns() {
        AddOnService service = new AddOnService();
        Test.startTest();
        for(Integer i=0; i<10; i++) {
            service.createAddOn('AddOn ' + i, 50.00 + i, 'Desc');
        }
        Test.stopTest();

        List<Add_On__c> addons = [SELECT Id FROM Add_On__c WHERE Name LIKE 'AddOn %'];
        Assert.areEqual(10, addons.size(), 'Should create 10 add-ons.');
    }
}
