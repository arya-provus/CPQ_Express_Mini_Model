public with sharing class QuoteLineService {
    private static QuoteLineDAO lineDao = new QuoteLineDAO();
    private static QuoteDAO quoteDao = new QuoteDAO();
    private static ProductDAO productDao = new ProductDAO();
    private QuoteService quoteService = new QuoteService();

    /**
     * Bulk adds multiple items (Products, Roles, Add-ons) to a quote.
     */
    public void addItemsToQuote(Id quoteId, List<Id> productIds, List<Id> roleIds, List<Id> addonIds) {
        if (quoteId == null) {
            throw new IllegalArgumentException('Quote ID is required.');
        }
        
        // Enforce lock check
        quoteService.checkLock(quoteId);

        // 1. Ensure Quote has a Pricebook2Id
        Quote q = quoteDao.getQuoteById(quoteId);
        Id pricebookId = q.Pricebook2Id;
        if (pricebookId == null) {
            pricebookId = productDao.getStandardPricebookId();
            q.Pricebook2Id = pricebookId;
            quoteDao.updateQuote(q);
        }

        List<QuoteLineItem> linesToInsert = new List<QuoteLineItem>();

        // 2. Handle standard Products
        if (productIds != null && !productIds.isEmpty()) {
            Map<Id, PricebookEntry> pbeMap = getPricebookEntries(productIds, pricebookId);
            Map<Id, Product2> prodMap = new Map<Id, Product2>([SELECT Id, Cost__c FROM Product2 WHERE Id IN :productIds]);
            
            for (Id pid : productIds) {
                if (pbeMap.containsKey(pid)) {
                    PricebookEntry pbe = pbeMap.get(pid);
                    linesToInsert.add(new QuoteLineItem(
                        QuoteId = quoteId,
                        Product2Id = pid,
                        PricebookEntryId = pbe.Id,
                        Quantity = 1,
                        UnitPrice = pbe.UnitPrice,
                        Base_Rate__c = pbe.UnitPrice,
                        Cost__c = prodMap.containsKey(pid) ? prodMap.get(pid).Cost__c : 0,
                        Discount__c = 0
                    ));
                }
            }
        }

        // 3. Handle Resource Roles
        if (roleIds != null && !roleIds.isEmpty()) {
            List<Resource_Role__c> roles = [SELECT Id, Name, Base_Rate__c, Cost__c FROM Resource_Role__c WHERE Id IN :roleIds];
            for (Resource_Role__c role : roles) {
                Id productId = getOrCreateShadowProduct('Resource: ' + role.Name, 'Auto-created for resource role: ' + role.Name);
                Id pbeId = getOrCreatePricebookEntry(productId, pricebookId, role.Base_Rate__c);
                
                linesToInsert.add(new QuoteLineItem(
                    QuoteId = quoteId,
                    Product2Id = productId,
                    PricebookEntryId = pbeId,
                    Quantity = 1,
                    UnitPrice = role.Base_Rate__c,
                    Base_Rate__c = role.Base_Rate__c,
                    Cost__c = role.Cost__c,
                    Resource_Role__c = role.Id,
                    Discount__c = 0
                ));
            }
        }

        // 4. Handle Add-ons
        if (addonIds != null && !addonIds.isEmpty()) {
            List<Add_On__c> addons = [SELECT Id, Name, Price__c, Cost__c FROM Add_On__c WHERE Id IN :addonIds];
            for (Add_On__c addon : addons) {
                Id productId = getOrCreateShadowProduct('Add-on: ' + addon.Name, 'Auto-created for add-on: ' + addon.Name);
                Id pbeId = getOrCreatePricebookEntry(productId, pricebookId, addon.Price__c);
                
                linesToInsert.add(new QuoteLineItem(
                    QuoteId = quoteId,
                    Product2Id = productId,
                    PricebookEntryId = pbeId,
                    Quantity = 1,
                    UnitPrice = addon.Price__c,
                    Base_Rate__c = addon.Price__c,
                    Cost__c = addon.Cost__c,
                    Discount__c = 0
                ));
            }
        }

        if (!linesToInsert.isEmpty()) {
            lineDao.insertQuoteLines(linesToInsert);
            recalculateQuoteTotals(quoteId);
        }
    }

    private Map<Id, PricebookEntry> getPricebookEntries(List<Id> productIds, Id pricebookId) {
        Map<Id, PricebookEntry> pbeMap = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry 
                                   WHERE Product2Id IN :productIds AND Pricebook2Id = :pricebookId AND IsActive = true]) {
            pbeMap.put(pbe.Product2Id, pbe);
        }
        return pbeMap;
    }

    private Id getOrCreateShadowProduct(String name, String description) {
        List<Product2> existing = [SELECT Id FROM Product2 WHERE Name = :name AND IsActive = true LIMIT 1];
        if (!existing.isEmpty()) return existing[0].Id;
        
        Product2 newProd = new Product2(Name = name, Description = description, IsActive = true);
        insert newProd;
        return newProd.Id;
    }

    private Id getOrCreatePricebookEntry(Id productId, Id pricebookId, Decimal unitPrice) {
        List<PricebookEntry> existing = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId AND Pricebook2Id = :pricebookId AND IsActive = true LIMIT 1];
        if (!existing.isEmpty()) return existing[0].Id;
        
        PricebookEntry newPbe = new PricebookEntry(Product2Id = productId, Pricebook2Id = pricebookId, UnitPrice = unitPrice, IsActive = true);
        insert newPbe;
        return newPbe.Id;
    }

    public Id addQuoteLine(Id quoteId, Id productId, Integer quantity) {
        addItemsToQuote(quoteId, new List<Id>{productId}, null, null);
        return [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY CreatedDate DESC LIMIT 1].Id;
    }

    public Id addResourceRoleLine(Id quoteId, Id roleId, Integer quantity) {
        addItemsToQuote(quoteId, null, new List<Id>{roleId}, null);
        return [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY CreatedDate DESC LIMIT 1].Id;
    }

    public Id addAddOnLine(Id quoteId, Id addOnId, Integer quantity) {
        addItemsToQuote(quoteId, null, null, new List<Id>{addOnId});
        return [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY CreatedDate DESC LIMIT 1].Id;
    }

    /**
     * Updates multiple quote line items.
     */
    public void updateQuoteLines(List<QuoteLineItem> items) {
        if (items == null || items.isEmpty()) {
            return;
        }
        
        Id quoteId = [SELECT QuoteId FROM QuoteLineItem WHERE Id = :items[0].Id LIMIT 1].QuoteId;
        quoteService.checkLock(quoteId);

        lineDao.updateQuoteLines(items);
        recalculateQuoteTotals(quoteId);
    }

    /**
     * Updates a quote line item's editable fields.
     */
    public void updateQuoteLine(Id lineId, Decimal discount, String task, 
                                 Date startDate, Date endDate, Decimal unitPrice, Decimal quantity) {
        if (lineId == null) {
            throw new IllegalArgumentException('Line item Id is required.');
        }

        QuoteLineItem fullLine = [SELECT QuoteId FROM QuoteLineItem WHERE Id = :lineId LIMIT 1];
        quoteService.checkLock(fullLine.QuoteId);

        QuoteLineItem qli = new QuoteLineItem(Id = lineId);
        if (discount != null) qli.Discount__c = discount;
        if (task != null) qli.Task__c = task;
        if (startDate != null) qli.Start_Date__c = startDate;
        if (endDate != null) qli.End_Date__c = endDate;
        if (unitPrice != null) qli.UnitPrice = unitPrice;
        if (quantity != null) qli.Quantity = quantity;

        lineDao.updateQuoteLine(qli);
        recalculateQuoteTotals(fullLine.QuoteId);
    }

    /**
     * Deletes a quote line item.
     */
    public void deleteQuoteLine(Id lineId) {
        if (lineId == null) {
            throw new IllegalArgumentException('Line item Id is required.');
        }
        QuoteLineItem fullLine = [SELECT QuoteId FROM QuoteLineItem WHERE Id = :lineId LIMIT 1];
        quoteService.checkLock(fullLine.QuoteId);

        lineDao.deleteQuoteLine(lineId);
        recalculateQuoteTotals(fullLine.QuoteId);
    }

    public List<QuoteLineItem> getQuoteLines(Id quoteId) {
        return lineDao.getLinesByQuoteId(quoteId);
    }

    private void recalculateQuoteTotals(Id quoteId) {
        quoteService.recalculateQuoteTotals(quoteId);
    }
}
