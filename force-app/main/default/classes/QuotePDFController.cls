public with sharing class QuotePDFController {
    public Quote quoteRecord { get; set; }
    public List<LineItemWrapper> formattedLines { get; set; }

    public class LineItemWrapper {
        public String itemName { get; set; }
        public String itemDates { get; set; }
        public String itemType { get; set; }
        public String quantityStr { get; set; }
        public Decimal price { get; set; }
        public String discountStr { get; set; }
        public Decimal subtotal { get; set; }
    }

    public QuotePDFController() {
        Id quoteId = ApexPages.currentPage().getParameters().get('id');
        if (quoteId != null) {
            quoteRecord = [
                SELECT Id, Name, QuoteNumber, CreatedBy.Name, CreatedDate, Status,
                       Subtotal__c, Total_Amount__c, Margin__c, Discount__c,
                       Total_Cost__c, Discount_Amount__c, Margin_Amount__c,
                       Quote_Time_Period__c, ExpirationDate, Description
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];

            List<QuoteLineItem> rawLines = [
                SELECT Id, Product2.Name, Resource_Role__r.Name, 
                       Task__c, Start_Date__c, End_Date__c, Quantity, 
                       Base_Rate__c, UnitPrice, Discount__c, Cost__c
                FROM QuoteLineItem
                WHERE QuoteId = :quoteId
                ORDER BY CreatedDate ASC
            ];

            formattedLines = new List<LineItemWrapper>();
            for (QuoteLineItem qli : rawLines) {
                LineItemWrapper wrapper = new LineItemWrapper();
                
                String pName = qli.Product2 != null ? qli.Product2.Name : '';
                String rName = qli.Resource_Role__r != null ? qli.Resource_Role__r.Name : '';
                
                wrapper.itemName = String.isNotBlank(pName) ? pName : rName;
                
                // Determine Type
                if (String.isNotBlank(rName) || pName.startsWithIgnoreCase('Resource:')) {
                    wrapper.itemType = 'Resource Role';
                } else if (pName.startsWithIgnoreCase('Add-on:')) {
                    wrapper.itemType = 'Add On';
                } else {
                    wrapper.itemType = 'Product';
                }
                
                // Strip prefixes from item name if present
                if (wrapper.itemName.startsWithIgnoreCase('Resource: ')) {
                    wrapper.itemName = wrapper.itemName.substring(10);
                } else if (wrapper.itemName.startsWithIgnoreCase('Add-on: ')) {
                    wrapper.itemName = wrapper.itemName.substring(8);
                }

                // Dates
                String sDate = qli.Start_Date__c != null ? qli.Start_Date__c.format() : '';
                String eDate = qli.End_Date__c != null ? qli.End_Date__c.format() : '';
                if (String.isNotBlank(sDate) && String.isNotBlank(eDate)) {
                    wrapper.itemDates = sDate + ' - ' + eDate;
                } else {
                    wrapper.itemDates = '';
                }

                // Quantity
                Decimal q = qli.Quantity != null ? qli.Quantity : 0;
                String unit = (wrapper.itemType == 'Resource Role') ? 'month(s)' : 'item(s)';
                if (quoteRecord.Quote_Time_Period__c == 'Weeks' && wrapper.itemType == 'Resource Role') unit = 'week(s)';
                wrapper.quantityStr = q.setScale(0) + ' ' + unit;

                // Price & Discount
                Decimal rate = qli.Base_Rate__c != null ? qli.Base_Rate__c : qli.UnitPrice;
                wrapper.price = rate != null ? rate : 0;
                Decimal disc = qli.Discount__c != null ? qli.Discount__c : 0;
                wrapper.discountStr = disc > 0 ? disc + '%' : '-';

                // Subtotal calculation matching LWC
                wrapper.subtotal = (qli.UnitPrice != null ? qli.UnitPrice : 0) * q;
                if (disc > 0) {
                    wrapper.subtotal = wrapper.subtotal - (wrapper.subtotal * (disc / 100));
                }

                formattedLines.add(wrapper);
            }
        }
    }
}
