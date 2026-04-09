public without sharing class QuoteService {
    private static QuoteDAO dao = new QuoteDAO();
    private static ProductDAO productDao = new ProductDAO();

    /**
     * Business logic for creating a quote with full details.
     */
    public String createQuote(String name, Id accountId, Id opportunityId, Date startDate, Date endDate) {
        if (String.isBlank(name)) {
            throw new IllegalArgumentException('Quote name cannot be empty.');
        }

        Id standardPricebookId = productDao.getStandardPricebookId();

        Quote newQuote = new Quote(
            Name = name,
            OpportunityId = opportunityId,
            Account__c = accountId,
            Pricebook2Id = standardPricebookId,
            Status = 'Draft',
            ExpirationDate = endDate
        );

        Database.SaveResult result = dao.insertQuote(newQuote);
        
        if (result.isSuccess()) {
            return result.getId();
        } else {
            throw new AuraHandledException('Error creating quote: ' + getErrors(result));
        }
    }

    public String createQuote(String name) {
        return createQuote(name, null, null, null, null);
    }

    public List<Quote> getQuotes() {
        return dao.getAllQuotes();
    }

    public Quote getQuoteById(Id quoteId) {
        return dao.getQuoteById(quoteId);
    }

    public Map<String, Object> getQuoteSummary() {
        return dao.getQuoteSummaryStats();
    }

    public Map<String, Decimal> getRevenueBreakdown(Id quoteId) {
        List<QuoteLineItem> lines = [
            SELECT TotalPrice, Resource_Role__c, Product2.Name 
            FROM QuoteLineItem 
            WHERE QuoteId = :quoteId
        ];
        
        Decimal labor = 0;
        Decimal product = 0;
        Decimal addon = 0;
        
        for (QuoteLineItem line : lines) {
            Decimal total = line.TotalPrice != null ? line.TotalPrice : 0;
            if (line.Resource_Role__c != null || (line.Product2 != null && line.Product2.Name != null && line.Product2.Name.startsWith('Resource:'))) {
                labor += total;
            } else if (line.Product2 != null && line.Product2.Name != null && line.Product2.Name.contains('Add-on')) {
                addon += total;
            } else {
                product += total;
            }
        }
        
        return new Map<String, Decimal>{
            'Labor' => labor,
            'Product' => product,
            'Addon' => addon
        };
    }

    /**
     * Updates quote status.
     */
    public void updateQuoteStatus(Id quoteId, String status) {
        if (quoteId == null || String.isBlank(status)) {
            throw new IllegalArgumentException('Quote Id and status are required.');
        }
        
        // Custom logic: Only check lock if we are effectively trying to bypass the workflow
        // Otherwise, the specific recall/approve/reject methods handle their own status logic
        Quote q = new Quote(Id = quoteId, Status = status);
        dao.updateQuote(q);
    }

    /**
     * Recalculates quote totals from line items.
     */
    public void recalculateQuoteTotals(Id quoteId) {
        checkLock(quoteId);
        
        List<QuoteLineItem> lines = [
            SELECT UnitPrice, Quantity, Discount__c, Base_Rate__c, Cost__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
        ];

        Decimal subtotal = 0;
        Decimal lineDiscountAmount = 0;
        Decimal totalCost = 0;

        for (QuoteLineItem line : lines) {
            Decimal qty = line.Quantity != null ? line.Quantity : 0;
            Decimal price = line.UnitPrice != null ? line.UnitPrice : 0;
            Decimal discPct = line.Discount__c != null ? line.Discount__c : 0;
            Decimal cost = line.Cost__c != null ? line.Cost__c : 0;

            Decimal lineSubtotal = (price * qty);
            Decimal lineDiscount = (lineSubtotal * (discPct / 100));
            
            subtotal += lineSubtotal;
            lineDiscountAmount += lineDiscount;
            totalCost += (cost * qty);
        }

        Decimal finalTotalAmount = (subtotal - lineDiscountAmount).setScale(2, RoundingMode.HALF_UP);
        Decimal margin = finalTotalAmount > 0 ? (((subtotal - finalTotalAmount) / finalTotalAmount) * 100).setScale(2, RoundingMode.HALF_UP) : 0;
        Decimal finalDiscountPct = subtotal > 0 ? ((lineDiscountAmount / subtotal) * 100).setScale(2, RoundingMode.HALF_UP) : 0;

        Quote q = new Quote(
            Id = quoteId,
            Subtotal__c = subtotal.setScale(2, RoundingMode.HALF_UP),
            Total_Amount__c = finalTotalAmount,
            Total_Cost__c = totalCost.setScale(2, RoundingMode.HALF_UP),
            Margin__c = margin,
            Discount__c = finalDiscountPct
        );
        dao.updateQuote(q);
    }

    /**
     * Updates the additional discount on a quote.
     */
    public void updateQuoteDiscount(Id quoteId, Decimal discount) {
        if (quoteId == null) throw new IllegalArgumentException('Quote Id is required.');
        checkLock(quoteId);
        
        Quote q = new Quote(Id = quoteId, Additional_Discount__c = discount);
        dao.updateQuote(q);
        recalculateQuoteTotals(quoteId);
    }

    /**
     * Deletes multiple quotes.
     */
    public void deleteQuotes(List<Id> quoteIds) {
        for (Id quoteId : quoteIds) {
            checkLock(quoteId);
        }
        dao.deleteQuotes(quoteIds);
    }

    /**
     * Submits a quote for approval.
     */
    public void submitForApproval(Id quoteId, String comments) {
        Quote q = dao.getQuoteById(quoteId);
        if (q.Status != 'Draft') {
            throw new AuraHandledException('Only Draft quotes can be submitted for approval.');
        }

        Integer lineCount = new QuoteLineDAO().countLinesByQuoteId(quoteId);
        if (lineCount == 0) {
            throw new AuraHandledException('Quote must have at least one line item before submission.');
        }

        q.Status = 'In Review';
        q.Is_Locked__c = true;
        q.Approval_Comments__c = comments;
        dao.updateQuote(q);

        createHistoryRecord(quoteId, 'Submitted', comments);
    }

    /**
     * Recalls a quote in review.
     */
    public void recallQuote(Id quoteId) {
        Quote q = dao.getQuoteById(quoteId);
        if (q.Status != 'In Review') {
            throw new AuraHandledException('Only quotes in review can be recalled.');
        }

        q.Status = 'Draft';
        q.Is_Locked__c = false;
        dao.updateQuote(q);

        createHistoryRecord(quoteId, 'Recalled', 'Quote recalled by user.');
    }

    /**
     * Approves a quote.
     */
    public void approveQuote(Id quoteId, String comments) {
        Quote q = dao.getQuoteById(quoteId);
        if (q.Status != 'In Review') {
            throw new AuraHandledException('Only quotes in review can be approved.');
        }

        q.Status = 'Approved';
        q.Is_Locked__c = true;
        q.Approval_Comments__c = comments;
        dao.updateQuote(q);

        createHistoryRecord(quoteId, 'Approved', comments);
    }

    /**
     * Rejects a quote.
     */
    public void rejectQuote(Id quoteId, String comments) {
        Quote q = dao.getQuoteById(quoteId);
        if (q.Status != 'In Review') {
            throw new AuraHandledException('Only quotes in review can be rejected.');
        }

        q.Status = 'Rejected';
        q.Is_Locked__c = true;
        q.Approval_Comments__c = comments;
        dao.updateQuote(q);

        createHistoryRecord(quoteId, 'Rejected', comments);
    }

    public List<Quote_Approval_History__c> getApprovalHistory(Id quoteId) {
        return dao.getApprovalHistory(quoteId);
    }

    /**
     * Enforces locking logic at the backend level.
     */
    public void checkLock(Id quoteId) {
        Quote q = dao.getQuoteById(quoteId);
        if (q.Status == 'In Review' || q.Status == 'Approved' || q.Status == 'Rejected') {
            throw new AuraHandledException('This quote is currently locked due to its status: ' + q.Status);
        }
    }

    private void createHistoryRecord(Id quoteId, String action, String comments) {
        Quote_Approval_History__c history = new Quote_Approval_History__c();
        history.Quote__c = quoteId;
        history.Action__c = action;
        history.Comments__c = comments;
        history.Action_By__c = UserInfo.getUserId();
        history.Action_Date__c = DateTime.now();
        dao.insertApprovalHistory(history);
    }

    private String getErrors(Database.SaveResult result) {
        String errors = '';
        for (Database.Error err : result.getErrors()) {
            errors += err.getMessage() + ' ';
        }
        return errors;
    }
}
