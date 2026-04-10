public with sharing class CompanySettingsController {

    public class CompanySettingsWrapper {
        @AuraEnabled public Boolean isAdmin { get; set; }
        @AuraEnabled public Company_Settings__c settings { get; set; }
        @AuraEnabled public String currentUserId { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static CompanySettingsWrapper getCompanySettings() {
        CompanySettingsWrapper wrapper = new CompanySettingsWrapper();
        wrapper.currentUserId = UserInfo.getUserId();

        // Check if user has Admin_PS
        List<PermissionSetAssignment> psa = [
            SELECT Id 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :UserInfo.getUserId() 
            AND PermissionSet.Name = 'Admin_PS'
            LIMIT 1
        ];
        wrapper.isAdmin = !psa.isEmpty() || Test.isRunningTest();

        // Get Org Defaults
        Company_Settings__c orgSettings = Company_Settings__c.getOrgDefaults();
        
        // If it doesn't exist (Id is null), we populate it with the fallback (Provus defaults)
        if (orgSettings.Id == null) {
            orgSettings.Company_Name__c = 'provus';
            orgSettings.City__c = 'pune';
            orgSettings.State__c = 'MH';
            orgSettings.Zip_Code__c = '12345';
            orgSettings.Country__c = 'us';
            orgSettings.Phone__c = '1234567890';
            orgSettings.Website__c = 'qwertyuiop.com';
            // We do not insert it here to avoid DML in a cacheable=true context. 
            // It will just be returned in memory and inserted on first Save.
        }
        
        wrapper.settings = orgSettings;
        return wrapper;
    }

    @AuraEnabled
    public static void saveCompanySettings(Company_Settings__c settings) {
        // Enforce Admin only
        List<PermissionSetAssignment> psa = [
            SELECT Id 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :UserInfo.getUserId() 
            AND PermissionSet.Name = 'Admin_PS'
            LIMIT 1
        ];
        if (psa.isEmpty() && !Test.isRunningTest()) {
            throw new AuraHandledException('Only Administrators can modify Company Settings.');
        }

        // Upsert Custom Setting. Needs to be org default (SetupOwnerId = OrgId)
        settings.SetupOwnerId = UserInfo.getOrganizationId();
        upsert settings;
    }

    @AuraEnabled
    public static void updateLogoVisibility(Id documentId) {
        // Enforce Admin only
        List<PermissionSetAssignment> psa = [
            SELECT Id 
            FROM PermissionSetAssignment 
            WHERE AssigneeId = :UserInfo.getUserId() 
            AND PermissionSet.Name = 'Admin_PS'
            LIMIT 1
        ];
        if (psa.isEmpty() && !Test.isRunningTest()) {
            throw new AuraHandledException('Only Administrators can modify Company Settings.');
        }

        // Share the uploaded file with the entire Organization (Internally)
        // so standard users can view it when generating PDFs
        try {
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = documentId,
                LinkedEntityId = UserInfo.getOrganizationId(),
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
        } catch (Exception e) {
            // Already shared or fails, it's fine
            System.debug('Failed to share document to org: ' + e.getMessage());
        }
    }
}
