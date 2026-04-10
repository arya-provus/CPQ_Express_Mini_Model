@isTest
private class CompanySettingsControllerTest {

    @isTest
    static void testGetCompanySettingsNoRecord() {
        // No org default exists — should return fallback defaults
        Test.startTest();
        CompanySettingsController.CompanySettingsWrapper wrapper = CompanySettingsController.getCompanySettings();
        Test.stopTest();

        Assert.isNotNull(wrapper);
        Assert.isNotNull(wrapper.settings);
        Assert.isNotNull(wrapper.currentUserId);
        // In test context, isAdmin is forced true
        Assert.isTrue(wrapper.isAdmin);
        // Fallback values should be present
        Assert.areEqual('provus', wrapper.settings.Company_Name__c);
    }

    @isTest
    static void testGetCompanySettingsWithExistingRecord() {
        // Pre-insert org default
        Company_Settings__c cs = new Company_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Company_Name__c = 'Acme Corp',
            City__c = 'Mumbai',
            State__c = 'MH',
            Country__c = 'India',
            Phone__c = '9876543210'
        );
        insert cs;

        Test.startTest();
        CompanySettingsController.CompanySettingsWrapper wrapper = CompanySettingsController.getCompanySettings();
        Test.stopTest();

        Assert.areEqual('Acme Corp', wrapper.settings.Company_Name__c);
        Assert.areEqual('Mumbai', wrapper.settings.City__c);
    }

    @isTest
    static void testSaveCompanySettingsInsert() {
        Company_Settings__c cs = new Company_Settings__c(
            Company_Name__c = 'New Corp',
            City__c = 'Pune',
            State__c = 'MH',
            Country__c = 'India',
            Phone__c = '1234567890'
        );
        Test.startTest();
        CompanySettingsController.saveCompanySettings(cs);
        Test.stopTest();

        Company_Settings__c saved = Company_Settings__c.getOrgDefaults();
        Assert.areEqual('New Corp', saved.Company_Name__c);
    }

    @isTest
    static void testSaveCompanySettingsUpdate() {
        Company_Settings__c cs = new Company_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Company_Name__c = 'Old Corp',
            Phone__c = '0000000000'
        );
        insert cs;

        cs.Company_Name__c = 'Updated Corp';
        Test.startTest();
        CompanySettingsController.saveCompanySettings(cs);
        Test.stopTest();

        Company_Settings__c updated = Company_Settings__c.getOrgDefaults();
        Assert.areEqual('Updated Corp', updated.Company_Name__c);
    }

    @isTest
    static void testUpdateLogoVisibility() {
        // Create a ContentVersion (file) to share
        ContentVersion cv = new ContentVersion(
            Title = 'TestLogo',
            PathOnClient = 'logo.png',
            VersionData = Blob.valueOf('fake image data'),
            IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Test.startTest();
        // Should not throw in test context
        CompanySettingsController.updateLogoVisibility(docId);
        Test.stopTest();

        // Just verify no exception thrown
        Assert.isTrue(true);
    }

    @isTest
    static void testGetCompanySettingsIsAdminFlagInTest() {
        // Test.isRunningTest() makes isAdmin = true regardless of permission set
        Test.startTest();
        CompanySettingsController.CompanySettingsWrapper w = CompanySettingsController.getCompanySettings();
        Test.stopTest();
        Assert.isTrue(w.isAdmin, 'isAdmin should be true in test context');
    }
}
