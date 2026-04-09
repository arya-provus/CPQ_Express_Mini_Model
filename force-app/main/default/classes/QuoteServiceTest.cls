@isTest
private class QuoteServiceTest {
    
    @testSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount('Test Account');
        TestDataFactory.createOpportunity(acc.Id, 'Test Opp');
    }

    @isTest
    static void testCreateQuotePositive() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        String quoteId = QuoteController.createQuote('New Quote', acc.Id, Date.today(), Date.today().addDays(30));
        Test.stopTest();

        Assert.isNotNull(quoteId, 'Quote should be created.');
        Quote q = [SELECT Name, OpportunityId, Pricebook2Id, Status FROM Quote WHERE Id = :quoteId];
        Assert.areEqual('New Quote', q.Name);
        Assert.isNotNull(q.OpportunityId, 'Quote should be associated with an Opportunity.');
        Assert.isNotNull(q.Pricebook2Id, 'Quote should have a Pricebook assigned.');
    }

    @isTest
    static void testCreateQuoteSimple() {
        Test.startTest();
        String quoteId = QuoteController.createQuoteSimple('Simple Quote');
        Test.stopTest();

        Assert.isNotNull(quoteId, 'Quote should be created via simple method.');
    }

    @isTest
    static void testCreateQuoteNegative() {
        Test.startTest();
        try {
            QuoteController.createQuote(null, null, null, null);
            Assert.fail('Should have thrown an exception for null name.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Quote name cannot be empty.'), 'Error message should match.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetQuotes() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        TestDataFactory.createQuote(opp.Id, 'Quote 1');
        TestDataFactory.createQuote(opp.Id, 'Quote 2');

        Test.startTest();
        List<Quote> quotes = QuoteController.getQuotes();
        Test.stopTest();

        Assert.isTrue(quotes.size() >= 2, 'Should return at least 2 quotes.');
    }

    @isTest
    static void testGetQuoteById() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Detail Quote');

        Test.startTest();
        Quote result = QuoteController.getQuoteById(q.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return the quote.');
        Assert.areEqual('Detail Quote', result.Name);
    }

    @isTest
    static void testGetQuoteSummary() {
        Test.startTest();
        Map<String, Object> summary = QuoteController.getQuoteSummary();
        Test.stopTest();

        Assert.isNotNull(summary, 'Summary should not be null.');
        Assert.isTrue(summary.containsKey('draftCount'), 'Should contain draftCount.');
    }

    @isTest
    static void testUpdateQuoteStatus() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Status Quote');

        Test.startTest();
        QuoteController.updateQuoteStatus(q.Id, 'Approved');
        Test.stopTest();

        Quote updated = [SELECT Status FROM Quote WHERE Id = :q.Id];
        Assert.areEqual('Approved', updated.Status);
    }

    @isTest
    static void testBulkCreateQuotes() {
        QuoteService service = new QuoteService();
        Test.startTest();
        for(Integer i=0; i<10; i++) {
            service.createQuote('Bulk Quote ' + i);
        }
        Test.stopTest();

        List<Quote> quotes = [SELECT Id FROM Quote WHERE Name LIKE 'Bulk Quote %'];
        Assert.areEqual(10, quotes.size(), 'Should create 10 bulk quotes.');
    }
}
