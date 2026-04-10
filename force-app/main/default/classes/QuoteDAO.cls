public inherited sharing class QuoteDAO {
    
    /**
     * Queries all Quote records with full details.
     * @return List of Quote records.
     */
    public List<Quote> getAllQuotes() {
        return [
            SELECT Id, Name, QuoteNumber, CreatedBy.Name, CreatedDate, Status,
                   Opportunity.Name, Account__r.Name,
                   Subtotal__c, Total_Amount__c, Margin__c, Discount__c,
                   Total_Cost__c, Discount_Amount__c, Margin_Amount__c,
                   Quote_Time_Period__c,
                   OpportunityId, Account__c, Pricebook2Id
            FROM Quote 
            ORDER BY CreatedDate DESC 
            LIMIT 100
        ];
    }

    /**
     * Queries a single Quote by its Id with full details.
     * @param quoteId The ID of the Quote.
     * @return The Quote record.
     */
    public Quote getQuoteById(Id quoteId) {
        return [
            SELECT Id, Name, QuoteNumber, CreatedById, CreatedBy.Name, CreatedDate, Status,
                   Opportunity.Name, Account__r.Name, Account__c,
                   Subtotal__c, Total_Amount__c, Margin__c, Discount__c,
                   Total_Cost__c, Discount_Amount__c, Margin_Amount__c,
                   Quote_Time_Period__c, Additional_Discount__c,
                   OpportunityId, AccountId, Pricebook2Id, ExpirationDate,
                   Account__r.BillingStreet,
                   Account__r.BillingCity,
                   Account__r.BillingState,
                   Account__r.BillingPostalCode,
                   Is_Locked__c, Approval_Comments__c
            FROM Quote 
            WHERE Id = :quoteId 
            LIMIT 1
        ];
    }

    /**
     * Gets summary statistics for the dashboard.
     * @return Map with keys: draftCount, highMarginCount, wonCount, totalAmount.
     */
    public Map<String, Object> getQuoteSummaryStats() {
        Map<String, Object> stats = new Map<String, Object>();
        
        // Draft pipeline count
        Integer draftCount = [SELECT COUNT() FROM Quote WHERE Status = 'Draft'];
        stats.put('draftCount', draftCount);
        
        // High margin deals (margin > 30%)
        Integer highMarginCount = [SELECT COUNT() FROM Quote WHERE Margin__c > 30];
        stats.put('highMarginCount', highMarginCount);
        
        // Won this month
        Date startOfMonth = Date.today().toStartOfMonth();
        Integer wonCount = [SELECT COUNT() FROM Quote WHERE Status = 'Approved' AND CreatedDate >= :startOfMonth];
        stats.put('wonCount', wonCount);
        
        // Total pipeline amount
        AggregateResult[] results = [SELECT SUM(Total_Amount__c) totalAmt FROM Quote WHERE Status = 'Draft'];
        Decimal totalAmt = (Decimal) results[0].get('totalAmt');
        stats.put('totalPipelineAmount', totalAmt != null ? totalAmt : 0);
        
        // Quotes for feed
        List<Quote> recentQuotes = [
            SELECT Id, Name, QuoteNumber, Status, Total_Amount__c, CreatedDate, 
                   Account__r.Name
            FROM Quote 
            ORDER BY CreatedDate DESC 
        ];
        stats.put('recentQuotes', recentQuotes);
        
        return stats;
    }

    /**
     * Inserts a Quote record.
     * @param q The Quote to insert.
     * @return The Database.SaveResult.
     */
    public Database.SaveResult insertQuote(Quote q) {
        return Database.insert(q, true);
    }

    /**
     * Updates a Quote record.
     * @param q The Quote to update.
     * @return The Database.SaveResult.
     */
    public Database.SaveResult updateQuote(Quote q) {
        return Database.update(q, true);
    }

    /**
     * Deletes multiple Quote records.
     * @param quoteIds List of Quote IDs to delete.
     */
    public void deleteQuotes(List<Id> quoteIds) {
        if (quoteIds != null && !quoteIds.isEmpty()) {
            delete [SELECT Id FROM Quote WHERE Id IN :quoteIds];
        }
    }

    /**
     * Fetches approval history for a quote.
     * @param quoteId Quote Id.
     * @return List of Quote_Approval_History__c records.
     */
    public List<Quote_Approval_History__c> getApprovalHistory(Id quoteId) {
        return [
            SELECT Id, Action__c, Comments__c, Action_By__r.Name, Action_Date__c
            FROM Quote_Approval_History__c
            WHERE Quote__c = :quoteId
            ORDER BY Action_Date__c DESC
        ];
    }

    /**
     * Inserts an approval history record.
     * @param history Record to insert.
     */
    public void insertApprovalHistory(Quote_Approval_History__c history) {
        insert history;
    }
}
