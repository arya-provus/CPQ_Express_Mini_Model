public with sharing class QuoteLineDAO {
    
    /**
     * Queries QuoteLineItems for a specific Quote with all fields.
     * @param quoteId Quote ID.
     * @return List of QuoteLineItem records.
     */
    public List<QuoteLineItem> getLinesByQuoteId(Id quoteId) {
        return [
            SELECT Id, Product2.Name, Product2Id, Quantity, UnitPrice, TotalPrice,
                   Discount__c, Base_Rate__c, Task__c, Start_Date__c, End_Date__c,
                   Resource_Role__c, Resource_Role__r.Name, Resource_Role__r.Base_Rate__c,
                   PricebookEntryId, Cost__c, Discount_Amount__c, Line_Total__c
            FROM QuoteLineItem 
            WHERE QuoteId = :quoteId 
            ORDER BY CreatedDate ASC
        ];
    }

    /**
     * Inserts a QuoteLineItem record.
     * @param qli The QuoteLineItem record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult insertQuoteLine(QuoteLineItem qli) {
        return Database.insert(qli, true);
    }

    /**
     * Inserts multiple QuoteLineItem records in bulk.
     * @param qlis List of QuoteLineItems.
     * @return List<Database.SaveResult>.
     */
    public List<Database.SaveResult> insertQuoteLines(List<QuoteLineItem> qlis) {
        return Database.insert(qlis, true);
    }

    /**
     * Updates a QuoteLineItem record.
     * @param qli The QuoteLineItem record.
     * @return Database.SaveResult.
     */
    public Database.SaveResult updateQuoteLine(QuoteLineItem qli) {
        return Database.update(qli, true);
    }

    /**
     * Updates multiple QuoteLineItem records in bulk.
     * @param qlis List of QuoteLineItems.
     * @return List<Database.SaveResult>.
     */
    public List<Database.SaveResult> updateQuoteLines(List<QuoteLineItem> qlis) {
        return Database.update(qlis, true);
    }

    /**
     * Deletes a QuoteLineItem record.
     * @param lineId The Id of the line to delete.
     * @return Database.DeleteResult.
     */
    public Database.DeleteResult deleteQuoteLine(Id lineId) {
        QuoteLineItem qli = new QuoteLineItem(Id = lineId);
        return Database.delete(qli, true);
    }

    /**
     * Counts line items for a quote.
     * @param quoteId Quote Id.
     * @return Number of lines.
     */
    public Integer countLinesByQuoteId(Id quoteId) {
        return [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId];
    }
}
