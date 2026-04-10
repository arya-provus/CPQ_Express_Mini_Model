@isTest
private class AccountControllerTest {

    @testSetup
    static void setup() {
        List<Account> accounts = new List<Account>{
            new Account(Name='Alpha Corp', Type='Customer', Industry='Technology', Phone='1112223333', Website='alpha.com'),
            new Account(Name='Beta Inc', Type='Partner', Industry='Finance', Phone='4445556666', Website='beta.com'),
            new Account(Name='Gamma Ltd', Type='Customer', Industry='Technology', Phone='7778889999')
        };
        insert accounts;
    }

    @isTest
    static void testGetAccountsNoFilters() {
        Test.startTest();
        List<Account> results = AccountController.getAccounts(null, null, null);
        Test.stopTest();
        Assert.isTrue(results.size() >= 3);
    }

    @isTest
    static void testGetAccountsWithSearchTerm() {
        Test.startTest();
        List<Account> results = AccountController.getAccounts('Alpha', null, null);
        Test.stopTest();
        Assert.areEqual(1, results.size());
        Assert.areEqual('Alpha Corp', results[0].Name);
    }

    @isTest
    static void testGetAccountsWithTypeFilter() {
        Test.startTest();
        List<Account> results = AccountController.getAccounts(null, 'Partner', null);
        Test.stopTest();
        Assert.areEqual(1, results.size());
        Assert.areEqual('Partner', results[0].Type);
    }

    @isTest
    static void testGetAccountsWithIndustryFilter() {
        Test.startTest();
        List<Account> results = AccountController.getAccounts(null, null, 'Finance');
        Test.stopTest();
        Assert.areEqual(1, results.size());
        Assert.areEqual('Finance', results[0].Industry);
    }

    @isTest
    static void testGetAccountsWithAllFilters() {
        Test.startTest();
        List<Account> results = AccountController.getAccounts('Alpha', 'Customer', 'Technology');
        Test.stopTest();
        Assert.areEqual(1, results.size());
    }

    @isTest
    static void testGetAccountsAllTypesFilter() {
        // 'All Types' should be ignored
        Test.startTest();
        List<Account> results = AccountController.getAccounts(null, 'All Types', null);
        Test.stopTest();
        Assert.isTrue(results.size() >= 3);
    }

    @isTest
    static void testGetAccountsAllIndustriesFilter() {
        Test.startTest();
        List<Account> results = AccountController.getAccounts(null, null, 'All Industries');
        Test.stopTest();
        Assert.isTrue(results.size() >= 3);
    }

    @isTest
    static void testGetAccountsByPhoneSearch() {
        Test.startTest();
        List<Account> results = AccountController.getAccounts('111', null, null);
        Test.stopTest();
        Assert.isTrue(results.size() >= 1);
    }

    @isTest
    static void testDeleteAccount() {
        Account acc = [SELECT Id FROM Account WHERE Name='Alpha Corp' LIMIT 1];
        Test.startTest();
        AccountController.deleteAccount(acc.Id);
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE Id = :acc.Id]);
    }

    @isTest
    static void testGetAccountTypes() {
        Test.startTest();
        List<String> types = AccountController.getAccountTypes();
        Test.stopTest();
        Assert.isNotNull(types);
        Assert.isTrue(types.size() > 0);
    }

    @isTest
    static void testGetAccountIndustries() {
        Test.startTest();
        List<String> industries = AccountController.getAccountIndustries();
        Test.stopTest();
        Assert.isNotNull(industries);
        Assert.isTrue(industries.size() > 0);
    }
}
