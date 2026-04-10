@isTest
private class QuoteDocumentServiceTest {

    @testSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount('Doc Account');
        Opportunity opp = TestDataFactory.createOpportunity(acc.Id, 'Doc Opp');
        TestDataFactory.createQuote(opp.Id, 'Doc Quote');
    }

    private static Quote getQuote() {
        return [SELECT Id FROM Quote LIMIT 1];
    }

    private static QuoteLineItem addLine(Id quoteId) {
        Product2 prod = TestDataFactory.createProduct('DocProd', true);
        PricebookEntry pbe = TestDataFactory.createStandardPricebookEntry(prod.Id, 500);
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId=quoteId, Product2Id=prod.Id, PricebookEntryId=pbe.Id,
            Quantity=1, UnitPrice=500, Base_Rate__c=500, Cost__c=300
        );
        insert qli;
        return qli;
    }

    @isTest
    static void testGenerateAndSavePdf() {
        Quote q = getQuote();
        addLine(q.Id);

        Test.startTest();
        QuoteDocumentService.generateAndSavePdf(q.Id, 'Test notes');
        Test.stopTest();

        List<Quote_Document__c> docs = [SELECT Id, Version__c, Notes__c FROM Quote_Document__c WHERE Quote__c = :q.Id];
        Assert.areEqual(1, docs.size());
        Assert.areEqual(1, docs[0].Version__c);
        Assert.areEqual('Test notes', docs[0].Notes__c);
    }

    @isTest
    static void testGeneratePdfVersionIncrement() {
        Quote q = getQuote();
        addLine(q.Id);

        Test.startTest();
        QuoteDocumentService.generateAndSavePdf(q.Id, 'v1');
        QuoteDocumentService.generateAndSavePdf(q.Id, 'v2');
        Test.stopTest();

        List<Quote_Document__c> docs = [SELECT Version__c FROM Quote_Document__c WHERE Quote__c = :q.Id ORDER BY Version__c ASC];
        Assert.areEqual(2, docs.size());
        Assert.areEqual(1, docs[0].Version__c);
        Assert.areEqual(2, docs[1].Version__c);
    }

    @isTest
    static void testGeneratePdfNullQuoteId() {
        Test.startTest();
        try {
            QuoteDocumentService.generateAndSavePdf(null, 'notes');
            Assert.fail('Should throw for null quoteId.');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Quote Id is required'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGeneratePdfNoLineItems() {
        Quote q = getQuote();
        // Do NOT add any line items

        Test.startTest();
        try {
            QuoteDocumentService.generateAndSavePdf(q.Id, 'notes');
            Assert.fail('Should throw for no line items.');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('no line items'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetQuoteDocuments() {
        Quote q = getQuote();
        addLine(q.Id);
        QuoteDocumentService.generateAndSavePdf(q.Id, 'Get docs test');

        Test.startTest();
        List<Quote_Document__c> docs = QuoteDocumentService.getQuoteDocuments(q.Id);
        Test.stopTest();

        Assert.isTrue(docs.size() >= 1);
        Assert.isNotNull(docs[0].ContentDocumentId__c);
    }

    @isTest
    static void testGetQuoteDocumentsEmpty() {
        Quote q = getQuote();
        Test.startTest();
        List<Quote_Document__c> docs = QuoteDocumentService.getQuoteDocuments(q.Id);
        Test.stopTest();
        Assert.areEqual(0, docs.size());
    }

    @isTest
    static void testDeleteQuoteDocument() {
        Quote q = getQuote();
        addLine(q.Id);
        QuoteDocumentService.generateAndSavePdf(q.Id, 'Delete test');

        Quote_Document__c doc = [SELECT Id FROM Quote_Document__c WHERE Quote__c = :q.Id LIMIT 1];

        Test.startTest();
        QuoteDocumentService.deleteQuoteDocument(doc.Id);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Quote_Document__c WHERE Id = :doc.Id]);
    }

    @isTest
    static void testGetPdfBase64() {
        ContentVersion cv = new ContentVersion(
            Title = 'TestPDF',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('PDF content here'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Test.startTest();
        String base64 = QuoteDocumentService.getPdfBase64(contentDocId);
        Test.stopTest();

        Assert.isNotNull(base64);
        Assert.isTrue(base64.length() > 0);
    }
}
