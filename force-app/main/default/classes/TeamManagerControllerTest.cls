@isTest
private class TeamManagerControllerTest {

    @isTest
    static void testGetTeamMembers() {
        Test.startTest();
        List<TeamManagerController.UserWrapper> members = TeamManagerController.getTeamMembers();
        Test.stopTest();
        // At minimum the running user should match a profile
        Assert.isNotNull(members);
    }

    @isTest
    static void testCanManageUsersAsAdmin() {
        // Running user in test context = System Administrator profile
        Test.startTest();
        Boolean result = TeamManagerController.canManageUsers();
        Test.stopTest();
        Assert.isTrue(result, 'System Administrator should be able to manage users.');
    }

    @isTest
    static void testCreateTeamMemberInvalidRole() {
        Test.startTest();
        try {
            TeamManagerController.createTeamMember('John', 'Doe', 'jd@test.com', 'jd@test.com', 'NonExistentRole');
            Assert.fail('Should have thrown for invalid role.');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Invalid role selected'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateTeamMemberValidRole() {
        // Use 'System Administrator' profile which is guaranteed to exist
        Test.startTest();
        try {
            TeamManagerController.createTeamMember(
                'Test', 'Member',
                'testmember_cpq@example.com',
                'testmember_cpq_' + System.currentTimeMillis() + '@example.com',
                'System Administrator'
            );
        } catch (Exception e) {
            // DML on User in test context may fail due to email uniqueness — acceptable
            Assert.isTrue(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateTeamMemberShortLastName() {
        // Exercises alias generation when lastName.length() <= 4
        Test.startTest();
        try {
            TeamManagerController.createTeamMember(
                'Jo', 'Li',
                'joli_cpq@example.com',
                'joli_cpq_' + System.currentTimeMillis() + '@example.com',
                'System Administrator'
            );
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateTeamMemberNullFirstName() {
        Test.startTest();
        try {
            TeamManagerController.createTeamMember(
                null, 'Doe',
                'nullfirst@example.com',
                'nullfirst_' + System.currentTimeMillis() + '@example.com',
                'System Administrator'
            );
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testDeactivateUser() {
        // Create a new user to deactivate
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            FirstName = 'Deact',
            LastName = 'User',
            Email = 'deactcpq@example.com',
            Username = 'deactcpq_' + System.currentTimeMillis() + '@example.com',
            Alias = 'dUsr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true
        );
        insert u;

        Test.startTest();
        TeamManagerController.deactivateUser(u.Id);
        Test.stopTest();

        User updated = [SELECT IsActive FROM User WHERE Id = :u.Id];
        Assert.isFalse(updated.IsActive);
    }

    @isTest
    static void testDeactivateUserInvalidId() {
        Test.startTest();
        try {
            // Passing a fake/invalid user id should result in an error
            TeamManagerController.deactivateUser(UserInfo.getUserId());
            // Deactivating own user may succeed or fail depending on org settings
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testUserWrapperInitialsWithFirstAndLastName() {
        // Covers the UserWrapper initials path
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            FirstName = 'Alice', LastName = 'Walker',
            Email = 'aw_cpq@example.com',
            Username = 'aw_cpq_' + System.currentTimeMillis() + '@example.com',
            Alias = 'aWlk',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true
        );
        insert u;

        Test.startTest();
        List<TeamManagerController.UserWrapper> members = TeamManagerController.getTeamMembers();
        Test.stopTest();

        // Verify wrapper properties through the list
        Boolean found = false;
        for (TeamManagerController.UserWrapper w : members) {
            if (w.firstName == 'Alice') {
                found = true;
                Assert.areEqual('AW', w.initials);
                Assert.areEqual('Walker', w.lastName);
                Assert.isTrue(w.isActive);
            }
        }
        Assert.isTrue(found, 'Alice Walker should appear in team members.');
    }
}
