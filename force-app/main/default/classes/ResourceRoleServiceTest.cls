@isTest
private class ResourceRoleServiceTest {

    @isTest
    static void testCreateRolePositive() {
        Test.startTest();
        Id roleId = ResourceRoleController.createRole('QA Engineer', 45.00, 'QA');
        Test.stopTest();

        Assert.isNotNull(roleId, 'Role should be created.');
        Resource_Role__c role = [SELECT Name, Base_Rate__c, Category__c, IsActive__c FROM Resource_Role__c WHERE Id = :roleId];
        Assert.areEqual('QA Engineer', role.Name);
        Assert.areEqual(45.00, role.Base_Rate__c);
        Assert.areEqual('QA', role.Category__c);
        Assert.isTrue(role.IsActive__c);
    }

    @isTest
    static void testCreateRoleNegative() {
        Test.startTest();
        try {
            ResourceRoleController.createRole('', -10.00, 'QA');
            Assert.fail('Should have failed for blank name.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Resource Role name is required.'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetActiveRoles() {
        ResourceRoleController.createRole('Active Role', 30.00, 'Development');

        Test.startTest();
        List<Resource_Role__c> roles = ResourceRoleController.getActiveRoles();
        Test.stopTest();

        Assert.isTrue(roles.size() >= 1, 'Should return at least one active role.');
    }

    @isTest
    static void testGetAllRoles() {
        ResourceRoleController.createRole('All Role', 30.00, 'Design');

        Test.startTest();
        List<Resource_Role__c> roles = ResourceRoleController.getAllRoles();
        Test.stopTest();

        Assert.isTrue(roles.size() >= 1, 'Should return at least one role.');
    }

    @isTest
    static void testDeleteRole() {
        Id roleId = ResourceRoleController.createRole('Delete Me', 20.00, 'DevOps');

        Test.startTest();
        ResourceRoleController.deleteRole(roleId);
        Test.stopTest();

        List<Resource_Role__c> remaining = [SELECT Id FROM Resource_Role__c WHERE Id = :roleId];
        Assert.areEqual(0, remaining.size(), 'Role should be deleted.');
    }

    @isTest
    static void testBulkCreateRoles() {
        ResourceRoleService service = new ResourceRoleService();
        Test.startTest();
        for(Integer i=0; i<10; i++) {
            service.createRole('Role ' + i, 25.00 + i, 'QA');
        }
        Test.stopTest();

        List<Resource_Role__c> roles = [SELECT Id FROM Resource_Role__c WHERE Name LIKE 'Role %'];
        Assert.areEqual(10, roles.size(), 'Should create 10 roles.');
    }
}
