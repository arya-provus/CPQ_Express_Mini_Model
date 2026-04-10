@isTest
private class QuoteLineServiceTest {

    @testSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount('QLI Account');
        Opportunity opp = TestDataFactory.createOpportunity(acc.Id, 'QLI Opp');
        TestDataFactory.createQuote(opp.Id, 'QLI Quote');
    }

    private static Quote getQuote() {
        return [SELECT Id FROM Quote LIMIT 1];
    }

    private static QuoteLineItem addProductLine(Id quoteId, String prodName, Decimal price) {
        Product2 prod = TestDataFactory.createProduct(prodName, true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, price);
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId=quoteId, Product2Id=prod.Id, PricebookEntryId=pbe.Id,
            Quantity=1, UnitPrice=price, Base_Rate__c=price, Cost__c=price*0.6, Discount__c=0
        );
        insert qli;
        return qli;
    }

    // ────────────── ADD ITEMS TO QUOTE ──────────────

    @isTest
    static void testAddProductToQuote() {
        Quote q = getQuote();
        Product2 prod = TestDataFactory.createProduct('P1', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 300);
        Test.startTest();
        QuoteLineController.addItemsToQuote(q.Id, new List<Id>{prod.Id}, null, null);
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id]);
    }

    @isTest
    static void testAddResourceRoleToQuote() {
        Quote q = getQuote();
        Resource_Role__c role = new Resource_Role__c(Name='Dev', Base_Rate__c=100, Cost__c=60);
        insert role;
        Test.startTest();
        QuoteLineController.addItemsToQuote(q.Id, null, new List<Id>{role.Id}, null);
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id]);
    }

    @isTest
    static void testAddAddonToQuote() {
        Quote q = getQuote();
        Add_On__c addon = new Add_On__c(Name='Addon1', Price__c=200, Cost__c=100, IsActive__c=true);
        insert addon;
        Test.startTest();
        QuoteLineController.addItemsToQuote(q.Id, null, null, new List<Id>{addon.Id});
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id]);
    }

    @isTest
    static void testAddItemsNullQuoteId() {
        Test.startTest();
        try {
            QuoteLineController.addItemsToQuote(null, new List<Id>(), null, null);
            Assert.fail('Should throw');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testAddItemsToLockedQuote() {
        Quote q = getQuote();
        Product2 prod = TestDataFactory.createProduct('P Lock', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        QuoteController.submitForApproval(q.Id, 'Lock');
        Test.startTest();
        try {
            QuoteLineController.addItemsToQuote(q.Id, new List<Id>{prod.Id}, null, null);
            Assert.fail();
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testAddItemsAllThreeTypes() {
        Quote q = getQuote();
        Product2 prod = TestDataFactory.createProduct('Multi P', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        Resource_Role__c role = new Resource_Role__c(Name='Analyst', Base_Rate__c=80, Cost__c=50);
        insert role;
        Add_On__c addon = new Add_On__c(Name='Multi Addon', Price__c=150, Cost__c=80, IsActive__c=true);
        insert addon;
        Test.startTest();
        QuoteLineController.addItemsToQuote(q.Id, new List<Id>{prod.Id}, new List<Id>{role.Id}, new List<Id>{addon.Id});
        Test.stopTest();
        Assert.areEqual(3, [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id]);
    }

    @isTest
    static void testAddRoleWithWeekPeriod() {
        Quote q = getQuote();
        update new Quote(Id=q.Id, Quote_Time_Period__c='Weeks');
        Resource_Role__c role = new Resource_Role__c(Name='Week Role', Base_Rate__c=50, Cost__c=30);
        insert role;
        Test.startTest();
        QuoteLineController.addItemsToQuote(q.Id, null, new List<Id>{role.Id}, null);
        Test.stopTest();
        QuoteLineItem qli = [SELECT UnitPrice FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 1];
        Assert.areEqual(50 * 40, qli.UnitPrice);
    }

    @isTest
    static void testAddRoleWithQuarterPeriod() {
        Quote q = getQuote();
        update new Quote(Id=q.Id, Quote_Time_Period__c='Quarters');
        Resource_Role__c role = new Resource_Role__c(Name='Qtr Role', Base_Rate__c=50, Cost__c=30);
        insert role;
        Test.startTest();
        QuoteLineController.addItemsToQuote(q.Id, null, new List<Id>{role.Id}, null);
        Test.stopTest();
        QuoteLineItem qli = [SELECT UnitPrice FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 1];
        Assert.areEqual(50 * 480, qli.UnitPrice);
    }

    // ────────────── GET QUOTE LINES ──────────────

    @isTest
    static void testGetQuoteLines() {
        Quote q = getQuote();
        addProductLine(q.Id, 'GetLines Prod', 100);
        Test.startTest();
        List<QuoteLineItem> lines = QuoteLineController.getQuoteLines(q.Id);
        Test.stopTest();
        Assert.isTrue(lines.size() >= 1);
    }

    // ────────────── UPDATE LINE ──────────────

    @isTest
    static void testUpdateQuoteLine() {
        Quote q = getQuote();
        QuoteLineItem qli = addProductLine(q.Id, 'Update Prod', 200);
        Test.startTest();
        QuoteLineController.updateQuoteLine(qli.Id, 10.0, 'Fix Bug', Date.today(), Date.today().addDays(10), 200.0, 2.0);
        Test.stopTest();
        QuoteLineItem updated = [SELECT Discount__c, Task__c, Quantity FROM QuoteLineItem WHERE Id = :qli.Id];
        Assert.areEqual(10.0, updated.Discount__c);
        Assert.areEqual('Fix Bug', updated.Task__c);
        Assert.areEqual(2, updated.Quantity);
    }

    @isTest
    static void testUpdateQuoteLineNullId() {
        Test.startTest();
        try {
            QuoteLineController.updateQuoteLine(null, 5.0, 'task', null, null, null, null);
            Assert.fail();
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateQuoteLinesInBulk() {
        Quote q = getQuote();
        QuoteLineItem qli = addProductLine(q.Id, 'Bulk Update Prod', 100);
        qli.Base_Rate__c = 120;
        Test.startTest();
        QuoteLineController.updateQuoteLines(new List<QuoteLineItem>{qli});
        Test.stopTest();
        QuoteLineItem updated = [SELECT UnitPrice FROM QuoteLineItem WHERE Id = :qli.Id];
        Assert.areEqual(120, updated.UnitPrice);
    }

    @isTest
    static void testUpdateQuoteLinesEmpty() {
        Test.startTest();
        QuoteLineController.updateQuoteLines(new List<QuoteLineItem>());
        Test.stopTest();
        // no exception = pass
        Assert.isTrue(true);
    }

    // ────────────── DELETE LINE ──────────────

    @isTest
    static void testDeleteQuoteLine() {
        Quote q = getQuote();
        QuoteLineItem qli = addProductLine(q.Id, 'Del Prod', 100);
        Test.startTest();
        QuoteLineController.deleteQuoteLine(qli.Id);
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM QuoteLineItem WHERE Id = :qli.Id]);
    }

    @isTest
    static void testDeleteQuoteLineNullId() {
        Test.startTest();
        try {
            QuoteLineController.deleteQuoteLine(null);
            Assert.fail();
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // ────────────── HELPER SHORTHAND METHODS ──────────────

    @isTest
    static void testAddQuoteLine() {
        Quote q = getQuote();
        Product2 prod = TestDataFactory.createProduct('Add Line P', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        Test.startTest();
        Id lineId = QuoteLineController.addQuoteLine(q.Id, prod.Id, 1);
        Test.stopTest();
        Assert.isNotNull(lineId);
    }

    @isTest
    static void testAddResourceRoleLine() {
        Quote q = getQuote();
        Resource_Role__c role = new Resource_Role__c(Name='Short Role', Base_Rate__c=60, Cost__c=40);
        insert role;
        Test.startTest();
        Id lineId = QuoteLineController.addResourceRoleLine(q.Id, role.Id, 1);
        Test.stopTest();
        Assert.isNotNull(lineId);
    }

    @isTest
    static void testAddAddOnLine() {
        Quote q = getQuote();
        Add_On__c addon = new Add_On__c(Name='Short Addon', Price__c=100, Cost__c=60, IsActive__c=true);
        insert addon;
        Test.startTest();
        Id lineId = QuoteLineController.addAddOnLine(q.Id, addon.Id, 1);
        Test.stopTest();
        Assert.isNotNull(lineId);
    }
}
