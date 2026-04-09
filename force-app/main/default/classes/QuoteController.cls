public with sharing class QuoteController {
    
    /**
     * Entry point for LWC to create a Quote with full details.
     * @param name The Name of the Quote.
     * @param accountId Optional Account Id.
     * @param opportunityId Optional Opportunity Id.
     * @param startDate Optional start date.
     * @param endDate Optional end date.
     * @return The Id of the newly created Quote.
     */
    @AuraEnabled
    public static String createQuote(String name, Id accountId, Id opportunityId, Date startDate, Date endDate) {
        try {
            QuoteService service = new QuoteService();
            return service.createQuote(name, accountId, opportunityId, startDate, endDate);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Simple createQuote for backward compatibility.
     */
    @AuraEnabled
    public static String createQuoteSimple(String name) {
        try {
            QuoteService service = new QuoteService();
            return service.createQuote(name);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Entry point for LWC to get Quote list.
     * @return List of Quote records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Quote> getQuotes() {
        try {
            QuoteService service = new QuoteService();
            return service.getQuotes();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Gets a single quote by ID.
     */
    @AuraEnabled(cacheable=true)
    public static Quote getQuoteById(Id quoteId) {
        try {
            QuoteService service = new QuoteService();
            return service.getQuoteById(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Gets dashboard summary statistics.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getQuoteSummary() {
        try {
            QuoteService service = new QuoteService();
            return service.getQuoteSummary();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Gets revenue breakdown for a quote.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getRevenueBreakdown(Id quoteId) {
        try {
            QuoteService service = new QuoteService();
            return service.getRevenueBreakdown(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Updates quote status.
     */
    @AuraEnabled
    public static void updateQuoteStatus(Id quoteId, String status) {
        try {
            QuoteService service = new QuoteService();
            service.updateQuoteStatus(quoteId, status);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Recalculates quote totals from line items.
     */
    @AuraEnabled
    public static void recalculateQuoteTotals(Id quoteId) {
        try {
            QuoteService service = new QuoteService();
            service.recalculateQuoteTotals(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * Updates quote additional discount.
     */
    @AuraEnabled
    public static void updateQuoteDiscount(Id quoteId, Decimal discount) {
        try {
            QuoteService service = new QuoteService();
            service.updateQuoteDiscount(quoteId, discount);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Deletes multiple quotes by ID.
     */
    @AuraEnabled
    public static void deleteQuotes(List<Id> quoteIds) {
        try {
            QuoteService service = new QuoteService();
            service.deleteQuotes(quoteIds);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Submits a quote for approval.
     */
    @AuraEnabled
    public static void submitForApproval(Id quoteId, String comments) {
        try {
            QuoteService service = new QuoteService();
            service.submitForApproval(quoteId, comments);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Recalls a quote in review.
     */
    @AuraEnabled
    public static void recallQuote(Id quoteId) {
        try {
            QuoteService service = new QuoteService();
            service.recallQuote(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Approves a quote.
     */
    @AuraEnabled
    public static void approveQuote(Id quoteId, String comments) {
        try {
            QuoteService service = new QuoteService();
            service.approveQuote(quoteId, comments);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Rejects a quote.
     */
    @AuraEnabled
    public static void rejectQuote(Id quoteId, String comments) {
        try {
            QuoteService service = new QuoteService();
            service.rejectQuote(quoteId, comments);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Fetches approval history.
     */
    @AuraEnabled(cacheable=true)
    public static List<Quote_Approval_History__c> getApprovalHistory(Id quoteId) {
        try {
            QuoteService service = new QuoteService();
            return service.getApprovalHistory(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
