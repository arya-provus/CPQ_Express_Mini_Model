public with sharing class QuoteDocumentService {
    @AuraEnabled
    public static void generateAndSavePdf(Id quoteId, String notes) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required');
        }

        Quote q = [SELECT Status, Total_Amount__c, Margin_Amount__c, Margin__c FROM Quote WHERE Id = :quoteId LIMIT 1];

        Integer count = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId];
        if (count == 0) {
            throw new AuraHandledException('Cannot generate PDF for a quote with no line items.');
        }

        // Generate PDF
        PageReference pdfPage = Page.QuotePDF;
        pdfPage.getParameters().put('id', quoteId);
        
        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Mock PDF Content');
        } else {
            try {
                pdfBlob = pdfPage.getContentAsPDF();
            } catch (Exception e) {
                // If called synchronously from AuraEnabled, this will throw CalloutException.
                // We will catch it and throw a clearer exception, or the user can invoke the visualforce fallback.
                throw new AuraHandledException('Failed to generate PDF: ' + e.getMessage());
            }
        }

        Integer version = [SELECT COUNT() FROM Quote_Document__c WHERE Quote__c = :quoteId] + 1;

        ContentVersion cv = new ContentVersion(
            Title = 'Quote_v' + version,
            PathOnClient = 'Quote_v' + version + '.pdf',
            VersionData = pdfBlob,
            IsMajorVersion = true
        );
        insert cv;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Quote_Document__c doc = new Quote_Document__c(
            Quote__c = quoteId,
            Version__c = version,
            Notes__c = notes,
            Total_Amount__c = q.Total_Amount__c,
            Margin_Amount__c = q.Margin_Amount__c,
            Margin__c = q.Margin__c,
            ContentDocumentId__c = contentDocumentId
        );
        insert doc;

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = doc.Id,
            ShareType = 'I'
        );
        insert cdl;
        
        // Also optionally link it to the Quote directly
        ContentDocumentLink cdlQuote = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = quoteId,
            ShareType = 'I'
        );
        insert cdlQuote;
    }

    @AuraEnabled(cacheable=true)
    public static List<Quote_Document__c> getQuoteDocuments(Id quoteId) {
        return [SELECT Id, Name, Version__c, Notes__c, Total_Amount__c, Margin_Amount__c, Margin__c, CreatedDate, CreatedBy.Name, ContentDocumentId__c 
                FROM Quote_Document__c 
                WHERE Quote__c = :quoteId 
                ORDER BY Version__c DESC];
    }

    @AuraEnabled
    public static void deleteQuoteDocument(Id documentId) {
        Quote_Document__c doc = [SELECT Id, ContentDocumentId__c FROM Quote_Document__c WHERE Id = :documentId LIMIT 1];
        if (doc.ContentDocumentId__c != null) {
            delete [SELECT Id FROM ContentDocument WHERE Id = :doc.ContentDocumentId__c];
        }
        delete doc;
    }

    @AuraEnabled
    public static String getPdfBase64(Id contentDocumentId) {
        ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true LIMIT 1];
        return EncodingUtil.base64Encode(cv.VersionData);
    }
}
