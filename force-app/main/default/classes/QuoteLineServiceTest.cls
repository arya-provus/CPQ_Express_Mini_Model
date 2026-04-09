@isTest
private class QuoteLineServiceTest {
    
    @testSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount('Test Account');
        Opportunity opp = TestDataFactory.createOpportunity(acc.Id, 'Test Opp');
        TestDataFactory.createQuote(opp.Id, 'Test Quote');
        
        Product2 p1 = TestDataFactory.createProduct('Product 1', true);
        TestDataFactory.createStandardPricebookEntry(p1.Id, 100.00);

        // Create a resource role for testing
        Resource_Role__c role = new Resource_Role__c(
            Name = 'QA Lead',
            Base_Rate__c = 50.00,
            Category__c = 'QA',
            IsActive__c = true
        );
        insert role;
    }

    @isTest
    static void testAddQuoteLinePositive() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Product2 p = [SELECT Id FROM Product2 WHERE Name = 'Product 1' LIMIT 1];

        Test.startTest();
        Id lineId = QuoteLineController.addQuoteLine(q.Id, p.Id, 2);
        Test.stopTest();

        Assert.isNotNull(lineId, 'Line item should be created.');
        QuoteLineItem qli = [SELECT Quantity, UnitPrice, TotalPrice FROM QuoteLineItem WHERE Id = :lineId];
        Assert.areEqual(2, qli.Quantity);
        Assert.areEqual(100.00, qli.UnitPrice);
        Assert.areEqual(200.00, qli.TotalPrice);
    }

    @isTest
    static void testAddQuoteLineNegative() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        try {
            QuoteLineController.addQuoteLine(q.Id, null, 1);
            Assert.fail('Should have failed for null product.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Invalid input') || e.getMessage().contains('required'));
        }
        Test.stopTest();
    }

    @isTest
    static void testAddResourceRoleLine() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Resource_Role__c role = [SELECT Id FROM Resource_Role__c WHERE Name = 'QA Lead' LIMIT 1];

        Test.startTest();
        Id lineId = QuoteLineController.addResourceRoleLine(q.Id, role.Id, 3);
        Test.stopTest();

        Assert.isNotNull(lineId, 'Resource role line item should be created.');
        QuoteLineItem qli = [SELECT Quantity, UnitPrice, Resource_Role__c FROM QuoteLineItem WHERE Id = :lineId];
        Assert.areEqual(3, qli.Quantity);
        Assert.areEqual(50.00, qli.UnitPrice);
        Assert.areEqual(role.Id, qli.Resource_Role__c);
    }

    @isTest
    static void testUpdateQuoteLine() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Product2 p = [SELECT Id FROM Product2 WHERE Name = 'Product 1' LIMIT 1];
        Id lineId = QuoteLineController.addQuoteLine(q.Id, p.Id, 1);

        Test.startTest();
        QuoteLineController.updateQuoteLine(lineId, 10.0, 'Testing', Date.today(), Date.today().addDays(5), null, null);
        Test.stopTest();

        QuoteLineItem updated = [SELECT Discount__c, Task__c, Start_Date__c FROM QuoteLineItem WHERE Id = :lineId];
        Assert.areEqual(10.0, updated.Discount__c);
        Assert.areEqual('Testing', updated.Task__c);
    }

    @isTest
    static void testDeleteQuoteLine() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Product2 p = [SELECT Id FROM Product2 WHERE Name = 'Product 1' LIMIT 1];
        Id lineId = QuoteLineController.addQuoteLine(q.Id, p.Id, 1);

        Test.startTest();
        QuoteLineController.deleteQuoteLine(lineId);
        Test.stopTest();

        List<QuoteLineItem> remaining = [SELECT Id FROM QuoteLineItem WHERE Id = :lineId];
        Assert.areEqual(0, remaining.size(), 'Line item should be deleted.');
    }

    @isTest
    static void testGetQuoteLines() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Product2 p = [SELECT Id FROM Product2 WHERE Name = 'Product 1' LIMIT 1];
        QuoteLineController.addQuoteLine(q.Id, p.Id, 1);

        Test.startTest();
        List<QuoteLineItem> lines = QuoteLineController.getQuoteLines(q.Id);
        Test.stopTest();

        Assert.isTrue(lines.size() >= 1, 'Should return at least one line item.');
    }

    @isTest
    static void testBulkAddQuoteLines() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        QuoteLineService service = new QuoteLineService();
        Test.startTest();
        for(Integer i=0; i<5; i++) {
            Product2 p = TestDataFactory.createProduct('Bulk Prod ' + i, true);
            TestDataFactory.createStandardPricebookEntry(p.Id, 50.00);
            service.addQuoteLine(q.Id, p.Id, 2);
        }
        Test.stopTest();

        List<QuoteLineItem> lines = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id];
        Assert.areEqual(5, lines.size(), 'Should have 5 bulk lines.');
    }
}
