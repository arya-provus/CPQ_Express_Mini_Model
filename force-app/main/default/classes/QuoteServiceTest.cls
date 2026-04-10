@isTest
private class QuoteServiceTest {

    @testSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount('Test Account');
        Opportunity opp = TestDataFactory.createOpportunity(acc.Id, 'Test Opp');
        TestDataFactory.createQuote(opp.Id, 'Setup Quote');
    }

    // ────────────── CREATE QUOTE ──────────────

    @isTest
    static void testCreateQuotePositive() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        String quoteId = QuoteController.createQuote('New Quote', acc.Id, opp.Id, Date.today(), Date.today().addDays(30));
        Test.stopTest();

        Assert.isNotNull(quoteId);
        Quote q = [SELECT Name, Status, Pricebook2Id FROM Quote WHERE Id = :quoteId];
        Assert.areEqual('New Quote', q.Name);
        Assert.areEqual('Draft', q.Status);
        Assert.isNotNull(q.Pricebook2Id);
    }

    @isTest
    static void testCreateQuoteSimple() {
        Test.startTest();
        String quoteId = QuoteController.createQuoteSimple('Simple Quote');
        Test.stopTest();
        Assert.isNotNull(quoteId);
    }

    @isTest
    static void testCreateQuoteNullName() {
        Test.startTest();
        try {
            QuoteController.createQuote(null, null, null, null, null);
            Assert.fail('Expected exception');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateQuoteBlankName() {
        Test.startTest();
        try {
            QuoteController.createQuote('   ', null, null, null, null);
            Assert.fail('Expected exception');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // ────────────── GET QUOTES ──────────────

    @isTest
    static void testGetQuotes() {
        Test.startTest();
        List<Quote> quotes = QuoteController.getQuotes();
        Test.stopTest();
        Assert.isTrue(quotes.size() >= 1);
    }

    @isTest
    static void testGetQuoteById() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Quote result = QuoteController.getQuoteById(q.Id);
        Test.stopTest();
        Assert.isNotNull(result);
        Assert.areEqual(q.Id, result.Id);
    }

    @isTest
    static void testGetQuoteSummary() {
        Test.startTest();
        Map<String, Object> summary = QuoteController.getQuoteSummary();
        Test.stopTest();
        Assert.isNotNull(summary);
        Assert.isTrue(summary.containsKey('draftCount'));
        Assert.isTrue(summary.containsKey('totalQuotes'));
    }

    // ────────────── REVENUE BREAKDOWN ──────────────

    @isTest
    static void testGetRevenueBreakdown() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Map<String, Decimal> breakdown = QuoteController.getRevenueBreakdown(q.Id);
        Test.stopTest();
        Assert.isNotNull(breakdown);
        Assert.isTrue(breakdown.containsKey('Labor'));
        Assert.isTrue(breakdown.containsKey('Product'));
        Assert.isTrue(breakdown.containsKey('Addon'));
    }

    @isTest
    static void testGetRevenueBreakdownWithLines() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Revenue Quote');
        Product2 prod = TestDataFactory.createProduct('Test Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        QuoteLineItem qli = new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        insert qli;
        Test.startTest();
        Map<String, Decimal> breakdown = QuoteController.getRevenueBreakdown(q.Id);
        Test.stopTest();
        Assert.areEqual(100, breakdown.get('Product'));
    }

    // ────────────── UPDATE STATUS ──────────────

    @isTest
    static void testUpdateQuoteStatus() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        QuoteController.updateQuoteStatus(q.Id, 'Approved');
        Test.stopTest();
        Quote updated = [SELECT Status FROM Quote WHERE Id = :q.Id];
        Assert.areEqual('Approved', updated.Status);
    }

    @isTest
    static void testUpdateQuoteStatusNullId() {
        Test.startTest();
        try {
            QuoteController.updateQuoteStatus(null, 'Draft');
            Assert.fail('Should throw');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // ────────────── RECALCULATE TOTALS ──────────────

    @isTest
    static void testRecalculateQuoteTotals() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Recalc Quote');
        Product2 prod = TestDataFactory.createProduct('Recalc Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 200);
        QuoteLineItem qli = new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=2, UnitPrice=200, Base_Rate__c=200, Cost__c=100, Discount__c=0);
        insert qli;
        Test.startTest();
        QuoteController.recalculateQuoteTotals(q.Id);
        Test.stopTest();
        Quote updated = [SELECT Subtotal__c, Total_Amount__c FROM Quote WHERE Id = :q.Id];
        Assert.areEqual(400, updated.Subtotal__c);
    }

    @isTest
    static void testRecalcWithWeeklyPeriod() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        update new Quote(Id=q.Id, Quote_Time_Period__c='Weeks');
        Test.startTest();
        QuoteController.recalculateQuoteTotals(q.Id);
        Test.stopTest();
        // Should not throw
        Assert.isNotNull([SELECT Id FROM Quote WHERE Id = :q.Id]);
    }

    @isTest
    static void testRecalcWithQuarterlyPeriod() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        update new Quote(Id=q.Id, Quote_Time_Period__c='Quarters');
        Test.startTest();
        QuoteController.recalculateQuoteTotals(q.Id);
        Test.stopTest();
        Assert.isNotNull([SELECT Id FROM Quote WHERE Id = :q.Id]);
    }

    // ────────────── DISCOUNT ──────────────

    @isTest
    static void testUpdateQuoteDiscount() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Discount Quote');
        Product2 prod = TestDataFactory.createProduct('Disc Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 500);
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=500, Base_Rate__c=500, Cost__c=300, Discount__c=0);
        Test.startTest();
        QuoteController.updateQuoteDiscount(q.Id, 10);
        Test.stopTest();
        Quote updated = [SELECT Additional_Discount__c FROM Quote WHERE Id = :q.Id];
        Assert.areEqual(10, updated.Additional_Discount__c);
    }

    @isTest
    static void testUpdateQuoteDiscountNullId() {
        Test.startTest();
        try {
            QuoteController.updateQuoteDiscount(null, 10);
            Assert.fail('Should throw');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // ────────────── APPROVAL WORKFLOW ──────────────

    @isTest
    static void testSubmitForApproval() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Approval Quote');
        Product2 prod = TestDataFactory.createProduct('AP Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        Test.startTest();
        QuoteController.submitForApproval(q.Id, 'Please review');
        Test.stopTest();
        Quote updated = [SELECT Status, Is_Locked__c FROM Quote WHERE Id = :q.Id];
        Assert.areEqual('In Review', updated.Status);
        Assert.isTrue(updated.Is_Locked__c);
    }

    @isTest
    static void testSubmitForApprovalNoLines() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Empty Quote');
        Test.startTest();
        try {
            QuoteController.submitForApproval(q.Id, 'No lines');
            Assert.fail('Should throw');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitForApprovalNonDraft() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Already Approved');
        update new Quote(Id=q.Id, Status='Approved');
        Test.startTest();
        try {
            QuoteController.submitForApproval(q.Id, 'Comments');
            Assert.fail('Should throw');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testRecallQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Recall Quote');
        Product2 prod = TestDataFactory.createProduct('Rec Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        QuoteController.submitForApproval(q.Id, 'Submit');
        Test.startTest();
        QuoteController.recallQuote(q.Id);
        Test.stopTest();
        Quote updated = [SELECT Status, Is_Locked__c FROM Quote WHERE Id = :q.Id];
        Assert.areEqual('Draft', updated.Status);
        Assert.isFalse(updated.Is_Locked__c);
    }

    @isTest
    static void testRecallNonReviewQuote() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        try {
            QuoteController.recallQuote(q.Id);
            Assert.fail('Should throw');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('in review'));
        }
        Test.stopTest();
    }

    @isTest
    static void testApproveQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'To Approve');
        Product2 prod = TestDataFactory.createProduct('Appr Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        QuoteController.submitForApproval(q.Id, 'Submit');
        Test.startTest();
        QuoteController.approveQuote(q.Id, 'Looks good');
        Test.stopTest();
        Quote updated = [SELECT Status FROM Quote WHERE Id = :q.Id];
        Assert.areEqual('Approved', updated.Status);
    }

    @isTest
    static void testApproveNonReviewQuote() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        try {
            QuoteController.approveQuote(q.Id, 'Should fail');
            Assert.fail();
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('in review'));
        }
        Test.stopTest();
    }

    @isTest
    static void testRejectQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'To Reject');
        Product2 prod = TestDataFactory.createProduct('Rej Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        QuoteController.submitForApproval(q.Id, 'Submit');
        Test.startTest();
        QuoteController.rejectQuote(q.Id, 'Not valid');
        Test.stopTest();
        Quote updated = [SELECT Status FROM Quote WHERE Id = :q.Id];
        Assert.areEqual('Rejected', updated.Status);
    }

    @isTest
    static void testRejectNonReviewQuote() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        try {
            QuoteController.rejectQuote(q.Id, 'Should fail');
            Assert.fail();
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('in review'));
        }
        Test.stopTest();
    }

    // ────────────── APPROVAL HISTORY ──────────────

    @isTest
    static void testGetApprovalHistory() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'History Quote');
        Product2 prod = TestDataFactory.createProduct('Hist Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        QuoteController.submitForApproval(q.Id, 'Submitted');
        Test.startTest();
        List<Quote_Approval_History__c> history = QuoteController.getApprovalHistory(q.Id);
        Test.stopTest();
        Assert.isTrue(history.size() >= 1);
    }

    // ────────────── DELETE QUOTES ──────────────

    @isTest
    static void testDeleteQuotes() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q1 = TestDataFactory.createQuote(opp.Id, 'Delete Q1');
        Quote q2 = TestDataFactory.createQuote(opp.Id, 'Delete Q2');
        Test.startTest();
        QuoteController.deleteQuotes(new List<Id>{ q1.Id, q2.Id });
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Quote WHERE Id IN (:q1.Id, :q2.Id)]);
    }

    // ────────────── LOCK CHECK ──────────────

    @isTest
    static void testCheckLockOnLockedQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = TestDataFactory.createQuote(opp.Id, 'Locked Quote');
        Product2 prod = TestDataFactory.createProduct('Lock Prod', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 100);
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=prod.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);
        QuoteController.submitForApproval(q.Id, 'Lock it');
        Test.startTest();
        try {
            QuoteController.updateQuoteDiscount(q.Id, 5);
            Assert.fail('Should throw — quote is locked');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // ────────────── BULK TEST ──────────────

    @isTest
    static void testBulkCreateQuotes() {
        QuoteService service = new QuoteService();
        Test.startTest();
        for (Integer i = 0; i < 10; i++) {
            service.createQuote('Bulk Quote ' + i);
        }
        Test.stopTest();
        Assert.areEqual(10, [SELECT COUNT() FROM Quote WHERE Name LIKE 'Bulk Quote %']);
    }
}
