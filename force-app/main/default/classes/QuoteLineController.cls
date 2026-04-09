public with sharing class QuoteLineController {

    /**
     * Entry point for LWC to add a product to a quote as a line item.
     * @param quoteId Quote ID.
     * @param productId Product ID.
     * @param quantity Number of units.
     * @return QuoteLineItem Id.
     */
    @AuraEnabled
    public static Id addQuoteLine(Id quoteId, Id productId, Integer quantity) {
        try {
            QuoteLineService service = new QuoteLineService();
            return service.addQuoteLine(quoteId, productId, quantity);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Adds a resource role as a line item.
     */
    @AuraEnabled
    public static Id addResourceRoleLine(Id quoteId, Id roleId, Integer quantity) {
        try {
            QuoteLineService service = new QuoteLineService();
            return service.addResourceRoleLine(quoteId, roleId, quantity);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Adds an add-on as a line item.
     */
    @AuraEnabled
    public static Id addAddOnLine(Id quoteId, Id addOnId, Integer quantity) {
        try {
            QuoteLineService service = new QuoteLineService();
            return service.addAddOnLine(quoteId, addOnId, quantity);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Bulk adds multiple items (Products, Roles, Add-ons) to a quote.
     */
    @AuraEnabled
    public static void addItemsToQuote(Id quoteId, List<Id> productIds, List<Id> roleIds, List<Id> addonIds) {
        try {
            QuoteLineService service = new QuoteLineService();
            service.addItemsToQuote(quoteId, productIds, roleIds, addonIds);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Entry point for LWC to fetch quote lines.
     * @param quoteId Quote ID.
     * @return List of QuoteLineItems.
     */
    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLines(Id quoteId) {
        try {
            QuoteLineService service = new QuoteLineService();
            return service.getQuoteLines(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Updates multiple line items at once.
     */
    @AuraEnabled
    public static void updateQuoteLines(List<QuoteLineItem> items) {
        try {
            QuoteLineService service = new QuoteLineService();
            service.updateQuoteLines(items);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Updates a line item's editable fields (inline editing).
     */
    @AuraEnabled
    public static void updateQuoteLine(Id lineId, Decimal discount, String task,
                                        Date startDate, Date endDate, Decimal unitPrice, Decimal quantity) {
        try {
            QuoteLineService service = new QuoteLineService();
            service.updateQuoteLine(lineId, discount, task, startDate, endDate, unitPrice, quantity);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Deletes a line item.
     */
    @AuraEnabled
    public static void deleteQuoteLine(Id lineId) {
        try {
            QuoteLineService service = new QuoteLineService();
            service.deleteQuoteLine(lineId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
