@isTest
private class ResourceRoleServiceTest {

    @isTest
    static void testCreateRolePositive() {
        Test.startTest();
        Id roleId = ResourceRoleController.createRole('QA Engineer', 45.00, 30.00, 'Hours', 'NY', 'NY', 'USA');
        Test.stopTest();

        Assert.isNotNull(roleId, 'Role should be created.');
        Resource_Role__c role = [SELECT Name, Base_Rate__c, IsActive__c FROM Resource_Role__c WHERE Id = :roleId];
        Assert.areEqual('QA Engineer', role.Name);
        Assert.areEqual(45.00, role.Base_Rate__c);
        Assert.isTrue(role.IsActive__c);
    }

    @isTest
    static void testCreateRoleNegative() {
        Test.startTest();
        try {
            ResourceRoleController.createRole('', -10.00, -5.00, 'Hours', '', '', '');
            Assert.fail('Should have failed for blank name.');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateRole() {
        Id roleId = ResourceRoleController.createRole('Orig Role', 30.00, 20.00, 'Hours', '', '', '');
        Test.startTest();
        ResourceRoleController.updateRole(roleId, 'Updated Role', 40.00, 25.00, 'Days', 'SF', 'CA', 'USA');
        Test.stopTest();
        Resource_Role__c role = [SELECT Name, Base_Rate__c, City__c FROM Resource_Role__c WHERE Id = :roleId];
        Assert.areEqual('Updated Role', role.Name);
        Assert.areEqual(40.00, role.Base_Rate__c);
        Assert.areEqual('SF', role.City__c);
    }

    @isTest
    static void testGetActiveRoles() {
        ResourceRoleController.createRole('Active Role', 30.00, 20.00, 'Hours', '', '', '');

        Test.startTest();
        List<Resource_Role__c> roles = ResourceRoleController.getActiveRoles();
        Test.stopTest();

        Assert.isTrue(roles.size() >= 1, 'Should return at least one active role.');
    }

    @isTest
    static void testGetAllRoles() {
        ResourceRoleController.createRole('All Role', 30.00, 20.00, 'Hours', '', '', '');

        Test.startTest();
        List<Resource_Role__c> roles = ResourceRoleController.getAllRoles();
        Test.stopTest();

        Assert.isTrue(roles.size() >= 1, 'Should return at least one role.');
    }

    @isTest
    static void testDeleteRole() {
        Id roleId = ResourceRoleController.createRole('Delete Me', 20.00, 10.00, 'Hours', '', '', '');

        Test.startTest();
        ResourceRoleController.deleteRole(roleId);
        Test.stopTest();

        List<Resource_Role__c> remaining = [SELECT Id FROM Resource_Role__c WHERE Id = :roleId];
        Assert.areEqual(0, remaining.size(), 'Role should be deleted.');
    }
    
    @isTest
    static void testDeleteResourceRoles() {
        Id roleId1 = ResourceRoleController.createRole('Del 1', 20.00, 10.00, 'Hours', '', '', '');
        Id roleId2 = ResourceRoleController.createRole('Del 2', 20.00, 10.00, 'Hours', '', '', '');
        Test.startTest();
        ResourceRoleController.deleteResourceRoles(new List<Id>{roleId1, roleId2});
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Resource_Role__c WHERE Id IN (:roleId1, :roleId2)]);
    }

    @isTest
    static void testBulkCreateRoles() {
        ResourceRoleService service = new ResourceRoleService();
        Test.startTest();
        for(Integer i=0; i<10; i++) {
            service.createRole('Role ' + i, 25.00 + i, 15.00 + i, 'Hours', '', '', '');
        }
        Test.stopTest();

        List<Resource_Role__c> roles = [SELECT Id FROM Resource_Role__c WHERE Name LIKE 'Role %'];
        Assert.areEqual(10, roles.size(), 'Should create 10 roles.');
    }
}
